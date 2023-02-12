# npm global path to prevent install npm with sudo
NPM_PACKAGES="${HOME}/.npm-packages"

# insert globally installed npm packages to path homebrew to PATH
export PATH="$NPM_PACKAGES/bin:/opt/homebrew/bin:$HOME/bin/.scripts:$HOME/.composer/vendor/bin:/opt/homebrew/sbin:$PATH"

# unset manpath so we can inherit from /etc/manpath via the `manpath` command
export MANPATH="${MANPATH-$(manpath)}:$NPM_PACKAGES/share/man"

# commandline
export HISTCONTROL=ignoredups

# this loads nvm
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

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

# git and github functions
commit () {
    commitMessage="$1"

    if [ "$commitMessage" = "" ]
    then
        commitMessage="WIP"
    fi

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

    git add .
    eval "git commit -a -m '${commitMessage}'"
    eval "git push origin ${gitCurrentBranch}"
}

# misc.
export GPG_TTY=$(tty)