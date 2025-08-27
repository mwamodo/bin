# programs & software aliases
alias vim="nvim"
alias vi="nvim"
alias v="vi"
alias h="history | awk '{print $2}' | sort | uniq -c | sort -rn | head -5"

# laravel & dev work
alias php="herd php"
alias composer="herd composer"

alias artisan="php artisan"
alias art="artisan"
alias a="artisan"

alias horizon="a horizon"
alias h="a horizon"

alias acc="a cache:clear"
alias aop="a optimize:clear"

alias log:clear="truncate -s 0 storage/logs/laravel*.log"

alias a:tt="artisan:test-with-coverage"
alias a:tp="a:t --parallel"
alias artisan:test="a test"
alias a:t="artisan:test"
alias a:ts="a test --stop-on-failure"

alias c="commit"
alias c:p="commit:push"

alias artisan:enlightn="a enlightn --report"
alias a:e="artisan:enlightn"

alias npm:dev="npm run dev"
alias npm:build="npm run build"
alias n:b="npm:build"
alias n:d="npm:dev"
alias nd="n:d"
alias nb="n:b"

alias queue:work="php artisan queue:work"
alias q:w="queue:work"
alias queue:listen="php artisan queue:listen"
alias q:l="queue:listen"

alias migrate="a migrate"
alias mf="migrate"
alias ms="a migrate:status"
alias mff="a migrate:fresh && a optimize:clear"
alias mfs="a migrate:fresh --seed && a optimize:clear"
alias mfsr="a migrate:fresh --seed && a optimize:clear && redis-cli flushdb"

alias tinker="a tinker"

alias ide:helper="a ide-helper:generate && a ide-helper:meta && a ide-helper:models --nowrite"
alias ide:helper:generate="a ide-helper:generate"
alias ide:helper:meta="a ide-helper:meta"
alias ide:helper:models="a ide-helper:models --nowrite"

alias db:wipe="a db:wipe"
alias db:seed="a db:seed"

alias s:r="schedule:run"

alias share="herd share"
alias h:s="share"

alias duster="./vendor/bin/duster"
alias duster:lint="duster lint"
alias lint="duster:lint"
alias duster:fix="duster fix"
alias fix="duster:fix"

alias flux:icon="artisan flux:icon"

# system
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
alias gst="git status"
alias ga="git add"
alias gaa="git add ."
alias gc="git commit"
alias gcm="git commit -m"
alias gp="git push"
alias gpl="git pull"
alias gb="git branch"
alias gco="git checkout"
alias gd="git diff"
alias gl="git log"
alias gt="git tag -s"
alias gll="git log --oneline --decorate --all --graph"

# fancy git
alias push="gp"
alias push:main="gp origin main"

# mysql herd
alias mysql="mysql -u root -h 127.0.0.1 -P 3306 -p"

# youtube-dl
alias youtube-dl-mp4="youtube-dl -f 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best'"

# switch from top to bpytop
alias top="bpytop"

# switch from neofetch to fastfetch
alias neofetch="fastfetch"

# switch from cat to bat
alias cat="bat"

# switch from tmux to tmuxinator
alias tmux="tmux -u"
