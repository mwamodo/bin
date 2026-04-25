# Dotfiles

Configs, customizations, and themes to personalize my macOS experience, with a heavy focus on **Laravel (Herd)** development and modern CLI tools.

> [!IMPORTANT]
> Feel free to look around, contribute and suggest improvements. However, these will remain my personal config files/preferences written to selfishly fit my needs.

## Features

- **Shell**: **Zsh** optimized with [`zinit`](https://github.com/zdharma-continuum/zinit) for fast plugin loading and **Powerlevel10k** instant prompt.
- **Terminals**: **WezTerm** and **Ghostty** — both styled with the **Catppuccin** theme.
- **Navigation**: **zoxide** (`cd`) for smarter directory jumping.
- **Session Management**: **Tmux** with TPM, a custom `t` helper script, and plugins for sessions, floating panes, URL opening, and persistent resurrection.
- **Editor**: **Neovim** (kickstart-based, `lazy.nvim`, Catppuccin theme) — aliased to `vim` and `vi`.
- **Laravel Integration**: deep integration with **Herd**, **Artisan**, **Composer**, and **NPM**, including extensive aliases and helper functions.
- **Modern CLI Tools**: Replaces standard tools with better alternatives:
  - `ls` → `lsd` (icons, colors)
  - `cat` → `bat` (syntax highlighting)
  - `top` → `bpytop` (beautiful resource monitoring)
  - `neofetch` → `fastfetch` (system info)
- **AI & Dev Tools**: Claude CLI, LM Studio, WakaTime (Neovim).
- **Home Lab Helpers**: SSH shortcuts, Wake-on-LAN, and Transmission remote control.

## Prerequisites

Ensure you have the following installed before running the setup:

1. **git**
2. **zsh**
3. **tmux**
4. **neovim**
5. **fzf** (Required for the `t` script and shell integrations)
6. **Recommended Modern Tools**:
   - `lsd`
   - `bat`
   - `zoxide`
   - `fastfetch`
   - `bpytop`

## Installation

1. Set `zsh` as your default shell.
2. Clone the repository to your home directory:
   ```bash
   git clone https://github.com/yourusername/dotfiles.git $HOME/bin
   ```
3. Run the installation script:

   ```bash
   cd $HOME/bin
   chmod +x install
   ./install
   ```

### What the install script does

The `install` script links configuration files from this repo to your home directory.

- **Dry run**: `./install -n` (See what happens without changes)
- **Verbose**: `./install -v` (Detailed output)
- **Safe**: Backs up existing configurations before linking (never deletes them).

It also clones **Powerlevel10k** automatically if it isn't already present.

## Directory Structure

| Path | Description |
| :--- | :--- |
| **`zsh/`** | Shell aliases (`aliases.sh`) and environment exports/integrations (`exports.sh`). |
| **`tmux/`** | Tmux configuration, TPM plugins, and helper scripts. |
| **`nvim/`** | Complete Neovim configuration based on kickstart.nvim. |
| **`wezterm/`** | WezTerm terminal configuration (Monaspace Krypton font, Catppuccin Mocha). |
| **`ghostty/`** | Ghostty terminal configuration (Dank Mono font, Catppuccin adaptive theme). |
| **`scripts/`** | Custom scripts, including the `t` session helper and `transmission` controller. |
| **`.zshrc`** | Main shell configuration file (zinit plugins, keybindings, history, completions). |

## Usage & Configuration

### Environment Variables

Create a `.env` file in `~/bin/` to store local secrets and machine-specific configs. This file is ignored by git and safely loaded on shell startup.

```bash
# Example ~/bin/.env
HOME_IP=192.168.1.5
HOME_MAC=aa:bb:cc:dd:ee:ff
HOME_TRANSMISSION_PORT=9091
HOME_TRANSMISSION_USERNAME=admin
HOME_TRANSMISSION_PASSWORD=secret
```

### Node Version Management

The shell automatically detects `.nvmrc` files and switches Node versions via **nvm** when changing directories.

### Top Aliases

#### Laravel & PHP

| Alias | Command | Description |
| :--- | :--- | :--- |
| `a` | `php artisan` | Run artisan commands |
| `mf` | `a migrate` | Run migrations |
| `mfs` | `a migrate:fresh --seed && a optimize:clear` | Fresh migration with seeds |
| `mfsr` | `mfs && redis-cli flushdb` | Fresh migration, seed, and flush Redis |
| `tinker` | `a tinker` | Enter execution loop |
| `a:t` | `artisan:test` | Run tests |
| `a:tp` | `a:t --parallel` | Run tests in parallel |
| `a:tt` | `artisan:test-with-coverage` | Run tests with HTML coverage report |
| `a:cc` | `a cache:clear` | Clear caches |
| `a:op` | `a optimize:clear` | Clear optimized files |
| `ide:helper` | `a ide-helper:generate && a ide-helper:meta && a ide-helper:models --nowrite` | Generate IDE helpers |
| `duster` | `./vendor/bin/duster` | Run Laravel Duster |
| `lint` | `duster lint` | Lint code |
| `fix` | `duster fix` | Auto-fix code |
| `expose` | `expose --server-host=repounlock.com` | Expose local site |
| `share` / `h:s` | `herd share --server-host=repounlock.com` | Share via Herd |

#### Git

| Alias | Command | Description |
| :--- | :--- | :--- |
| `g` | `git` | Git shorthand |
| `gst` | `git status` | Status |
| `ga` | `git add` | Stage files |
| `gaa` | `git add .` | Stage all |
| `gc` | `git commit` | Commit |
| `gcm` | `git commit -m` | Commit with message |
| `gp` | `git push` | Push |
| `gco` | `git checkout` | Checkout branch |
| `gd` | `git diff` | Diff |
| `gl` / `gll` | `git log` / `git log --oneline --graph` | Log |

#### System & Tools

| Alias | Command | Description |
| :--- | :--- | :--- |
| `l` / `ls` | `lsd` | List files with icons |
| `la` | `lsd -A` | List all files |
| `ll` | `lsd -Fl` | List with details |
| `cat` | `bat` | View file with syntax highlighting |
| `top` | `bpytop` | System resource monitor |
| `neofetch` | `fastfetch` | System info |
| `tm` | `tmux -u` | Start Tmux |
| `vim` / `vi` / `v` | `nvim` | Open Neovim |
| `cc` | `claude --dangerously-skip-permissions` | Claude CLI |
| `ccr` | `claude --resume` | Resume Claude session |

### Helper Functions

| Function | Description |
| :--- | :--- |
| `commit [message]` | Stage all and commit (`WIP` if no message) |
| `commit:push [message]` / `wip` | Stage, commit, and push to current branch |
| `switch:master` | Checkout master and pull |
| `schedule:run` | Loop `php artisan schedule:run` every 60 seconds |
| `artisan:test-with-coverage` | Run tests with coverage and open in browser |
| `lab [command]` | SSH into home server, or run a remote command |
| `lab:suspend` | Suspend home server |
| `lab:sleep` | Suspend home server with RTC wake time |
| `lab:wake` | Wake home server via Wake-on-LAN |

### Tmux Smart Session Manager (`t`)

The `t` script (linked to `~/.local/bin/t`) is a powerhouse for managing workflow.

- **`t`**: Opens `fzf` to select a project from `~/code`, `~/code/turbine/products`, `~/code/turbine/internal`, or `~/bin`.
- **`t [directory]`**: Directly opens or attaches to a tmux session for that directory.

It automatically names sessions based on the folder name and handles attaching/detaching seamlessly.

### Tmux Plugins & Features

Plugins are managed via [TPM](https://github.com/tmux-plugins/tpm). Key features include:

- **Catppuccin theme** with custom status modules: session, directory, todos, meetings (calendar), and date/time.
- **`tmux-sessionx`** (`Ctrl-a` + `s`): Fuzzy session switcher with zoxide integration.
- **`tmux-floax`** (`Ctrl-a` + `p`): Floating popup window for quick tasks.
- **`tmux-fzf-url`**: Open URLs from the buffer with `fzf`.
- **`tmux-thumbs`**: Rapid copy-paste of file paths, IPs, etc.
- **`tmux-resurrect` / `tmux-continuum`**: Automatic session save and restore.
- **Smart navigation**: `Ctrl-h/j/k/l` seamlessly moves between vim and tmux panes.

### Transmission Remote Controller (`transmission`)

A Python CLI script to manage a remote Transmission daemon.

```bash
transmission --list              # List all torrents
transmission --downloading       # List active downloads
transmission --pause-all         # Pause everything
transmission --start-all         # Resume everything
transmission --stop 1 2 3        # Stop specific torrent IDs
```
