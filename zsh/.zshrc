[[ $- != *i* ]] && return

for rc in $HOME/.zsh/includes/*; do
    source $rc
done

for rc in $HOME/.zsh/*; do
    source $rc
done

if [ -r $HOME/.zsh/dircolors/dircolors.256dark ]; then
    eval $(dircolors $HOME/.zsh/dircolors/dircolors.256dark);
fi

if [ -r $HOME/.custom ]; then
    source $HOME/.custom;
fi
