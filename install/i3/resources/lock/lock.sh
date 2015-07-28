#!/bin/bash

scrot -e 'convert -resize 20% -fill "#282828" -colorize 50% -blur 0x1 -resize 500% $f ~/.lock/lockbg.png'
convert -gravity center -composite $HOME/.lock/lockbg.png $HOME/.lock/lock.png $HOME/.lock/lockfinal.png
i3lock -u -i $HOME/.lock/lockfinal.png
rm  $HOME/.lock/lockfinal.png $HOME/.lock/lockbg.png
