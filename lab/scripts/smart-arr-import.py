#!/usr/bin/env python3
"""Personalized Radarr/Sonarr importer.

Builds recommendation seeds from Jellyfin watch history + Jellyseerr requests,
asks Jellyseerr/TMDB for similar/recommended movies and shows, then optionally
adds the top-scoring candidates to Radarr/Sonarr.

Default is DRY RUN. Use --apply for real additions.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

TODAY = dt.date.today()
EXCLUDED_MOVIE_GENRES = {"Documentary", "Music", "TV Movie"}
EXCLUDED_TV_GENRES = {"Documentary", "News", "Reality", "Talk"}


def load_env() -> None:
    env_path = Path(__file__).with_name(".env")
    if not env_path.exists():
        env_path = Path.home() / "bin/lab/scripts/.env"
    if not env_path.exists():
        return
    for raw in env_path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


class Client:
    def __init__(self, base: str, api_key: str | None = None, api_prefix: str = "") -> None:
        self.base = base.rstrip("/")
        self.api_key = api_key
        self.api_prefix = api_prefix.strip("/")

    def url(self, path: str) -> str:
        path = path.lstrip("/")
        if self.api_prefix:
            return f"{self.base}/{self.api_prefix}/{path}"
        return f"{self.base}/{path}"

    def request(self, path: str, method: str = "GET", data: Any | None = None, timeout: int = 30) -> Any:
        body = None
        headers = {"Accept": "application/json"}
        if self.api_key:
            headers["X-Api-Key"] = self.api_key
            headers["X-MediaBrowser-Token"] = self.api_key
        if data is not None:
            body = json.dumps(data).encode()
            headers["Content-Type"] = "application/json"
        req = urllib.request.Request(self.url(path), headers=headers, data=body, method=method)
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                raw = resp.read().decode()
                if not raw:
                    return None
                return json.loads(raw)
        except urllib.error.HTTPError as e:
            raw = e.read().decode(errors="replace")
            raise RuntimeError(f"HTTP {e.code} {method} {self.url(path)}: {raw[:400]}") from e


def env_client(prefix: str, api_prefix: str = "api/v3") -> Client | None:
    base = os.environ.get(f"{prefix}_URL")
    key = os.environ.get(f"{prefix}_API_KEY")
    if not base or not key:
        return None
    return Client(base, key, api_prefix)


def parse_date(value: str | None) -> dt.date | None:
    if not value:
        return None
    try:
        return dt.date.fromisoformat(value[:10])
    except ValueError:
        return None


def genres_of(item: dict[str, Any]) -> set[str]:
    genres = item.get("genres") or item.get("Genres") or []
    out: set[str] = set()
    for g in genres:
        if isinstance(g, dict):
            name = g.get("name") or g.get("Name")
            if name:
                out.add(str(name))
        elif isinstance(g, str):
            out.add(g)
    return out


def jellyseerr_requests(js: Client, limit: int = 80) -> list[dict[str, Any]]:
    try:
        data = js.request(f"request?take={limit}&skip=0&sort=added&filter=all")
    except Exception as e:
        print(f"WARN: Jellyseerr request history unavailable: {e}", file=sys.stderr)
        return []
    return data.get("results", data if isinstance(data, list) else [])


def seed_from_jellyseerr(js: Client) -> tuple[list[int], list[int], Counter[str], Counter[str]]:
    movie_ids: list[int] = []
    tv_ids: list[int] = []
    movie_genres: Counter[str] = Counter()
    tv_genres: Counter[str] = Counter()
    for req in jellyseerr_requests(js):
        media = req.get("media") or {}
        media_type = media.get("mediaType") or req.get("type")
        tmdb_id = media.get("tmdbId")
        if not tmdb_id:
            continue
        try:
            details = js.request(("movie" if media_type == "movie" else "tv") + f"/{tmdb_id}")
        except Exception:
            continue
        gs = genres_of(details)
        if media_type == "movie":
            movie_ids.append(int(tmdb_id))
            movie_genres.update(gs)
        elif media_type == "tv":
            tv_ids.append(int(tmdb_id))
            tv_genres.update(gs)
    return movie_ids, tv_ids, movie_genres, tv_genres


def seed_from_jellyfin(jf: Client, js: Client, per_user: int = 80) -> tuple[list[int], list[int], Counter[str], Counter[str]]:
    movie_ids: list[int] = []
    tv_ids: list[int] = []
    movie_genres: Counter[str] = Counter()
    tv_genres: Counter[str] = Counter()
    try:
        users = jf.request("Users")
    except Exception as e:
        print(f"WARN: Jellyfin users unavailable: {e}", file=sys.stderr)
        return movie_ids, tv_ids, movie_genres, tv_genres

    seen_series: set[str] = set()
    for user in users:
        uid = user.get("Id")
        if not uid:
            continue
        qs = urllib.parse.urlencode(
            {
                "isPlayed": "true",
                "recursive": "true",
                "includeItemTypes": "Movie,Episode",
                "sortBy": "DatePlayed",
                "sortOrder": "Descending",
                "fields": "Genres,ProviderIds,SeriesName,SeriesId,CommunityRating,DateCreated",
                "limit": str(per_user),
            }
        )
        try:
            data = jf.request(f"Users/{uid}/Items?{qs}")
        except Exception:
            continue
        for item in data.get("Items", []):
            typ = item.get("Type")
            provider = item.get("ProviderIds") or {}
            if typ == "Movie":
                tmdb = provider.get("Tmdb") or provider.get("TMDb")
                if tmdb and str(tmdb).isdigit():
                    movie_ids.append(int(tmdb))
                    movie_genres.update(genres_of(item))
            elif typ == "Episode":
                series_id = item.get("SeriesId")
                if not series_id or series_id in seen_series:
                    continue
                seen_series.add(series_id)
                try:
                    details = jf.request(f"Items/{series_id}?Fields=Genres,ProviderIds")
                except Exception:
                    continue
                provider = details.get("ProviderIds") or {}
                tmdb = provider.get("Tmdb") or provider.get("TMDb")
                if tmdb and str(tmdb).isdigit():
                    tv_ids.append(int(tmdb))
                    tv_genres.update(genres_of(details))
    return movie_ids, tv_ids, movie_genres, tv_genres


def unique_recent(values: list[int], limit: int) -> list[int]:
    out: list[int] = []
    seen: set[int] = set()
    for value in values:
        if value in seen:
            continue
        seen.add(value)
        out.append(value)
        if len(out) >= limit:
            break
    return out


def recommendations(js: Client, media_type: str, seeds: list[int], max_seeds: int = 12) -> dict[int, dict[str, Any]]:
    candidates: dict[int, dict[str, Any]] = {}
    for seed in unique_recent(seeds, max_seeds):
        for flavor in ("recommendations", "similar"):
            try:
                data = js.request(f"{media_type}/{seed}/{flavor}")
            except Exception:
                continue
            for rank, item in enumerate(data.get("results", [])[:12], start=1):
                cid = item.get("id")
                if not cid:
                    continue
                c = candidates.setdefault(int(cid), dict(item))
                c.setdefault("_sources", []).append({"seed": seed, "flavor": flavor, "rank": rank})
        time.sleep(0.05)
    return candidates


def score_candidate(item: dict[str, Any], wanted_genres: Counter[str], media_type: str) -> float:
    vote = float(item.get("voteAverage") or item.get("vote_average") or 0)
    popularity = float(item.get("popularity") or 0)
    gs = genres_of(item)
    genre_score = sum(wanted_genres.get(g, 0) for g in gs)
    source_score = sum(max(0, 13 - s.get("rank", 12)) for s in item.get("_sources", []))
    score = vote * 8 + min(popularity, 80) * 0.15 + genre_score * 3 + source_score * 1.2
    title = item.get("title") or item.get("name") or ""
    if any(word in title.lower() for word in ("live", "concert", "documentary")):
        score -= 20
    if media_type == "tv" and (genres_of(item) & EXCLUDED_TV_GENRES):
        score -= 50
    if media_type == "movie" and (genres_of(item) & EXCLUDED_MOVIE_GENRES):
        score -= 50
    return round(score, 3)


def existing_radarr_tmdb(radarr: Client) -> set[int]:
    return {int(m["tmdbId"]) for m in radarr.request("movie") if m.get("tmdbId")}


def existing_sonarr_tvdb(sonarr: Client) -> set[int]:
    return {int(s["tvdbId"]) for s in sonarr.request("series") if s.get("tvdbId")}


def already_known_jellyseerr(js: Client) -> tuple[set[int], set[int]]:
    movies: set[int] = set()
    tv: set[int] = set()
    for req in jellyseerr_requests(js, limit=150):
        media = req.get("media") or {}
        mt = media.get("mediaType") or req.get("type")
        tid = media.get("tmdbId")
        if not tid:
            continue
        (movies if mt == "movie" else tv).add(int(tid))
    return movies, tv


def filter_movies(
    js: Client,
    items: dict[int, dict[str, Any]],
    existing: set[int],
    known_requests: set[int],
    wanted_genres: Counter[str],
    min_year: int,
) -> list[dict[str, Any]]:
    out = []
    for tmdb_id, item in items.items():
        if tmdb_id in existing or tmdb_id in known_requests:
            continue
        try:
            details = js.request(f"movie/{tmdb_id}")
        except Exception:
            details = {}
        merged = dict(item)
        merged.update({k: v for k, v in details.items() if v not in (None, "", [])})
        title = merged.get("title")
        release = parse_date(merged.get("releaseDate") or merged.get("release_date"))
        vote = float(merged.get("voteAverage") or merged.get("vote_average") or 0)
        if not title or not release or release > TODAY or release.year < min_year or vote < 6.2:
            continue
        if genres_of(merged) & EXCLUDED_MOVIE_GENRES:
            continue
        merged["score"] = score_candidate(merged, wanted_genres, "movie")
        out.append(merged)
    return sorted(out, key=lambda x: x["score"], reverse=True)


def filter_tv(
    js: Client,
    items: dict[int, dict[str, Any]],
    sonarr: Client,
    existing_tvdb: set[int],
    known_requests: set[int],
    wanted_genres: Counter[str],
    min_year: int,
) -> list[dict[str, Any]]:
    out = []
    for tmdb_id, item in items.items():
        if tmdb_id in known_requests:
            continue
        try:
            details = js.request(f"tv/{tmdb_id}")
        except Exception:
            continue
        merged = dict(item)
        merged.update({k: v for k, v in details.items() if v not in (None, "", [])})
        first_air = parse_date(merged.get("firstAirDate") or merged.get("first_air_date"))
        vote = float(merged.get("voteAverage") or merged.get("vote_average") or 0)
        if not merged.get("name") or not first_air or first_air > TODAY or first_air.year < min_year or vote < 6.8:
            continue
        if genres_of(merged) & EXCLUDED_TV_GENRES:
            continue
        tvdb = (merged.get("externalIds") or {}).get("tvdbId") or (merged.get("mediaInfo") or {}).get("tvdbId")
        if not tvdb or int(tvdb) in existing_tvdb:
            continue
        merged["tvdbId"] = int(tvdb)
        merged["score"] = score_candidate(merged, wanted_genres, "tv")
        out.append(merged)
    return sorted(out, key=lambda x: x["score"], reverse=True)


def add_radarr_movie(radarr: Client, tmdb_id: int, root: str, profile: int) -> str:
    movie = radarr.request(f"movie/lookup/tmdb?tmdbId={tmdb_id}")
    payload = dict(movie)
    payload.update(
        {
            "qualityProfileId": profile,
            "rootFolderPath": root,
            "monitored": True,
            "addOptions": {"searchForMovie": False},
        }
    )
    added = radarr.request("movie", method="POST", data=payload)
    return f"{added.get('title')} ({added.get('year')})"


def add_sonarr_series(sonarr: Client, tvdb_id: int, root: str, profile: int) -> str:
    matches = sonarr.request(f"series/lookup?term=tvdb:{tvdb_id}")
    if not matches:
        raise RuntimeError(f"Sonarr lookup returned nothing for tvdb:{tvdb_id}")
    series = dict(matches[0])
    for season in series.get("seasons", []):
        season["monitored"] = True
    series.update(
        {
            "qualityProfileId": profile,
            "rootFolderPath": root,
            "monitored": True,
            "seasonFolder": True,
            "seriesType": "standard",
            "addOptions": {"monitor": "all", "searchForMissingEpisodes": False},
        }
    )
    added = sonarr.request("series", method="POST", data=series)
    return f"{added.get('title')} ({added.get('year') or added.get('firstAired', '')[:4]})"


def main() -> int:
    load_env()
    parser = argparse.ArgumentParser(description="Personalized Radarr/Sonarr auto-importer")
    parser.add_argument("--apply", action="store_true", help="Actually add candidates. Default is dry-run.")
    parser.add_argument("--max-movies", type=int, default=2)
    parser.add_argument("--max-tv", type=int, default=1)
    parser.add_argument("--min-score", type=float, default=75.0)
    parser.add_argument("--min-movie-year", type=int, default=int(os.environ.get("SMART_IMPORT_MIN_MOVIE_YEAR", "1990")))
    parser.add_argument("--min-tv-year", type=int, default=int(os.environ.get("SMART_IMPORT_MIN_TV_YEAR", "2000")))
    parser.add_argument("--radarr-root", default=os.environ.get("SMART_IMPORT_RADARR_ROOT", "/movies-b"))
    parser.add_argument("--sonarr-root", default=os.environ.get("SMART_IMPORT_SONARR_ROOT", "/tv-2"))
    parser.add_argument("--quality-profile", type=int, default=int(os.environ.get("SMART_IMPORT_QUALITY_PROFILE", "4")))
    args = parser.parse_args()

    radarr = env_client("RADARR")
    sonarr = env_client("SONARR")
    js = env_client("JELLYSEERR", "api/v1")
    jf = env_client("JELLYFIN", "")
    missing = [name for name, client in [("RADARR", radarr), ("SONARR", sonarr), ("JELLYSEERR", js), ("JELLYFIN", jf)] if client is None]
    if missing:
        print(f"Missing env for: {', '.join(missing)}", file=sys.stderr)
        return 2
    assert radarr and sonarr and js and jf

    js_movies, js_tv, movie_genres, tv_genres = seed_from_jellyseerr(js)
    jf_movies, jf_tv, jf_movie_genres, jf_tv_genres = seed_from_jellyfin(jf, js)
    movie_seeds = unique_recent(jf_movies + js_movies, 20)
    tv_seeds = unique_recent(jf_tv + js_tv, 20)
    movie_genres.update(jf_movie_genres)
    tv_genres.update(jf_tv_genres)

    print(f"Seeds: movies={len(movie_seeds)} tv={len(tv_seeds)}")
    print("Movie taste genres:", ", ".join(f"{g}({c})" for g, c in movie_genres.most_common(8)) or "none")
    print("TV taste genres:", ", ".join(f"{g}({c})" for g, c in tv_genres.most_common(8)) or "none")

    known_movies, known_tv = already_known_jellyseerr(js)
    movie_candidates = filter_movies(
        js,
        recommendations(js, "movie", movie_seeds),
        existing_radarr_tmdb(radarr),
        known_movies,
        movie_genres,
        args.min_movie_year,
    )
    tv_candidates = filter_tv(
        js,
        recommendations(js, "tv", tv_seeds),
        sonarr,
        existing_sonarr_tvdb(sonarr),
        known_tv,
        tv_genres,
        args.min_tv_year,
    )

    movie_pick = [m for m in movie_candidates if m["score"] >= args.min_score][: args.max_movies]
    tv_pick = [t for t in tv_candidates if t["score"] >= args.min_score][: args.max_tv]

    print("\nTop movie candidates:")
    for m in movie_candidates[:10]:
        print(f"  {m['score']:>6}  {m.get('title')} ({(m.get('releaseDate') or m.get('release_date') or '')[:4]})  genres={','.join(sorted(genres_of(m)))}")
    print("\nTop TV candidates:")
    for t in tv_candidates[:10]:
        print(f"  {t['score']:>6}  {t.get('name')} ({(t.get('firstAirDate') or t.get('first_air_date') or '')[:4]})  tvdb={t.get('tvdbId')} genres={','.join(sorted(genres_of(t)))}")

    if not args.apply:
        print("\nDRY RUN: no additions made. Use --apply to add selected candidates.")
        return 0

    print("\nApplying selected additions...")
    added_any = False
    for m in movie_pick:
        try:
            print("  Radarr +", add_radarr_movie(radarr, int(m["id"]), args.radarr_root, args.quality_profile))
            added_any = True
        except Exception as e:
            print(f"  Radarr FAILED {m.get('title')}: {e}", file=sys.stderr)
    for t in tv_pick:
        try:
            print("  Sonarr +", add_sonarr_series(sonarr, int(t["tvdbId"]), args.sonarr_root, args.quality_profile))
            added_any = True
        except Exception as e:
            print(f"  Sonarr FAILED {t.get('name')}: {e}", file=sys.stderr)
    if not added_any:
        print("  Nothing met the threshold. The machine showed restraint; note this historic event.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
