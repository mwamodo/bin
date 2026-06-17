# shellcheck shell=bash
# programs & software aliases
alias vim="nvim"
alias vi="nvim"
alias v="vi"

alias claude="claude --dangerously-skip-permissions"
alias cc="claude"
alias ccr="claude --resume"

# laravel & dev work
alias code="agy-ide"

alias composer="herd composer"

alias artisan="php artisan"
alias art="artisan"
alias a="artisan"

alias horizon="a horizon"
alias a:h="horizon"

alias a:cc="a cache:clear"
alias a:op="a optimize:clear"

alias log:clear="truncate -s 0 storage/logs/laravel*.log"

alias a:t="a test"
alias a:tp="a test --parallel"
alias a:tc="herd coverage ./vendor/bin/pest --coverage --coverage-html=public/test-coverage"
alias a:ts="a test --stop-on-failure"
alias commit:ai="pi --no-session --model opencode-go/deepseek-v4-flash -p 'commit all changes'"
alias wip="commit:push"

alias n="npm"
alias nr="n run"

alias npm:build="nr build"
alias npm:dev="nr dev"

alias n:b="npm:build"
alias n:d="npm:dev"

alias queue:work="a queue:work"
alias queue:listen="a queue:listen"

alias q:w="queue:work"
alias q:l="queue:listen"

alias migrate="a migrate"
alias ms="a migrate:status"
alias mff="a migrate:fresh && a optimize:clear"

alias mfs="a migrate:fresh --seed && a optimize:clear"
alias mfsr="a migrate:fresh --seed && a optimize:clear && redis-cli flushdb"

alias tinker="a tinker"

alias db:wipe="a db:wipe"
alias db:seed="a db:seed"

alias s:r="schedule:run"

alias expose="expose --server-host=repounlock.com"
alias share="herd share --server-host=repounlock.com"
alias h:s="share"

alias flux:icon="artisan flux:icon"

# system
alias history="fc -l 1"
alias reload="source ~/.zshrc"

# python
alias python="python3"
alias pip="pip3"

# ls & lsd
alias l="lsd"
alias ls="lsd"
alias la="l -A"
alias ll="l -Fl"
alias lla="l -FlA"

# git
alias g="git"

alias ga="g add"
alias gaa="g add ."

alias gst="g status"
alias gc="g commit -S"
alias gcm="g commit -S -m"

alias gp="g push"
alias gpl="g pull"

alias push="gp"
alias push:main="gp origin main"

alias gb="g branch"
alias gbd="g branch -d"
alias gco="g checkout"

alias gd="g diff"

alias gl="g log"
alias gll="g log --oneline --decorate --all --graph"

alias gt="g tag -S"

# mysql herd
alias mysql="mysql -u root -h 127.0.0.1 -P 3306 -p"

# terminal tools
alias cat="bat"
alias top="bpytop"
alias htop="bpytop"
alias tmux="tmux -u"
alias neofetch="fastfetch"

# youtube-dl
alias youtube-dl-mp4="youtube-dl -f 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best'"

# tailscale
alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
