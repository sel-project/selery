#!/bin/bash
cd init
dub run
cd ..
dub build -a x86_64
