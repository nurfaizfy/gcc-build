#!/usr/bin/env bash

echo "*****************************************"
echo "*        Download GCC & Binutils        *"
echo "*****************************************"

export IS_MASTER="${1}"

download() {
  if [ "${IS_MASTER}" == "master" ]; then
    git clone -b master --depth=1 git://sourceware.org/git/binutils-gdb.git binutils
    git clone -b master --depth=1 git://gcc.gnu.org/git/gcc.git gcc
    git clone -b dev https://github.com/facebook/zstd zstd
  else
    git clone -b binutils-2_40-branch --depth=1 git://sourceware.org/git/binutils-gdb.git binutils
    git clone -b releases/gcc-13 --depth=1 git://gcc.gnu.org/git/gcc.git gcc
    git clone -b v1.5.5 https://github.com/facebook/zstd zstd
  fi
  sed -i '/^development=/s/true/false/' binutils/bfd/development.sh
  cd gcc
  ./contrib/download_prerequisites
  cd ..
}

download
