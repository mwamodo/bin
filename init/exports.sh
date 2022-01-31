# npm global path to prevent install npm with sudo
NPM_PACKAGES="${HOME}/.npm-packages"

# Insert globally installed npm packages to path and local bin
export PATH="$PATH:$NPM_PACKAGES/bin"

# Unset manpath so we can inherit from /etc/manpath via the `manpath` command
export MANPATH="${MANPATH-$(manpath)}:$NPM_PACKAGES/share/man"

export DATE=`date +%d-%m-%Y`

# insert bin/scripts directory to path
export PATH=$PATH:$HOME/bin/scripts

# PHP
export PATH="$PATH:$HOME/.composer/vendor/bin"
export XDEBUG_MODE=coverage

# Flutter
export PATH="$PATH:$HOME/Code/Externals/flutter/bin"

# Git and GitHub
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
