#!/bin/sh
cd ../init
dub run --arch=$CONFIG --compiler=$DC --build=release
cd ../build
dub build --config=lite --arch=$CONFIG --compiler=$DC --build=release
dub build --config=hub --arch=$CONFIG --compiler=$DC --build=release
dub build --config=node --arch=$CONFIG --compiler=$DC --build=release
