# list directories
alias l="ls"
alias ll="ls -l"
alias la="ls -a"
alias lla="ls -al"

# git aliases
alias g="git"
alias gc="g commit"
alias gs="g status -s"
alias ga="git add"
alias gst="gs"
alias gcm="gc -m"
alias gaa="ga ."
alias gpo="g push origin"
alias gpom="g push origin main"
alias glog="g log --graph --pretty=format:'''%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'"

# program & software aliases
alias vim="mvim"
alias vi="vim"
alias v="vi"
alias h="history | awk '{print $2}' | sort | uniq -c | sort -rn | head -5"

# PHP | laravel
alias sail='[ -f sail ] && sh sail || sh ./vendor/bin/sail'

alias artisan="sail artisan"
alias art="artisan"
alias a="artisan"

alias horizon="a horizon"
alias h="a horizon"

alias acc="a cache:clear"
alias log:clear="truncate -s 0 storage/logs/laravel.log" # requires truncate ```brew install truncate```

alias artisan:test="a test --parallel"
alias a:t="artisan:test"

alias artisan:enlightn="a enlightn --report"
alias a:e="artisan:enlightn"

alias npm:dev="sail npm run dev"
alias npm:build="sail npm run build"

alias mf="a migrate"
alias ms="a migrate:status"
alias mff="a migrate:fresh && a cache:clear"
alias mfs="a migrate:fresh --seed && a cache:clear"
alias mfsr="a migrate:fresh --seed && a cache:clear && redis-cli flushdb"

alias tinker="a tinker"

alias db:wipe="a db:wipe"
alias db:seed="a db:seed"

# system
alias reload="source ~/.zshrc"