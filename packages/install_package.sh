#!/bin/bash

################################################
# Module package installer
# installPackage <type> <name>
#
###############################################

unset PACKAGE_INSTALL package_support package_supported packages_length packages

declare -a packages # Package 
packages_length=0 # package length

registerPackage() {
    
    NAME=${2}
    TYPE=${1}

    echo "-------"
    # Echos descriptions
    PACKAGE_INSTALL="${DOTFILES_DIR}/packages/${TYPE}/${NAME}"
    source "${PACKAGE_INSTALL}/${NAME}.info"
    
    unset package_support

    install_confirm=`getInputBoolean "Do you want to install ${NAME}"?` #TODO move to ask function

    # Saves in formate <type>_<name>_<confirm>
    package_install="${TYPE}_${NAME}_${install_confirm}"
    
    packages+=($package_install)
    let packages_length+=1
    if [[ "$install_confirm" == "1" ]]; then
        PRE_INSTALL_OPTIONS
        export installed="${installed} ${TYPE}_${NAME}_1"
        let installed_len+=1
    fi
    
    unset package_install PRE_INSTALL_OPTIONS

}

installPackage() {
    
    # Handles arguments for predefined package lsits
    if [[ $1 != "" ]]; then
        packages_length=$1
    fi

    if [[ $2 != "" ]]; then
        end=$((2 + $packages_length))
        packages=(${@:2:$end})
    fi

    # install loop
    for i in $(seq 0 $packages_length); do
	    if [[ $i == $packages_length ]]; then
            continue
        fi

        # Reads in package from array
        raw_name="${packages[$i]}"
        
        OLDIFS="$IFS"
        
        # Split
        IFS=_ arr=($raw_name) 
        install_confirm=${arr[2]}
        NAME=${arr[1]}
        TYPE=${arr[0]}
               
        IFS="$OLDIFS"
              
        # Install location
        PACKAGE_INSTALL="${DOTFILES_DIR}/packages/${TYPE}/${NAME}"

        
        #If user doesn't wish to install - skip
        if [[ "$install_confirm" == "0" ]]; then
            continue
        fi
        

        sudo echo "" # Maintain sudo access
        echo "------------ ${NAME} ------------"

        # Every package must have a name.info file in it's directory. It must contain:
        # * supported oses (exported to package_support [comma delemiter])
        # * Brief description of the package (echoed)
        # * Additional packages installed (not including dependancies, echoed)

        source "${PACKAGE_INSTALL}/${NAME}.info" &> /dev/null

        package_supported=`echo $package_support | grep -o $DISTRO`
        
        if [ "$package_supported" != "$DISTRO" ]; then 
            echo "${NAME} cannot be installed on ${DISTRO}."
            continue
        fi


        echo "Attempting to install ${NAME}..."
        # Os specific
        if [[ "$DISTRO" == "Debian" ]] || [[ "$DISTRO" == "Ubuntu" ]]; then
            source "${PACKAGE_INSTALL}/${NAME}.debian"
        elif [[ "$DISTRO" == "Darwin" ]]; then
            source "${PACKAGE_INSTALL}/${NAME}.osx"
        elif [[ "$DISTRO" == "Arch" ]]; then
            source "${PACKAGE_INSTALL}/${NAME}.arch"
        elif [[ "$DISTRO" == "Fedora" ]]; then
            source "${PACKAGE_INSTALL}/${NAME}.fedora"
        else
            # FYI: This shouldn't ever happen - make an issue if it does?
            echo "ERROR: This os doesn't support ${NAME} installations."a
            continue
        fi
        
        # Common install
        if [ -r "${PACKAGE_INSTALL}/${NAME}.sh" ]; then
            source ${PACKAGE_INSTALL}/${NAME}.sh
        fi
    done

	unset PACKAGE_INSTALL package_support package_supported packages_length packages
}
