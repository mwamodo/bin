# Dotfiles

Configs, customizations, and themes to personalize my macOS experience, with a heavy focus on **Laravel (Herd)** development and modern CLI tools.

> [!IMPORTANT]
> Feel free to look around, contribute and suggest improvements. However, these will remain my personal config files/preferences written to selfishly fit my needs.

## Features

-   **Shell**: **Zsh** optimized with `zinit` for fast plugin loading.
-   **Theme**: **Powerlevel10k** for a highly informative and responsive prompt.
-   **Navigation**: **zoxide** (`z`) for smarter directory jumping.
-   **Session Management**: **Tmux** with a custom `t` helper script for instant project switching.
-   **Editor**: **Neovim** (aliased to `vim` and `vi`) as the primary text editor.
-   **Laravel Integration**: deep integration with **Herd** and **Artisan**, including extensive aliases.
-   **Modern CLI Tools**: Replaces standard tools with better alternatives:
    -   `ls` → `lsd` (icons, colors)
    -   `cat` → `bat` (syntax highlighting)
    -   `top` → `bpytop` (beautiful resource monitoring)
    -   `neofetch` → `fastfetch` (system info)

## Prerequisites

Ensure you have the following installed before running the setup:

1.  **git**
2.  **zsh**
3.  **tmux**
4.  **neovim**
5.  **fzf** (Required for the `t` script)
6.  **Recommended Modern Tools**:
    -   `lsd`
    -   `bat`
    -   `zoxide`
    -   `fastfetch`
    -   `bpytop`

## Installation

1.  Set `zsh` as your default shell.
2.  Clone the repository to your home directory:
    ```bash
    git clone https://github.com/yourusername/dotfiles.git $HOME/bin
    ```
3.  Run the installation script:

    ```bash
    cd $HOME/bin
    chmod +x install
    ./install
    ```

### What the install script does

The `install` script links configuration files from this repo to your home directory.

-   **Dry run**: `./install -n` (See what happens without changes)
-   **Verbose**: `./install -v` (Detailed output)
-   **Safe**: Backs up/removes existing configurations before linking.

## Directory Structure

-   **`zsh/`**: Contains shell aliases (`aliases.sh`) and environment exports (`exports.sh`).
-   **`tmux/`**: Tmux configuration and themes.
-   **`nvim/`**: Complete Neovim configuration.
-   **`scripts/`**: Custom scripts, including the `t` session helper.
-   **`.zshrc`**: Main shell configuration file.

## Usage & Configuration

### Environment Variables
Create a `.env` file in `~/bin/` to store local secrets and machine-specific configs. This file is ignored by git.
```bash
# Example ~/bin/.env
HOME_IP=192.168.1.5
```

### Top Aliases

| Alias | Command | Description |
| :--- | :--- | :--- |
| `a` | `php artisan` | Run artisan commands |
| `mf` | `a migrate` | Run migrations |
| `mfs` | `a migrate:fresh --seed` | Fresh migration with seeds |
| `tinker` | `a tinker` | Enter execution loop |
| `gp` | `git push` | Push to remote |
| `gco` | `git checkout` | Checkout branch |
| `l` | `lsd` | List files with icons |
| `cat` | `bat` | View file with highlighting |
| `tm` | `tmux -u` | Start Tmux |

### Tmux Smart Session Manager (`t`)

The `t` script (linked to `~/.local/bin/t`) is a powerhouse for managing workflow.

-   **`t`**: Opens a fuzzy finder (`fzf`) to select a project from `~/Code/Herd` or `~/bin`.
-   **`t [directory]`**: Directly opens or attaches to a tmux session for that directory.

It automatically names sessions based on the folder name and handles attaching/detaching seamlessly.
