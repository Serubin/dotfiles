[[ $- != *i* ]] && return

for rc in ~/.zsh/includes/*; do
    source $rc
done

for rc in ~/.zsh/*; do
    source $rc
done

if [ -r ~/.custom ]; then
    source ~/.custom;
fi