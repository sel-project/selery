#!/bin/sh
cd ..
git clone https://github.com/sel-project/sel-project.github.io.git website
rm -r -f website/server/docs
mkdir -p website/server/docs

# generate documentation
cd common && dub build --build=docs && cd ..
cd hub && dub build --build=docs && cd ..
cd node && dub build --build=docs && cd ..

# copy files
cp -r -f common/docs website/server
cp -r -f hub/docs website/server
cp -r -f node/docs website/server

# build init for the version
cd build
dub build --single init.d
mv init ../
cd ..
chmod +x init

# push
cd website
git add --all .
git commit -m "Generated documentation for sel-server $(./init --version)"
git push "https://${TOKEN}@github.com/sel-project/sel-project.github.io" master
