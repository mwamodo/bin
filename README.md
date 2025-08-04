# Dotfiles

This Repository Dotfiles contain my personal config files. Here you'll find configs, customizations, themes, and whatever I need to personalize my Linux and mac OS experience.

> ⚠️ Be aware, products can change over time. I do my best to keep up with the latest changes and releases, but please understand that this won't always be the case.

## Prerequisites

1. git
2. [oh-my-zsh](https://ohmyz.sh/)
3. tmux
4. neovim
5. fzf *(optional for the `t` helper)*

## usage & installation

1. install `git` then clone the repo to $HOME dir

2. install `oh-my-zsh` and link your $HOME/.zshrc to $HOME/bin/.vimrc

```bash
# run the command below an be found https://ohmyz.sh/#install
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

3. run the installation script

```bash
cd $HOME/bin
chmod +x install
./install
```

### What the Install Script Does

The `install` script automatically sets up your dotfiles by creating symbolic links from your home directory to the configuration files in this repository. Here's what it does:

#### Features:
- **Dry Run Mode**: Use `./install -n` to see what would be linked without actually creating the links
- **Verbose Output**: Use `./install -v` to see detailed output of each operation
- **Cross-Platform**: Automatically detects macOS vs Linux and links appropriate files
- **Safe**: Removes existing files/directories before creating new symbolic links

#### Files and Directories Linked:

**Common (Linux & macOS):**
- `.zshrc` → Shell configuration
- `.tmux.conf` → Tmux configuration
- `scripts/t` → Helper script (placed in `~/.local/bin/`)
- `nvim/` → Neovim configuration directory
- `warp/` → Warp terminal configuration
- `.gitignore` → Global git ignore file
- `aerospace.toml` → Aerospace window manager config

**macOS Only:**
- `ghostty/` → Ghostty terminal configuration
- `yabai/` → Yabai window manager configuration
- `skhd/` → SKHD hotkey daemon configuration

#### What Gets Created:
- `~/.local/bin/` directory (if it doesn't exist)
- `~/.config/` directory (if it doesn't exist)
- `~/Library/Application Support/` directory on macOS (if it doesn't exist)

The script ensures all your dotfiles are properly linked and your development environment is configured consistently across systems.

## TODO

1. add brew to the installation script
