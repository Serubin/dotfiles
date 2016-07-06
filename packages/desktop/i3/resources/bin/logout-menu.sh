#!/bin/bash

#generously from: https://gitlab.com/dennis.hamester/dotfiles/tree/1063e46e7e6641c2b2949c07947dc37466663b7e

background="#2b303b"
foreground="#65737e"
outline="#c0c5ce"

CMD=`echo -e "Logout\nLock\nPoweroff\nReboot\nSuspend" | rofi -dmenu -p "Logout Menu:" -lines 5 -eh 2 -opacity "70" -bw 1 -bc "#22262f" -bg "$background" -fg "$foreground" -hlbg "$outline" -hlfg "$background" -width 100 -padding 400`
if [ ! $CMD ]; then
    exit
fi

case $CMD in
    Logout)
        i3-msg exit ;;
    Lock)
        ~/.i3/lock/lock.sh ;;
    Poweroff)
        systemctl poweroff ;;
    Reboot)
        systemctl reboot ;;
    Suspend)
        systemctl suspend ;;
esac
