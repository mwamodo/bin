# $HOME/bin on steroids 

## Prerequisites
1. git

## usage & installation

1. clone the repo to $HOME dir

2. install `zsh` & `oh my zsh` and link your $HOME/.zshrc to $HOME/bin/.vimrc

```bash
# Backup your .zshrc file
mv "${HOME}/.zshrc" "${HOME}/.zshrc-old"

# Link file
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