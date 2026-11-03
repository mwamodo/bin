# Lab scripts (AGENTS.md)

Skills define *how* tools work. This file is for *your* specifics — the stuff that's unique to your setup.

## Scripts Convention

- **Lab scripts live in `~/bin/lab/scripts/`** (this repo is public: `mwamodo/bin`). On the lab host, `~/bin/scripts/<name>` symlinks keep old paths working.
- **Write scripts for repeatable tasks** — if you'll do it more than once, script it
- **Secrets go in `~/bin/lab/scripts/.env`** (copy `.env.example`) — gitignored, never committed. Never hardcode hosts, IPs, keys or personal paths.

## Location

- **Runs on the lab home server only.** Nothing here is linked or put on PATH on the Mac.

## Jellyfin (`jellyfin.sh`)

- **check who's watching:** `./jellyfin.sh status`
- **list libraries:** `./jellyfin.sh libraries`
- **scan library:** `./jellyfin.sh scan <library-id>`
- **search:** `./jellyfin.sh search <query>`
- **recently added:** `./jellyfin.sh latest [limit]`

## Radarr (`radarr.sh`)

- **list movies:** `./radarr.sh list`
- **search movie:** `./radarr.sh search <title>`
- **add movie:** `./radarr.sh add <tmdb-id>`
- **download queue:** `./radarr.sh queue`
- **calendar:** `./radarr.sh calendar [days]`

## Smart Arr Import (`smart-arr-import.py`)

- **dry run personalized recommendations:** `./smart-arr-import.py --max-movies 3 --max-tv 3`
- **apply conservative auto-add:** `./smart-arr-import.py --apply --max-movies 1 --max-tv 1 --min-score 120`
- Uses Jellyfin watched history + Jellyseerr requests as taste seeds, then Jellyseerr/TMDB recommendations, then adds top-scoring missing Movies/TV to Radarr/Sonarr without immediate search.
- Weekly Hermes no-agent cron wrapper: `~/.hermes/scripts/smart-arr-import-weekly.sh` → Sundays 12:30 EAT. Logs to `~/bin/scripts/smart-arr-import.log`.

## Sonarr (`sonarr.sh`)

- **list series:** `./sonarr.sh list`
- **search series:** `./sonarr.sh search <title>`
- **episodes:** `./sonarr.sh episodes <series-id>`
- **download queue:** `./sonarr.sh queue`
- **calendar:** `./sonarr.sh calendar [days]`

## Prowlarr (`prowlarr.sh`)

- **list indexers:** `./prowlarr.sh list`
- **health check:** `./prowlarr.sh health`
- **search:** `./prowlarr.sh search <query>`
- **stats:** `./prowlarr.sh stats`

## Transmission

- **list torrents:** `~/bin/scripts/transmission-list.sh`
- **remove torrent:** `~/bin/scripts/transmission-remove.sh <id> [--delete-data]`
- **cleanup completed:** `~/bin/scripts/transmission-cleanup.sh`
- **control:** `~/bin/scripts/transmission-control.sh <pause|resume|toggle> <id|all>`

## meTube (`metube.sh`)

- **list downloads:** `./metube.sh list`
- **add URL:** `./metube.sh add <url>`
- **queue status:** `./metube.sh queue`
- **remove:** `./metube.sh remove <id>`
- **clear history:** `./metube.sh clear`

## Jellyseerr (`jellyseerr.sh`)

- **status:** `./jellyseerr.sh status`
- **pending requests:** `./jellyseerr.sh requests` (needs API key in .env)
- **request counts:** `./jellyseerr.sh count`

## Jellystat (`jellystat.sh`)

- **recent activity:** `./jellystat.sh activity [limit]`
- **most active users:** `./jellystat.sh users`
- **most viewed:** `./jellystat.sh top`
- **library overview:** `./jellystat.sh libraries`
- **recently added:** `./jellystat.sh recent`
- **views over time:** `./jellystat.sh views`

## Lab Management

- **sleep if idle:** `~/bin/scripts/lab-sleep.sh` — Jellyfin-aware suspend (cron @ 02:00)
- **simple suspend:** `~/bin/night-sleep-rtcwake.sh` — rtcwake with `--dry-run` support
- **reddit downloader:** `~/bin/scripts/reddit.py --subreddit <name> [--sort top|hot]`

## Root Escalation (`sudo.sh`)

- (`sudo.sh` is local-only, not in this repo.)
- **Run a command as root non-interactively** when sudoers is broken/unavailable: `~/bin/scripts/sudo.sh <command...>`
  - Reads `SUDO_PASSWORD` from `scripts/.env`, then falls back to `$HOME/.hermes/.env` (which Hermes itself uses for credentials).
  - Pipes the password to `su -c '<cmd>' root` via stdin — never as a command-line arg, so it does not show in `ps`/shell history.
  - **Note:** `sudo` binary on this host is broken (`sudo-rs` without suid bit, every `sudo -n` fails with "must be owned by uid 0 and have the setuid bit set"). Use `sudo.sh` instead.
  - **Verified 2026-06-26** with `/tmp/hermes-verify-sudo.sh`: file/mode/syntax, refuse-on-missing-password, refuse-on-no-args, argument quoting (spaces/apostrophes/$literals), password-not-in-ps-or-/proc, end-to-end (inconclusive on this host — see "if it fails" below).

### If the password is rejected

`su: Authentication failure` means `SUDO_PASSWORD` doesn't match this host's root account. Likely cause: it's the password for a different host (another service, container or machine). Do not retry with variations — that's the kind of thing that gets accounts locked. Ask the user, or have them escalate from a host that *does* have working auth.

## Media Operations Toolkit

### Transmission Diagnosis (`transmission-diagnose.sh`)

- **diagnose all active torrents:** `./transmission-diagnose.sh`
- **deep-dive one torrent:** `./transmission-diagnose.sh <torrent-id>`
- Checks: progress, peers, trackers, ASN blocklist hint, seed ratio, ETA
- Categorizes: healthy, slow, stalled, seeding, errors

### Downloads Audit (`downloads-audit.sh`)

- **full audit:** `./downloads-audit.sh`
- **orphans only:** `./downloads-audit.sh --orphans`
- **old incomplete:** `./downloads-audit.sh --old-days 14`
- **complete only:** `./downloads-audit.sh --complete-only`
- Checks: orphaned incomplete dirs, old stuck downloads, completed items not imported, space usage

### Suspicious Episode Detection (`suspicious-episode-detect.sh`)

- **scan all:** `./suspicious-episode-detect.sh`
- **downloads only:** `./suspicious-episode-detect.sh --downloads`
- **library only:** `./suspicious-episode-detect.sh --library`
- **quarantine suspicious files:** `./suspicious-episode-detect.sh --fix`
- Flags: `.exe`/`.bat`/etc masquerading as video, double extensions, video-looking names with no video ext

### Missing Episode Search (`missing-episode-search.sh`)

- **all monitored series:** `./missing-episode-search.sh`
- **one show:** `./missing-episode-search.sh --show "Rick and Morty"`
- **one season:** `./missing-episode-search.sh --show "Rick and Morty" --season 9`
- **skip future episodes:** `./missing-episode-search.sh --missing-only`
- Cross-references: Sonarr wanted list, library on disk, downloads/complete
- Distinguishes: not aired yet, in downloads pending import, in library but Sonarr unaware, truly missing

### Audiobook Import (`audiobook-import.sh`)

- **dry run:** `./audiobook-import.sh --dry-run`
- **import for real:** `./audiobook-import.sh`
- Scans downloads/complete for audio files and moves to `/mnt/DRIVE_A/Audiobooks/<Title>`

### Jellyfin Health (`jellyfin-health.sh`)

- **active sessions + transcode info:** `./jellyfin-health.sh sessions`
- **known devices:** `./jellyfin-health.sh devices`
- **active transcodes:** `./jellyfin-health.sh transcodes`
- **recent log warnings:** `./jellyfin-health.sh logs [lines]`
- **everything:** `./jellyfin-health.sh full`

### Media Services Check (`media-services-check.sh`)

- **human readable:** `./media-services-check.sh`
- **JSON output:** `./media-services-check.sh --json`
- Checks: Jellyfin, Jellyseerr, Jellystat, Radarr, Sonarr, Prowlarr, Transmission, Audiobookshelf, metube

