#!/bin/bash
set -e

# This script downloads the binaries for the most recent version of TabNine.
# Based off of: https://github.com/codota/TabNine/blob/master/dl_binaries.sh
if [ "$(uname -s)" = "Darwin" ]; then
  if [ "$(arch)" = "arm64" ]; then
    targets='aarch64-apple-darwin'
  else
    targets='x86_64-apple-darwin'
  fi
fi

version="$(curl -sS https://update.tabnine.com/bundles/version)"

rm -rf ./binaries

echo "$targets" | while read target
do
  mkdir -p binaries/$version/$target
  path=$version/$target
  echo "downloading $path"
  curl -sS https://update.tabnine.com/bundles/$path/TabNine.zip > binaries/$path/TabNine.zip
  unzip -o binaries/$path/TabNine.zip -d binaries/$path
  rm binaries/$path/TabNine.zip
  chmod +x binaries/$path/*
done
