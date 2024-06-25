#!/bin/sh -ex

curl -fsSLo- --compressed https://raw.githubusercontent.com/nodejs/node/main/README.md | awk '/^gpg --keyserver hkps:\/\/keys\.openpgp\.org --recv-keys/ {sub(/^.*--recv-keys /, ""); print}' | sed '1d' > keys/node.keys
