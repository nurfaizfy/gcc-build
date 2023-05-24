#!/usr/bin/env bash

echo "*****************************************"
echo "*        Download GCC & Binutils        *"
echo "*****************************************"

download() {
  echo "Cloning Binutils"
  git clone git://sourceware.org/git/binutils-gdb.git -b master binutils --depth=1
  sed -i '/^development=/s/true/false/' binutils/bfd/development.sh
  echo "Cloning GCC"
  git clone git://gcc.gnu.org/git/gcc.git -b master gcc --depth=1
  cd gcc
  ./contrib/download_prerequisites
  cd ../
}

download
