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

export PATH="$HOME/Applications/WezTerm.app/Contents/MacOS:$PATH"

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
    git commit -a -m "${commitMessage}"
}

commit:push () {
    commitMessage="$1"
    gitCurrentBranch=$(git branch --show-current)

    if [ "$commitMessage" = "" ]
    then
        commitMessage="WIP"
    fi

    git add .
    git commit -a -m "${commitMessage}"
    git push origin "${gitCurrentBranch}"
}

switch:master () {
    git checkout master
    git pull origin master
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

bot() {
    if [ $# -eq 0 ]; then
        ssh openclaw@${OPENCLAW_IP}
    else
        ssh -tt openclaw@${OPENCLAW_IP} "bash -ic '$*'"
    fi
}

lab() {
    if [ $# -eq 0 ]; then
        ssh rick@${HOME_IP}
    else
        ssh -tt rick@${HOME_IP} "bash -ic '$*'"
    fi
}

lab:suspend() {
    ssh -t clawdbot@${HOME_IP} 'sudo systemctl suspend'
}

lab:sleep() {
    local day=$(date +%u)
    local waketime="16:30"

    [[ "$day" -eq 6 || "$day" -eq 7 ]] && waketime="10:00"

    local current_time=$(date +%H%M)
    local wake_time_cmp="${waketime//:/}"
    local target_day="today"

    if [[ "$current_time" > "$wake_time_cmp" ]]; then
        target_day="tomorrow"
        # calculate wake time for tomorrow
        # if today is Friday (5) or Saturday (6), tomorrow is weekend (Sat/Sun)
        if [[ "$day" -eq 5 || "$day" -eq 6 ]]; then
            waketime="10:00"
        else
            waketime="16:30"
        fi
    fi

    echo "Manually suspending. Server will wake at $waketime $target_day."
    ssh -t clawdbot@${HOME_IP} "sudo rtcwake -m mem -t \$(date -d '$target_day $waketime' +%s)"
}

lab:wake() {
    wakeonlan ${HOME_MAC}
}

if [ -n "$ZSH_VERSION" ]; then
    precmd_functions+=(set_name)
elif [ -n "$BASH_VERSION" ]; then
    PROMPT_COMMAND='set_name'
fi
