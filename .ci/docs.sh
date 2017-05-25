#!/bin/sh
cd ..
git clone https://github.com/sel-project/sel-project.github.io.git website
rm -r -f website/server/docs
mkdir -p website/server/docs

# generate documentation
cd common && dub build --build=docs && cd ..
cd hub && dub build --build=docs && cd ..
cd node && dub build --build=docs && cd ..

if [[ "$TRAVIS_TAG" -ne "" ]]
then

	# copy files
	cp -r -f common/docs website/server
	cp -r -f hub/docs website/server
	cp -r -f node/docs website/server

	# push
	cd website
	git config --global user.email "selutils@mail.com"
	git config --global user.name "sel-bot"
	git add --all .
	git commit -m "Generated documentation for sel-server ${TRAVIS_TAG}"
	git push "https://${TOKEN}@github.com/sel-project/sel-project.github.io" master
	
fi
