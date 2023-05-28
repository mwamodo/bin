# Dotfiles

This Repository Dotfiles contain my personal config files. Here you'll find configs, customizations, themes, and whatever I need to personalize my Linux and mac OS experience.

> ⚠️ Be aware, products can change over time. I do my best to keep up with the latest changes and releases, but please understand that this won’t always be the case.

## Prerequisites
1. git

## usage & installation

1. clone the repo to $HOME dir

2. install `oh-my-zsh` and link your $HOME/.zshrc to $HOME/bin/.vimrc

```bash
# run the command below an be found https://ohmyz.sh/#install
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# backup the original .zshrc file
mv "${HOME}/.zshrc" "${HOME}/.zshrc-old"

# link file
ln -s "${HOME}/bin/.zshrc" "${HOME}/.zshrc"
```

3. link your $HOME/.vimrc to $HOME/bin/.vimrc

```bash
ln -s "${HOME}/bin/.vimrc" "${HOME}/.vimrc"
```

4. create .vim, and .vim/colors directory

```bash
mkdir -p "${HOME}/.vim/colors"
```

5. copy vim themes to the created colors directory

```bash
cp "${HOME}/bin/vim/colors/cobalt2.vim" "${HOME}/.vim/colors"
cp "${HOME}/bin/vim/colors/atom-dark.vim" "${HOME}/.vim/colors"
```

6. set up vim plugins with Vundle

```bash
mkdir -p "${HOME}/.vim/bundle"
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
ln -s "${HOME}/bin/vim/plugins.vim" "${HOME}/.vim/plugins.vim"
vim +PluginInstall +qall
```

## aditional optional settings

1. create global .gitignore file

```bash
# link gitignore global
ln -s "${HOME}/bin/.gitignore_global" "${HOME}/.gitignore"
```

2. add git global gitignore

```bash
# tell git about the global gitignore file
git config --global core.excludesfile ~/.gitignore
```

3. install dependancies

```bash
# install truncate. required in laravel alias log:clear
brew install truncate
```
