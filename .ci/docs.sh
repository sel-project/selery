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
cd ..
mv build/init .
chmod +x init

# push
if [ $TRAVIS_TAG != "" ]; then
	cd website
	git config --global user.email "selutils@mail.com"
	git config --global user.name "sel-bot"
	git add --all .
	git commit -m "Generated documentation for sel-server ${TRAVIS_TAG}"
	git push "https://${TOKEN}@github.com/sel-project/sel-project.github.io" master
fi
