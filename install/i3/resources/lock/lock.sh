#!/bin/bash
# Locking script
# generously from: https://github.com/jearbear/dotfiles

scrot -e 'convert -resize 20% -fill "#282828" -colorize 50% -blur 0x1 -resize 500% $f ~/.i3/lock/lockbg.png' $HOME/.i3/lock/tmp.png
convert -gravity southwest -geometry +50+50 -composite $HOME/.i3/lock/lockbg.png $HOME/.i3/lock/lock-txt.png $HOME/.i3/lock/lockfinal.png
i3lock -u -i $HOME/.i3/lock/lockfinal.png
rm  $HOME/.i3/lock/lockfinal.png $HOME/.i3/lock/lockbg.png $HOME/.i3/lock/tmp.png
