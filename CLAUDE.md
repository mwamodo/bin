# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository containing configuration files for macOS and Linux development environments. The repository uses symbolic linking to set up development tools and environments.

## Installation and Setup

### Installation Command
```bash
cd $HOME/bin
chmod +x install
./install
```

The install script supports:
- `./install -n` - Dry run mode (show what would be linked)
- `./install -v` - Verbose output

### Prerequisites
- git
- oh-my-zsh
- tmux  
- neovim
- fzf (optional, for the `t` helper script)

## Key Scripts and Utilities

### Project Session Helper (`scripts/t`)
- **Location**: `scripts/t`
- **Purpose**: Creates or attaches to tmux sessions for project directories
- **Usage**: `t [directory]` or `t` (uses fzf to select from ~/Code/Herd)
- **Installed to**: `~/.local/bin/t`

### Shell Functions (in `.zshrc`)
- `commit [message]` - Git add all and commit (defaults to "WIP")
- `commit:push [message]` - Commit and push to current branch
- `schedule:run` - Runs Laravel scheduler in a loop
- `artisan:test-with-coverage` - Runs tests with HTML coverage report
- `lab [command]` - SSH to home lab server

## Development Environment

### Laravel Development Aliases
Key Laravel aliases from `zsh/aliases.sh`:
- `a` / `art` / `artisan` - php artisan
- `a:t` - Run tests
- `a:tt` - Run tests with coverage
- `acc` - Cache clear
- `mf` - Migrate
- `mfs` - Fresh migrate with seed
- `tinker` - Laravel tinker
- `lint` / `fix` - Duster linting and fixing

### General Development Aliases  
- `vim` / `vi` / `v` - Opens neovim
- `n:d` / `nd` - npm run dev
- `n:b` / `nb` - npm run build
- `c` - Git commit function
- `reload` - Reload .zshrc

## Architecture and Structure

### Configuration Structure
- **Shell**: `.zshrc` loads from `zsh/aliases.sh` and `zsh/exports.sh`
- **Terminal**: Multiple terminal configs (Warp, Ghostty)
- **Window Management**: Yabai + SKHD (macOS) and AeroSpace configurations
- **Editor**: Neovim with Kickstart-based config in `nvim/`
- **Multiplexer**: tmux configuration with vim-style bindings

### Platform-Specific Configurations
- **macOS**: Ghostty, Yabai, SKHD configurations
- **Common**: Neovim, tmux, Warp, git configurations

### Environment Integration
- Herd for PHP development
- NVM for Node.js version management
- Zinit for zsh plugin management
- 1Password SSH agent integration
- Automatic .nvmrc detection and Node version switching

## Window Management

### AeroSpace (Primary - newer)
- Tiling window manager with vim-style navigation
- `alt + h/j/k/l` - Focus windows
- `alt + shift + h/j/k/l` - Move windows
- `alt + 1-9` - Switch workspaces

### Yabai + SKHD (Legacy)
- Float layout by default
- Similar vim-style bindings for window management
- Application-specific rules for floating windows