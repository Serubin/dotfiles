[[ $- != *i* ]] && return

# for rc in $HOME/.zsh/includes/*; do
#     source $rc
# done

for rc in $HOME/.zsh/*; do
    source $rc
done

if [ -r $ADOTDIR/seebi/dircolors-solarized/dircolors.256dark ]; then
    eval $(dircolors ADOTDIR/seebi/dircolors-solarized/dircolors.256dark);
fi

if [ -r $HOME/.custom ]; then
    source $HOME/.custom;
fi
