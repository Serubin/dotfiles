[[ $- != *i* ]] && return

setopt extendedglob

# Call all files in .zsh, except .zwc (compiled zsh files)
for rc in $HOME/.zsh/*~*.zwc; do
    source $rc
done

if [ -r $HOME/.zsh/dircolors/dircolors.256dark ]; then
    local dircolors_dir=$HOME/.zsh/dircolors/dircolors.256dark
    if [ "$DISTRO" = "darwin" ]; then
      eval $(gdircolors $dircolors_dir);
    else
      eval $(dircolors $dircolors_dir);
    fi
fi

if [ -r $HOME/.custom ]; then
    source $HOME/.custom;
fi

unsetopt extendedglob
