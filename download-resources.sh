#!/usr/bin/env bash

echo "*****************************************"
echo "*        Download GCC & Binutils        *"
echo "*****************************************"

export \
  GCC=$1 \
  BINUTILS=$2

init(){
  mkdir binutils gcc
  cd binutils
  git init .
  git remote add origin git://sourceware.org/git/binutils-gdb.git
  cd ../gcc
  git init .
  git remote add origin git://gcc.gnu.org/git/gcc.git
  cd ..
}

fetch(){
  cd binutils
  git fetch --depth=1 origin $BINUTILS
  git fetch --depth=1 origin master
  cd ../gcc
  git fetch --depth=1 origin $GCC
  git fetch --depth=1 origin master
  cd ..
}

download() {
  cd gcc
  git checkout -f origin/master ./contrib/download_prerequisites ./gcc/BASE-VER
  ./contrib/download_prerequisites
  cd ..
  git clone https://github.com/facebook/zstd -b v1.5.5 zstd --depth=1
}

init
fetch
download
