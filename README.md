# $HOME/bin on steroids 

## usage & installation

1. clone the repo to $HOME dir
2. install zsh
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
