# preferred editor for local and remote sessions
 if [[ -n $SSH_CONNECTION ]]; then
   export EDITOR='vim'
 else
   export EDITOR='mvim'
 fi

[[ -f ${HOME}/bin/.zsh/aliases.sh ]] && source ${HOME}/bin/.zsh/aliases.sh
[[ -f ${HOME}/bin/.zsh/exports.sh ]] && source ${HOME}/bin/.zsh/exports.sh
[[ -f ${HOME}/bin/.zsh/starship.sh ]] && source ${HOME}/bin/.zsh/starship.sh

eval "$(starship init zsh)"
eval "$(twilio autocomplete:script zsh)"