# npm global path to prevent install npm with sudo
NPM_PACKAGES="${HOME}/.npm-packages"

# insert globally installed npm packages to path homebrew to PATH
export PATH="$HOME/.local/bin:$NPM_PACKAGES/bin:/usr/local/mysql/bin:$PATH"

# redis path for DBngin
export PATH="/Users/Shared/DBngin/redis/7.0.0/bin:$PATH"

# mysql path for DBngin
export PATH="/Users/Shared/DBngin/mysql/8.0.33/bin:$PATH"

export PATH="$HOME/bin/scripts:$PATH"

export PATH="$HOME/.composer/vendor/bin:$PATH"

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
source <(fzf --zsh)

# functions
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

schedule:run () {
    while true; do
        echo "Running Laravel schedule at $(date)"
        php artisan schedule:run >> storage/logs/scheduler.log 2>&1
        sleep 60
    done
}

artisan:test-with-coverage() {
    local current_dir_name=$(basename "$PWD")
    a test --coverage-html "../coverage/${current_dir_name}/"
    open "http://coverage.test/${current_dir_name}/"
}

lab() {
    if [ $# -eq 0 ]; then
        ssh mwamodo@${HOME_IP}
    else
        ssh -tt mwamodo@${HOME_IP} "bash -ic '$*'"
    fi
}

pihole() {
    if [ $# -eq 0 ]; then
        ssh mwamodo@${PIHOLE_IP}
    else
        ssh -tt mwamodo@${PIHOLE_IP} "bash -ic '$*'"
    fi
}

# sets the tab name for warp to the current directory name
set_name () {
    echo -ne "\033]0;${PWD##*/}\007"
}

if [ -n "$ZSH_VERSION" ]; then
    precmd_functions+=(set_name)
elif [ -n "$BASH_VERSION" ]; then
    PROMPT_COMMAND='set_name'
fi
