[[ $- != *i* ]] && return

for rc in $HOME/.zsh/includes/*; do
    source $rc
done

for rc in $HOME/.zsh/*; do
    source $rc
done

if [ -r $HOME/.custom ]; then
    source $HOME/.custom;
fi
