# Load environment variables and shell integrations that might produce output
# These need to be BEFORE the instant prompt to avoid warnings

# Load environment variables from .env file
if [ -f "$HOME/bin/.env" ]; then
    export $(cat "$HOME/bin/.env" | grep -v '^#' | xargs) 2>/dev/null
fi

# Load envman (only once, removing duplicate)
if [ -s "$HOME/.config/envman/load.sh" ]; then
    source "$HOME/.config/envman/load.sh"
fi

# Shell integrations that might produce output
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null
eval "$(twilio autocomplete:script zsh)" 2>/dev/null
eval "$(zoxide init --cmd cd zsh)" 2>/dev/null

[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)" 2>/dev/null

typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Download Zinit, if it's not there yet (moved to avoid console output during init)
if [ ! -d "$ZINIT_HOME" ]; then
    mkdir -p "$(dirname $ZINIT_HOME)" 2>/dev/null
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME" 2>/dev/null
fi

# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"

# Add in zsh plugins (removed duplicate Powerlevel10k since we're using instant prompt)
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# Add in snippets
zinit snippet OMZL::git.zsh
zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::archlinux
zinit snippet OMZP::aws
zinit snippet OMZP::kubectl
zinit snippet OMZP::kubectx
zinit snippet OMZP::command-not-found

# Load completions
autoload -Uz compinit && compinit

zinit cdreplay -q

# Source local p10k configuration if it exists
[[ ! -f "${HOME}/bin/.powerlevel10k/powerlevel10k.zsh-theme" ]] || source "${HOME}/bin/.powerlevel10k/powerlevel10k.zsh-theme"
[[ ! -f "${HOME}/bin/.powerlevel10k/config/p10k-robbyrussell.zsh" ]] || source "${HOME}/bin/.powerlevel10k/config/p10k-robbyrussell.zsh"

# Keybindings
bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward
bindkey '^[w' kill-region

# History
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=10000
HISTDUP=erase

setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
    export EDITOR='vim'
else
    export EDITOR='nvim'
fi

[[ -f ${HOME}/bin/zsh/aliases.sh ]] && source ${HOME}/bin/zsh/aliases.sh
[[ -f ${HOME}/bin/zsh/exports.sh ]] && source ${HOME}/bin/zsh/exports.sh

# Herd injected PHP binary.
export PATH="$HOME/Library/Application Support/Herd/bin/":$PATH
export PHP_INI_SCAN_DIR="$HOME/Library/Application Support/Herd/config/php/":$PHP_INI_SCAN_DIR

# Herd injected PHP configuration.
export HERD_PHP_74_INI_SCAN_DIR="$HOME/Library/Application Support/Herd/config/php/74/"
export HERD_PHP_80_INI_SCAN_DIR="$HOME/Library/Application Support/Herd/config/php/80/"
export HERD_PHP_81_INI_SCAN_DIR="$HOME/Library/Application Support/Herd/config/php/81/"
export HERD_PHP_82_INI_SCAN_DIR="$HOME/Library/Application Support/Herd/config/php/82/"
export HERD_PHP_83_INI_SCAN_DIR="$HOME/Library/Application Support/Herd/config/php/83/"
export HERD_PHP_84_INI_SCAN_DIR="$HOME/Library/Application Support/Herd/config/php/84/"
export HERD_PHP_85_INI_SCAN_DIR="$HOME/Library/Application Support/Herd/config/php/85/"

# Added by LM Studio CLI (lms)
export PATH="$PATH:$HOME/.cache/lm-studio/bin"
# End of LM Studio CLI section

export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"





bindkey "^[[A" history-beginning-search-backward
bindkey "^[[B" history-beginning-search-forward

export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"

# Added by Antigravity
export PATH="/Users/mwamodo/.antigravity/antigravity/bin:$PATH"


# opencode
export PATH=/Users/mwamodo/.opencode/bin:$PATH


# Herd injected PHP 8.3 configuration.
export HERD_PHP_83_INI_SCAN_DIR="/Users/mwamodo/Library/Application Support/Herd/config/php/83/"


# Herd injected PHP 8.4 configuration.
export HERD_PHP_84_INI_SCAN_DIR="/Users/mwamodo/Library/Application Support/Herd/config/php/84/"
