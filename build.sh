#!/bin/bash
#
# Copyright: (c) 2018 SEL
# License: LGPL-3.0
#

case $(uname -m) in
    x86_64|amd64) ARCH=x86_64; MODEL=64;;
    i*86) ARCH=x86; MODEL=32;;
    *)
        fatal "Unsupported Arch $(uname -m)"
        ;;
esac

COMPILER=dmd
BUILD=debug
CONFIG=default
PORTABLE=

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
			
	esac
	shift
done

cd builder/init
dub run --compiler=$COMPILER --build=$BUILD --arch=$ARCH -- $CONFIG $PORTABLE
cd ..
dub build --compiler=$COMPILER --build=$BUILD --arch=$ARCH
