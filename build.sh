#!/bin/bash
#
# Copyright: 2017-2018 sel-project
# License: MIT
#

case $(uname -m) in
    x86_64|amd64) ARCH=x86_64;;
    i*86) ARCH=x86;;
    *)
        fatal "Unsupported Arch $(uname -m)"
        ;;
esac

COMPILER=dmd
BUILD=debug
CONFIG=default
PORTABLE=
PLUGINS=

while [[ $# -gt 0 ]]; do
	case "$1" in
	
		-h | --help)
			#TODO
			;;
			
		--dmd)
			COMPILER=dmd
			;;
			
		--ldc | --ldc2)
			COMPILER=ldc2
			;;

		debug | release)
			BUILD=$1
			;;
		
		default | classic | node | hub)
			CONFIG=$1
			;;
			
		-p | --portable)
			PORTABLE=--portable
			;;
			
		-np | --no-plugins)
			PLUGINS=--no-plugins
			;;
			
	esac
	shift
done

cd builder/init
dub run --compiler=$COMPILER --build=$BUILD --arch=$ARCH -- $CONFIG $PORTABLE $PLUGINS
cd ..
dub build --compiler=$COMPILER --build=$BUILD --arch=$ARCH
