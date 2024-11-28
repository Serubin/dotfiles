# Serubin's DotFiles
[![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2FSerubin%2Fdotfiles.svg?type=shield)](https://app.fossa.io/projects/git%2Bgithub.com%2FSerubin%2Fdotfiles?ref=badge_shield)


The purpose of this dotfiles configuration is to create a lightweight and easy to understand configuration. This was largely created as a multi-platform alternative to OhMyZsh. Personally - I found OhMyZsh to be very overwhelming and more focused on using other's configuration than customizing things to be my own. Thus, I created a framework that allows for two things: Easy management of dotfiles and a simple configuration that anyone could fork and modify to their liking.

Of course, you'll find within this repository my personal configuration: Although it may not be to everyone's liking I think it's a very solid foundation to creating a comfortable and mostly bug free development environment. A lot of the issues people run into when setting up their own dev-envs have already been solved here. An excellent example of this is getting colored nvim to work in tmux. 

Whether you use this as a resource for creating your own dotfiles or you use this configuration and make it your own, I hope that you find it helpful and will consider contributing.

## Installation

Installing is fairly straight forward, just clone the repo and place it anywhere and use the install script provided.
```bash
git clone --recursive https://github.com/Serubin/dotfiles.git && cd dotfiles && ./install.sh
```
To update run ``` ./install.sh -u```
To install without interactivity run ``` ./install.sh -i <package1,package2> ``` (Still in progress)
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

## General overview

Settings in `~/.dotfiles.info`

#### Bash/ZSH
* Custom Themeing
 * Set in dotfiles.info
*   Aliases (listed in packages/shell/common/run/.alias)
*   Functions to make life easy (listed in packages/shell/common/run/.function) 

#### ZSH
* Custom Themeing
 * Set in dotfiles.info
* Autocompletion while typing
* dynamic syntax highlighting

#### git
* Up to date! (Mostly looking at debian/ubuntu)
* Global ignore
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

#### Sublime (x server/Desktop Environment) (not included on Arch, mostly replaced by nVim at this point)
* Custom Theme - Monkia
* Packages
 * All Autocomplete
 * Apply Syntax
 * BracketHighlighter
 * CodeFormatter
 * SideBarEnhancements
 * Various Completion packages

## Design overview

```
/
+-- README.md
+-- LICENSE
+-- install.sh          <-- Main script
+-- common/             <-- Common files - shared and third party
|    +-- .custom        <-- Custom input file (copied to ~)
|    +-- <third-party-repos>/ 
+-- packages/
     +-- shell/
     +-- cli/
     +-- desktop/
+-- util/
```



## License
[![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2FSerubin%2Fdotfiles.svg?type=large)](https://app.fossa.io/projects/git%2Bgithub.com%2FSerubin%2Fdotfiles?ref=badge_large)