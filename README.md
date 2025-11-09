# Dotfiles

Configs, customizations, themes, and whatever I need to personalize my  mac OS experience.

> [!IMPORTANT]
> Feel free to look around, contribute and suggest improvements. However, these will remain my personal config files/preferences written to selfishly fit my needs.

## Prerequisites

1. git
2. zsh
3. tmux
4. neovim
5. fzf *(optional for the `t` helper)*

## usage & installation

1. set `zsh` as your default shell
2. install `brew` & `git` then clone the repo to $HOME dir
3. run the installation script

```bash
cd $HOME/bin
chmod +x install
./install
```

### What the install script does

The `install` script automatically sets up the dotfiles by creating symbolic links from the home directory to the configuration files in the repo.

#### Features

- **Dry run mode**: Use `./install -n` to see what would be linked without actually creating the links
- **Verbose output**: Use `./install -v` to see detailed output of each operation
- **Safe**: Removes existing files/directories before creating new symbolic links

#### Files and directories linked

- `.zshrc` → Shell configuration
- `.tmux.conf` → Tmux configuration
- `scripts/t` → Helper script (in `~/.local/bin/`)
- `nvim/` → Neovim configuration directory
- `.gitignore` → Global git ignore file

#### What gets created

- `~/.local/bin/` directory (if it doesn't exist)
- `~/.config/` directory (if it doesn't exist)
- `~/Library/Application Support/` directory on macOS (if it doesn't exist)

The script ensures all your dotfiles are properly linked and your development environment is configured consistently across systems.
