# Serubin's DotFiles

Your run of the mill dotfiles, using stow and a simple install script.

## Installation

Installing is easy:
```bash
git https://github.com/Serubin/dotfiles.git .dotfiles && cd .dotfiles && ./install.sh
```
To update run ``` ./install.sh``` again. You can add `-v` for verbose output. Use `--uninstall` to remove stowed directories. This will not remove installed packages.


## OS Support
* OS X (with brew)
* Debian
* Ubuntu

The install script takes care installing packages etc. This means sudo is used in these scripts and is required.

## Notes
Use the `~/.custom` file to add custom `.zshrc` entries

## Design overview

```
/
+-- README.md
+-- LICENSE
+-- install.sh              <-- Install script
+-- setup/                  <-- Common setup
|    +-- debian             <-- Install scripts, per distribution
|    +-- darwin 
+-- git/                    <-- Package directory
     +-- setup/             <-- Setup files
     +-- config_files       <-- All files in a package directory will be stowed
     +-- more_config_files
+-- other_packages/
     +-- setup/
     +-- ...
+-- ...
```

