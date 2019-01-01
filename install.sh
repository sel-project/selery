#!/bin/bash
#
# Copyright: 2017-2019 sel-project
# License: MIT
#

FOLDER=selery
VERSION=
ARCH=
PRESERVE=false

while [[ $# -gt 0 ]]; do
	case "$1" in
	
		-h | --help)
			echo "Usage: ./install.sh [-f <folder>] [-v <version>] [-a <arch>]"
			echo ""
			echo "Optional aguments:"
			echo "  -f <folder>           Extract files in the specified folder"
			echo "  -v <version>          Specify the version to download"
			echo "  -a <arch>             Manually indicate the system's architecture"
			exit 0
			;;
			
		-f)
			FOLDER=$2
			shift
			;;
		
		-v)
			VERSION=$2
			shift
			;;
			
		-a)
			ARCH=$2
			shift
			;;
		
		--preserve-archive | -pa)
			PRESERVE="true"
			;;
			
	esac
	shift
done

# get OS
case $(uname -s) in
    Darwin) OS=osx;;
    Linux) OS=linux;;
	MINGW*) OS=windows;;
    *)
        echo "Unsupported OS $(uname -s)"
		exit 1
        ;;
esac

# get arch if not specified
if [ "$ARCH" = "" ] ; then
	case $(uname -m) in
		x86_64|amd64) ARCH=x86_64;;
		i*86) ARCH=x86;;
		*)
			fatal "Unsupported arch $(uname -m)"
			;;
	esac
fi

# get latest version
if [ "$VERSION" = "" ] ; then
	VERSION=$(curl -s https://sel-bot.github.io/status/sel-project/selery/latest.txt)
fi

# create archive name
if [ "$OS" = "windows" ] ; then
	EXT="zip"
	if [ "$ARCH" = "x86_64" ] ; then ARCH="x64" ; fi
else
	EXT="tar.xz"
fi

# download
FILE="selery-$VERSION-$OS-$ARCH.$EXT"
curl -L "https://github.com/sel-project/selery/releases/download/v$VERSION/$FILE" -o $FILE

# extract
mkdir -p $FOLDER
if [ "$EXT" == "zip" ] ; then
	unzip -o $FILE -d $FOLDER
else
	tar -xJf $FILE -C $FOLDER
fi

# delete archive
if [ "$PRESERVE" = "false" ] ; then
	rm -f $FILE
fi
