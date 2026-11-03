# lab/

Scripts for the Linux home-lab server only. See `AGENTS.md` for usage.

- Not linked by `../install` and not on the Mac `PATH` (`zsh/exports.sh` only adds `~/bin/scripts`).
- Secrets: copy `scripts/.env.example` to `scripts/.env` (gitignored).
- On the lab host, run `./link-lab-compat.sh` once to keep legacy `~/bin/scripts/*` paths working.
- `tmux/tmux.conf` is the Linux tmux config; point `~/.config/tmux/tmux.conf` at it on the lab host.
