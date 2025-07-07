# Dotfiles

This Repository Dotfiles contain my personal config files. Here you'll find configs, customizations, themes, and whatever I need to personalize my Linux and mac OS experience.

> ⚠️ Be aware, products can change over time. I do my best to keep up with the latest changes and releases, but please understand that this won’t always be the case.

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
chmod +x install.sh
./install.sh
```

## TODO

1. add brew to the installation script
