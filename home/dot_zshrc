[[ $- != *i* ]] && return

setopt extendedglob

# Call all files in .zsh, except .zwc (compiled zsh files)
for rc in $HOME/.zsh/*~*.zwc; do
    source $rc
done

if [ -r $HOME/.custom ]; then
    source $HOME/.custom;
fi

unsetopt extendedglob

