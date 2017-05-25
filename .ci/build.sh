#!/bin/sh
cd ../build
dub init.d --arch=$CONFIG --compiler=$DC
dub build --config=lite --arch=$CONFIG --compiler=$DC --build=release
dub build --config=hub --arch=$CONFIG --compiler=$DC --build=release
dub build --config=node --arch=$CONFIG --compiler=$DC --build=release
