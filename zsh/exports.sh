# npm global path to prevent install npm with sudo
NPM_PACKAGES="${HOME}/.npm-packages"

# insert globally installed npm packages to path homebrew to PATH
export PATH="$HOME/.local/bin:$NPM_PACKAGES/bin:/usr/local/mysql/bin:$PATH"

# redis path for DBngin
export PATH="/Users/Shared/DBngin/redis/7.0.0/bin:$PATH"

# mysql path for DBngin
export PATH="/Users/Shared/DBngin/mysql/8.0.33/bin:$PATH"

# Doom Emacs
export PATH="$HOME/.config/emacs/bin:$PATH"

# unset manpath so we can inherit from /etc/manpath via the `manpath` command
export MANPATH="${MANPATH-$(manpath)}:$NPM_PACKAGES/share/man"

# commandline
export HISTCONTROL=ignoredups

# this loads nvm
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# set SSH_AUTH_SOCK for 1password
export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock

# load node version in a project with .nvmrc file
autoload -U add-zsh-hook
load-nvmrc() {
  local node_version="$(nvm version)"
  local nvmrc_path="$(nvm_find_nvmrc)"

  if [ -n "$nvmrc_path" ]; then
    local nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")

    if [ "$nvmrc_node_version" = "N/A" ]; then
      nvm install
    elif [ "$nvmrc_node_version" != "$node_version" ]; then
      nvm use
    fi
  elif [ "$node_version" != "$(nvm version default)" ]; then
    echo "Reverting to nvm default version"
    nvm use default
  fi
}
add-zsh-hook chpwd load-nvmrc
load-nvmrc

# misc.
export GPG_TTY=$(tty)

# functions
commit () {
    commitMessage="$1"

    if [ "$commitMessage" = "" ]
    then
        commitMessage="WIP"
    fi

    eval "git pull origin ${gitCurrentBranch}"

    git add .
    eval "git commit -a -m '${commitMessage}'"
}

commit:push () {
    commitMessage="$1"
    gitCurrentBranch=$(git branch --show-current)

    if [ "$commitMessage" = "" ]
    then
        commitMessage="WIP"
    fi

    eval "git pull origin ${gitCurrentBranch}"

    git add .
    eval "git commit -a -m '${commitMessage}'"

    eval "git push origin ${gitCurrentBranch}"
}

commit:today () {
    eval "git pull origin ${gitCurrentBranch}"
    git add .
    eval "git commit -m '$(date +%Y-%m-%d)'"
    eval "git push origin ${gitCurrentBranch}"
}
