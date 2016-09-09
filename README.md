# Serubin's DotFiles

The purpose of this dotfiles configuration is to create a lightweight and easy to understand configuration.

## Installation

Installing is fairly straight forward, just clone the repo and place it anywhere and use the install script provided.
```bash
git clone --recursive https://github.com/Serubin/dotfiles.git && cd dotfiles && ./install.sh
```
To update run ``` ./install.sh -u```
To install without interactivity run ``` ./install.sh -i <package1,package2> ```
To list installed packages run ``` ./install.sh -l```
In order to change the location of the installation you will have to re-run the install script with ``` ./install.sh ```


## OS Support
* OS X (with brew)
* Debian
* Ubuntu
* Arch
* Fedora

The install script takes care of all the pre-requists excluding git, bash, lsb-release, and sudo. However this only works with OSX, Arch,  Debian, and Ubuntu (for the moment). 

For all *linux* distributions
*The script will not be able to detect your os without ```lsb-release```, make sure to install it*

In OS X the script will install brew and all needed components. 

## What does this set up do?

This setup creates a clean bash envirnment with several other applications. Below is each application created and the features added. Of course I encourage you to look through the files to get a better picture of what this will set up for you.

Settings in `~/.dotfiles.info`

#### Bash/ZSH
*   Aliases (listed in bash/.alias)
*   Custom PS1 prompt with git integration
*   Functions to make life easy (listed in bash/.function) 

#### ZSH
* Custom Themeing
 * Set in dotfiles.info
* Autocompletion while typing
* dynamic syntax highlighting

#### git
* Global ignore for mac os x
* Git Aliases (listed in packages/cli/git/config/.gitconfig)

#### Vim
* "Smart" features
* Shortcuts
* Line numbers
* Intelligent ignores
* lightline
* YouCompleteMe
* NerdTree
* Presistent undo
* Various completion packages

#### Sublime (x server/Desktop Environment) (not included on Arch, mostly replaced by Vim at this point)
* Custom Theme - Monkia
* Packages
 * All Autocomplete
 * Apply Syntax
 * BracketHighlighter
 * CodeFormatter
 * SideBarEnhancements
 * Various Completion packages

