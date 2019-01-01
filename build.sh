#!/bin/bash
#
# Copyright: 2017-2019 sel-project
# License: MIT
#

COMPILER=
BUILD=debug
ARCH=
CONFIG=default
PLUGINS=
PORTABLE=

while [[ $# -gt 0 ]]; do
	case "$1" in
	
		-h | --help)
			echo "Usage: ./build.sh [-h] [--dmd|--ldc|-c COMPILER] [debug|release] [-a ARCH] [default|hub|node] [-np] [--clean]"
			echo ""
			echo "Optional aguments:"
			echo "  -h, --help            Show this message and exit"
			echo "  --dmd, --ldc          Compile using the DMD or LDC compiler"
			echo "  -c COMPILER           Compile using the spcified compiler"
			echo "  debug, release        Compile using DUB's debug or release mode"
			echo "  -a ARCH               Specify the architecture to build for"
			echo "  default, hub, node    Compile the specified configuration for Selery"
			echo "  -np, --no-plugins     Compile without plugins"
			echo "  --clean               Remove dub.selections.json files"
			exit 0
			;;
			
		--dmd)
			COMPILER=dmd
			;;
			
		--ldc | --ldc2)
			COMPILER=ldc2
			;;
		
		-c)
			COMPILER=$2
			shift
			;;

		debug | release)
			BUILD=$1
			;;
		
		default | classic | hub | node)
			CONFIG=$1
			;;
			
		-a)
			ARCH="--arch=$2"
			shift
			;;
			
		-np | --no-plugins)
			PLUGINS=--no-plugins
			;;
		
		--portable)
			PORTABLE=--portable
			;;
			
		--clean)
			rm -f dub.selections.json
			rm -f builder/dub.selections.json
			rm -f builder/init/dub.selections.json
			;;
			
	esac
	shift
done

if [ "$COMPILER" = "" ] ; then
	case $(uname -m) in
		arm*) COMPILER=ldc2;;
		*) COMPILER=dmd;;
	esac
fi

cd builder/init
dub run --compiler=$COMPILER --build=$BUILD $ARCH -- $CONFIG $PLUGINS $PORTABLE || exit 1
cd ..
dub build --compiler=$COMPILER --build=$BUILD $ARCH
