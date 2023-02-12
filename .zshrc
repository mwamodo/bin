# preferred editor for local and remote sessions
 if [[ -n $SSH_CONNECTION ]]; then
   export EDITOR='vim'
 else
   export EDITOR='mvim'
 fi

source ${HOME}/bin/init/aliases.sh
source ${HOME}/bin/init/exports.sh

eval "$(starship init zsh)"