#!/bin/bash

################################################
# Module package installer
# installPackage <type> <name>
#
###############################################
installPackage() {

	TYPE=${1}
	NAME=${2}

	PACKAGE_INSTALL="${DOTFILES_DIR}/packages/${TYPE}/${NAME}"

	echo ""
	echo "------------ ${NAME} ------------"


	# Every package must have a name.info file in it's directory. It must contain:
	# * supported oses (exported to package_support [comma delemiter])
	# * Breif description of the package (echoed)
	# * Additional packages installed (not including dependancies, echoed)

	source "${PACKAGE_INSTALL}/${NAME}.info"

	package_supported=`echo $package_support | grep -o $DISTRO`
	
	if [ "$package_supported" != "$DISTRO" ]; then 
		echo "${NAME} cannot be installed on ${DISTRO}."
		return
	fi

	package_install=`getInputBoolean "Do you want to install ${NAME}"?`
	
	#If user doesn't wish ti install - skip
	if [ "$package_install" == "0" ]; then
		return
	fi

	echo "Attempting to install ${NAME}..."
	# Os specific
	if [ "$DISTRO" == "Debian" ] || [ "$DISTRO" == "Ubuntu" ]; then
		source "${PACKAGE_INSTALL}/${NAME}.debian"
	elif [ "$DISTRO" == "Darwin" ]; then
		source "${PACKAGE_INSTALL}/${NAME}.osx"
	elif [ "$DISTRO" == "Arch" ]; then
		source "${PACKAGE_INSTALL}/${NAME}.arch"
	else
		# FYI: This shouldn't ever happen - make an issue if it does?
		echo "ERROR: This os doesn't support ${NAME} installations."a
		return
	fi
	
	# Common install
	if [ -r "${PACKAGE_INSTALL}/${NAME}.sh" ]; then
		source ${PACKAGE_INSTALL}/${NAME}.sh
	fi

	unset PACKAGE_INSTALL package_support package_supported
}
