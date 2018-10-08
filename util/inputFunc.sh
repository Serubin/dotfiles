#!/bin/bash

# Takes in input (yes or no) defaults to yes
getInputBoolean() {
        read -p "${1} (Y/n) " in;
        if [ "$in" == "y" ]; then
                echo 1;
        elif [ "$in" == "n" ]; then
                echo 0;
        else
                echo 1;
        fi
}

