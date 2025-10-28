# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository for macOS that manages shell configuration, terminal setup, window management, and development environment customization. The repository uses symbolic linking to deploy configuration files from a central location (`~/bin`) to their expected system locations.

## Installation & Setup

### Initial Setup
```bash
cd $HOME/bin
chmod +x install
./install
```

The `install` script supports:
- `-n` flag for dry run (preview changes without executing)
- `-v` flag for verbose output

### What Gets Linked
- `.zshrc` → Shell configuration
- `tmux/tmux.conf` → `~/.tmux.conf`
- `nvim/` → `~/.config/nvim`
- `yabai/` → `~/.config/yabai` (macOS only)
- `skhd/` → `~/.config/skhd` (macOS only)
- `wezterm/` → `~/.config/wezterm` (macOS only)
- `.gitignore` → Global git ignore

## Architecture

### Shell Configuration (ZSH)
The `.zshrc` follows a specific loading order to avoid conflicts with Powerlevel10k instant prompt:
1. Environment variables from `.env` file
2. Shell integrations (brew, zoxide, etc.)
3. Powerlevel10k instant prompt
4. Zinit plugin manager and plugins
5. Custom aliases and exports from `zsh/` directory

**Key Components:**
- `zsh/aliases.sh` - Command shortcuts (heavily Laravel/PHP focused)
- `zsh/exports.sh` - Environment variables, PATH modifications, and shell functions
- Zinit manages plugins: syntax-highlighting, completions, autosuggestions, fzf-tab

### Development Environment Focus
This setup is optimized for **Laravel/PHP development** with:
- Laravel Herd integration for PHP/Composer
- Extensive Laravel artisan command aliases
- Database management via DBngin (MySQL, Redis)
- Node.js via NVM with auto-version switching

### Helper Scripts (`scripts/`)
- **`t`** - Tmux session manager: Creates/attaches to tmux sessions for projects in `~/Code/Herd` or `~/bin`. Uses fzf for selection when no directory is specified.
- **`space`** - Yabai layout setter: Quickly set per-space window layouts (e.g., `space -1f -2s -3b` for float/stack/bsp)

### Window Management (macOS)
- **Yabai** (`yabai/yabairc`) - Tiling window manager configuration
- **SKHD** (`skhd/skhdrc`) - Hotkey daemon for window management shortcuts

## Common Commands

### Shell Operations
```bash
reload              # Reload .zshrc configuration
```

### Laravel Development
```bash
a <command>         # Shortcut for php artisan
a:t                 # Run tests
a:tt                # Run tests with coverage (opens in browser)
a:tp                # Run tests in parallel
a:ts                # Run tests with stop-on-failure
mff                 # Migrate fresh
mfs                 # Migrate fresh with seed
lint / fix          # Run duster linting/fixing
```

### Git Workflow
```bash
c "message"         # git add . && git commit -m "message" (defaults to "WIP")
c:p "message"       # Commit and push to current branch
```

### Tmux/Project Management
```bash
t                   # Launch tmux session picker (uses fzf)
t ~/path/to/project # Create/attach to tmux session for specific directory
```

### Window Management
```bash
space -1f -2s -3b   # Set space 1 to float, space 2 to stack, space 3 to bsp
```

## Development Notes

### Path Management
Custom scripts in `scripts/` are automatically added to PATH via `exports.sh`. The PATH includes:
- `~/.local/bin` (for user scripts)
- `~/.npm-packages/bin` (global npm packages)
- `~/bin/scripts` (this repo's scripts)
- Laravel Herd PHP and Composer
- DBngin MySQL and Redis
- Pyenv for Python version management

### Shell Functions (in `exports.sh`)
- `commit()` / `commit:push()` - Git workflow helpers
- `schedule:run()` - Run Laravel scheduler in loop
- `artisan:test-with-coverage()` - Run tests and open coverage report
- `lab()` / `pihole()` - SSH helpers for home servers (requires HOME_IP and PIHOLE_IP in .env)
- `set_name()` - Sets Warp tab name to current directory

### Environment Variables
The `.env` file in this repository is loaded by `.zshrc` and should contain:
- `HOME_IP` - IP for home lab server
- `PIHOLE_IP` - IP for Pi-hole server

### NVM Integration
The shell automatically detects `.nvmrc` files and switches Node.js versions when changing directories.

## File Structure Philosophy

- Configuration files are kept in their respective directories (tmux/, nvim/, yabai/, etc.)
- Shell customizations are modular: `.zshrc` orchestrates loading, while `zsh/` contains the actual configuration
- Scripts in `scripts/` are meant to be in PATH and used as commands
- The `install` script is the single source of truth for what gets linked where

## Tools & Dependencies

**Required:**
- git
- zsh
- tmux
- neovim
- fzf (optional, for the `t` helper)

**Recommended:**
- Laravel Herd (PHP/Composer)
- Homebrew
- lsd (modern ls replacement)
- bat (modern cat replacement)
- bpytop (system monitoring)
- fastfetch (system info)
- zoxide (smart cd replacement)
- yabai + skhd (window management, macOS only)

## Customization Guidelines

When modifying this repository:
1. **Aliases**: Add to `zsh/aliases.sh`
2. **Environment Variables**: Add to `zsh/exports.sh`
3. **Functions**: Add to `zsh/exports.sh`
4. **New Configs**: Create directory, update `install` script
5. **Scripts**: Add to `scripts/` directory (must be executable)

After changes, run `reload` or restart your terminal to apply.
