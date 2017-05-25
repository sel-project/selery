#!/bin/sh
cd ../build
dub init.d --arch=$ARCH --compiler=$DC --build=$CONFIG
travis_wait 30 dub build --config=lite --arch=$ARCH --compiler=$DC --build=$CONFIG
dub build --config=hub --arch=$ARCH --compiler=$DC --build=$CONFIG
dub build --config=node --arch=$ARCH --compiler=$DC --build=$CONFIG
