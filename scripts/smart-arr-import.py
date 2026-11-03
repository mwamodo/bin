#!/usr/bin/env python3
"""Personalized Sonarr importer (TV only).

Builds a taste profile from Jellyfin watch history (series watched and their
genres; falls back to the Sonarr library if Jellyfin is unavailable), asks Sonarr's series lookup for related shows (same franchise,
spin-offs, title matches), scores the ones not already in Sonarr, and
optionally adds the best ones to Sonarr without an immediate search.

Uses only Jellyfin and Sonarr. Secrets come from scripts/.env next to this file
(JELLYFIN_URL, JELLYFIN_API_KEY, SONARR_URL, SONARR_API_KEY).

Default is DRY RUN. Use --apply for real additions. Re-runs are safe: series
already in Sonarr are always skipped.
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
from collections import Counter
from pathlib import Path
from typing import Any

TODAY = dt.date.today()
EXCLUDED_TV_GENRES = {"Documentary", "News", "Reality", "Talk", "Talk Show", "Game Show"}


def load_env() -> None:
    env_path = Path(__file__).resolve().with_name(".env")
    if not env_path.exists():
        return
    for raw in env_path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


class Client:
    def __init__(self, base: str, api_key: str, api_prefix: str = "") -> None:
        self.base = base.rstrip("/")
        self.api_key = api_key
        self.api_prefix = api_prefix.strip("/")

    def url(self, path: str) -> str:
        path = path.lstrip("/")
        return f"{self.base}/{self.api_prefix}/{path}" if self.api_prefix else f"{self.base}/{path}"

    def request(self, path: str, method: str = "GET", data: Any | None = None, timeout: int = 30) -> Any:
        headers = {
            "Accept": "application/json",
            "X-Api-Key": self.api_key,
            "X-MediaBrowser-Token": self.api_key,
        }
        body = None
        if data is not None:
            body = json.dumps(data).encode()
            headers["Content-Type"] = "application/json"
        req = urllib.request.Request(self.url(path), headers=headers, data=body, method=method)
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                raw = resp.read().decode()
                return json.loads(raw) if raw else None
        except urllib.error.HTTPError as e:
            raw = e.read().decode(errors="replace")
            raise RuntimeError(f"HTTP {e.code} {method} {path}: {raw[:300]}") from e


def env_client(prefix: str, api_prefix: str) -> Client | None:
    base = os.environ.get(f"{prefix}_URL")
    key = os.environ.get(f"{prefix}_API_KEY")
    return Client(base, key, api_prefix) if base and key else None


def parse_date(value: str | None) -> dt.date | None:
    if not value:
        return None
    try:
        return dt.date.fromisoformat(value[:10])
    except ValueError:
        return None


def genres_of(item: dict[str, Any]) -> set[str]:
    out: set[str] = set()
    for g in item.get("genres") or item.get("Genres") or []:
        name = g.get("name") or g.get("Name") if isinstance(g, dict) else g
        if name:
            out.add(str(name))
    return out


def seed_from_jellyfin(jf: Client, per_user: int) -> tuple[list[str], Counter[str]]:
    """Return watched series titles (most recent first) and genre counts."""
    titles: list[str] = []
    genres: Counter[str] = Counter()
    try:
        users = jf.request("Users")
    except Exception as e:
        print(f"WARN: Jellyfin users unavailable: {e}", file=sys.stderr)
        return titles, genres
    seen: set[str] = set()
    for user in users or []:
        uid = user.get("Id")
        if not uid:
            continue
        qs = urllib.parse.urlencode({
            "isPlayed": "true", "recursive": "true", "includeItemTypes": "Episode",
            "sortBy": "DatePlayed", "sortOrder": "Descending",
            "fields": "SeriesName,SeriesId", "limit": str(per_user),
        })
        try:
            data = jf.request(f"Users/{uid}/Items?{qs}")
        except Exception:
            continue
        for item in data.get("Items", []):
            sid = item.get("SeriesId")
            if not sid or sid in seen:
                continue
            seen.add(sid)
            try:
                details = jf.request(f"Items/{sid}?Fields=Genres")
            except Exception:
                details = {}
            name = details.get("Name") or item.get("SeriesName")
            if name:
                titles.append(name)
            genres.update(genres_of(details))
    return titles, genres


def candidates_from_sonarr(sonarr: Client, seeds: list[str], existing: set[int]) -> dict[int, dict[str, Any]]:
    out: dict[int, dict[str, Any]] = {}
    for seed in seeds:
        try:
            results = sonarr.request(f"series/lookup?term={urllib.parse.quote(seed)}")
        except Exception as e:
            print(f"WARN: Sonarr lookup failed for {seed!r}: {e}", file=sys.stderr)
            continue
        for rank, s in enumerate((results or [])[:10], start=1):
            tvdb = s.get("tvdbId")
            if not tvdb or int(tvdb) in existing:
                continue
            c = out.setdefault(int(tvdb), dict(s))
            c.setdefault("_sources", []).append({"seed": seed, "rank": rank})
        time.sleep(0.1)
    return out


def score(item: dict[str, Any], wanted: Counter[str]) -> float:
    rating = float((item.get("ratings") or {}).get("value") or 0)
    votes = int((item.get("ratings") or {}).get("votes") or 0)
    genre_score = sum(wanted.get(g, 0) for g in genres_of(item))
    source_score = sum(max(0, 11 - s["rank"]) for s in item.get("_sources", []))
    value = rating * 8 + min(votes, 2000) / 100 + genre_score * 3 + source_score * 1.5
    if genres_of(item) & EXCLUDED_TV_GENRES:
        value -= 50
    return round(value, 3)


def filter_tv(items: dict[int, dict[str, Any]], wanted: Counter[str], min_year: int, min_rating: float) -> list[dict[str, Any]]:
    out = []
    for item in items.values():
        first = parse_date(item.get("firstAired"))
        rating = float((item.get("ratings") or {}).get("value") or 0)
        if not item.get("title") or not first or first > TODAY or first.year < min_year or rating < min_rating:
            continue
        if genres_of(item) & EXCLUDED_TV_GENRES:
            continue
        item["score"] = score(item, wanted)
        out.append(item)
    return sorted(out, key=lambda x: x["score"], reverse=True)


def add_series(sonarr: Client, item: dict[str, Any], root: str, profile: int) -> str:
    series = {k: v for k, v in item.items() if not k.startswith("_") and k != "score"}
    for season in series.get("seasons", []):
        season["monitored"] = True
    series.update({
        "qualityProfileId": profile, "rootFolderPath": root, "monitored": True,
        "seasonFolder": True, "seriesType": series.get("seriesType") or "standard",
        "addOptions": {"monitor": "all", "searchForMissingEpisodes": False},
    })
    added = sonarr.request("series", method="POST", data=series)
    return f"{added.get('title')} ({added.get('year')})"


def main() -> int:
    load_env()
    p = argparse.ArgumentParser(description="Personalized Sonarr auto-importer (dry run by default)")
    p.add_argument("--apply", action="store_true", help="Actually add series. Default is dry run.")
    p.add_argument("--max-tv", type=int, default=1)
    p.add_argument("--max-movies", type=int, default=0, help="Ignored (Radarr was removed); kept for old callers.")
    p.add_argument("--min-score", type=float, default=75.0)
    p.add_argument("--min-rating", type=float, default=float(os.environ.get("SMART_IMPORT_MIN_RATING", "6.8")))
    p.add_argument("--min-tv-year", type=int, default=int(os.environ.get("SMART_IMPORT_MIN_TV_YEAR", "2000")))
    p.add_argument("--max-seeds", type=int, default=15)
    p.add_argument("--sonarr-root", default=os.environ.get("SMART_IMPORT_SONARR_ROOT"))
    p.add_argument("--quality-profile", type=int, default=os.environ.get("SMART_IMPORT_QUALITY_PROFILE"))
    args = p.parse_args()

    sonarr = env_client("SONARR", "api/v3")
    jf = env_client("JELLYFIN", "")
    missing = [n for n, c in (("SONARR", sonarr), ("JELLYFIN", jf)) if c is None]
    if missing:
        print(f"Missing env for: {', '.join(missing)} (set *_URL and *_API_KEY in scripts/.env)", file=sys.stderr)
        return 2
    assert sonarr and jf

    try:
        library = sonarr.request("series")
    except Exception as e:
        print(f"ERROR: Sonarr unavailable: {e}", file=sys.stderr)
        return 1
    existing = {int(s["tvdbId"]) for s in library if s.get("tvdbId")}

    # Defaults come from Sonarr itself when not configured, so nothing is hardcoded.
    root = args.sonarr_root
    if not root:
        roots = sonarr.request("rootfolder") or []
        root = roots[0]["path"] if roots else None
    profile = args.quality_profile
    if profile is None:
        profiles = sonarr.request("qualityprofile") or []
        profile = profiles[0]["id"] if profiles else None
    profile = int(profile) if profile is not None else None

    titles, genres = seed_from_jellyfin(jf, per_user=80)
    source = "Jellyfin watch history"
    if not titles:
        # Fall back to the Sonarr library itself (most recently added first).
        recent = sorted(library, key=lambda s: s.get("added") or "", reverse=True)
        titles = [s["title"] for s in recent if s.get("title")]
        genres = Counter(g for s in recent for g in genres_of(s))
        source = "Sonarr library (Jellyfin history unavailable)"
    seeds = titles[: args.max_seeds]
    print(f"Seeds: tv={len(seeds)} (from {source})")
    print("TV taste genres:", ", ".join(f"{g}({c})" for g, c in genres.most_common(8)) or "none")

    cands = filter_tv(candidates_from_sonarr(sonarr, seeds, existing), genres, args.min_tv_year, args.min_rating)
    print("\nTop TV candidates:")
    for t in cands[:10]:
        print(f"  {t['score']:>6}  {t.get('title')} ({t.get('year')})  tvdb={t.get('tvdbId')} genres={','.join(sorted(genres_of(t)))}")

    if not args.apply:
        print("\nDRY RUN: no additions made. Use --apply to add selected candidates.")
        return 0
    if not root or profile is None:
        print("ERROR: no Sonarr root folder or quality profile found", file=sys.stderr)
        return 1

    print("\nApplying selected additions...")
    picks = [t for t in cands if t["score"] >= args.min_score][: args.max_tv]
    for t in picks:
        try:
            print("  Sonarr +", add_series(sonarr, t, root, profile))
        except Exception as e:
            print(f"  Sonarr FAILED {t.get('title')}: {e}")
    if not picks:
        print("  Nothing met the threshold.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
