# programs & software aliases
alias vim="nvim"
alias vi="nvim"
alias v="vi"
alias h="history | awk '{print $2}' | sort | uniq -c | sort -rn | head -5"

# laravel & dev work
alias artisan="php artisan"
alias art="artisan"
alias a="artisan"

alias horizon="a horizon"
alias h="a horizon"

alias acc="a cache:clear"
alias log:clear="truncate -s 0 storage/logs/laravel.log"

alias artisan:test="a test --parallel"
alias a:t="artisan:test"

alias artisan:enlightn="a enlightn --report"
alias a:e="artisan:enlightn"

alias npm:dev="npm run dev"
alias npm:build="npm run build"
alias n:d="npm:dev"
alias nd="n:d"
alias n:b="npm:build"
alias nb="n:b"

alias queue:work="php artisan queue:work"
alias q:w="queue:work"
alias queue:listen="php artisan queue:listen"
alias q:l="queue:listen"

alias migrate="a migrate"
alias mf="migrate"
alias ms="a migrate:status"
alias mff="a migrate:fresh && a cache:clear"
alias mfs="a migrate:fresh --seed && a cache:clear"
alias mfsr="a migrate:fresh --seed && a cache:clear && redis-cli flushdb"

alias tinker="a tinker"

alias db:wipe="a db:wipe"
alias db:seed="a db:seed"

# system
alias reload="source ~/.zshrc"

# python
alias python="python3"
alias pip="pip3"

# editors
alias code="zed"

# ls & lsd
alias ls="lsd"
alias ll="lsd -Fl"
