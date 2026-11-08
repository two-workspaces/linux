# ~/.bashrc — persisted on the Railway volume. Edit freely.
[ -z "$PS1" ] && return
export PATH="$HOME/.local/bin:$PATH"
export EDITOR=vim
alias ll='ls -alF'
PS1='\[\e[1;32m\]\u@linux\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '
[ -f ~/.motd ] && cat ~/.motd
