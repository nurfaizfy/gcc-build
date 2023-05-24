#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0
# Author: Vaisakh Murali
set -e

echo "*****************************************"
echo "* Building Bare-Metal Bleeding Edge GCC *"
echo "*****************************************"

# TODO: Add more dynamic option handling
while getopts a: flag; do
  case "${flag}" in
    a) arch=${OPTARG} ;;
    *) echo "Invalid argument passed" && exit 1 ;;
  esac
done

# TODO: Better target handling
case "${arch}" in
  "arm") TARGET="arm-eabi" ;;
  "arm64") TARGET="aarch64-elf" ;;
  "arm64gnu") TARGET="aarch64-linux-gnu" ;;
  "x86") TARGET="x86_64-elf" ;;
esac

export WORK_DIR="$PWD"
export PREFIX="${WORK_DIR}/../gcc-${arch}"
export PATH="${PREFIX}/bin:/usr/bin/core_perl:${PATH}"
export OPT_FLAGS="-O3 -pipe -ffunction-sections -fdata-sections"

echo "Cleaning up previous build directory..."
rm -rf ${WORK_DIR}/{build-binutils,build-gcc,build-zstd}

echo "||                                                                    ||"
echo "|| Building Bare Metal Toolchain for ${arch} with ${TARGET} as target ||"
echo "||                                                                    ||"

send_info(){
  MESSAGE=$1
  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d chat_id="${CHAT_ID}" \
    -d "disable_web_page_preview=true" \
    -d "parse_mode=html" \
    -d text="<b>${MESSAGE}</b>"
}

build_zstd() {
  echo "Building zstd"
  send_info "Starting Zstd build"
  mkdir ${WORK_DIR}/build-zstd
  pushd ${WORK_DIR}/build-zstd
  cmake ${WORK_DIR}/zstd/build/cmake -DCMAKE_INSTALL_PREFIX:PATH="${PREFIX}"
  make CFLAGS="-O3" CXXFLAGS="-O3" -j$(nproc --all)
  make install -j$(nproc --all)
  popd
}

build_binutils() {
  echo "Building Binutils"
  send_info "Starting [ ${arch} / ${TARGET} ] Binutils build"
  mkdir ${WORK_DIR}/build-binutils
  pushd ${WORK_DIR}/build-binutils
  env CFLAGS="$OPT_FLAGS" CXXFLAGS="$OPT_FLAGS" \
    ../binutils/configure --target=$TARGET \
    --disable-docs \
    --disable-gdb \
    --disable-nls \
    --disable-werror \
    --enable-gold \
    --prefix="$PREFIX" \
    --with-pkgversion="Eva Binutils" \
    --with-sysroot
  make -j$(nproc --all)
  make install -j$(nproc --all)
  echo "Built Binutils!"
  popd
}

build_gcc() {
  echo "Building GCC"
  send_info "Starting [ ${arch} / ${TARGET} ] GCC build"
  mkdir ${WORK_DIR}/build-gcc
  pushd ${WORK_DIR}/build-gcc
  env CFLAGS="$OPT_FLAGS" CXXFLAGS="$OPT_FLAGS" \
    ../gcc/configure --target=$TARGET \
    --disable-decimal-float \
    --disable-docs \
    --disable-gcov \
    --disable-libffi \
    --disable-libgomp \
    --disable-libmudflap \
    --disable-libquadmath \
    --disable-libstdcxx-pch \
    --disable-nls \
    --disable-shared \
    --enable-default-ssp \
    --enable-languages=c,c++ \
    --enable-threads=posix \
    --prefix="$PREFIX" \
    --with-gnu-as \
    --with-gnu-ld \
    --with-headers="/usr/include" \
    --with-linker-hash-style=gnu \
    --with-newlib \
    --with-pkgversion="SAMBEN GCC" \
    --with-sysroot \
    --with-zstd="${PREFIX}" \
    --with-zstd-include="${PREFIX}/include" \
    --with-zstd-lib="${PREFIX}/lib"

  make all-gcc -j$(nproc --all)
  make all-target-libgcc -j$(nproc --all)
  make install-gcc -j$(nproc --all)
  make install-target-libgcc -j$(nproc --all)
  echo "Built GCC!"
  popd
}

strip_binaries(){
  pushd ${PREFIX}
  ${PREFIX}/bin/${TARGET}-gcc -v 2>&1 | tee /tmp/gcc-version
  ${WORK_DIR}/strip-binaries.sh
  popd
}

git_push(){
  pushd ${PREFIX}
  send_info "Pushing into Github"
  git add . -f
  git commit -as \
    -m "Import GCC $(date +%Y%m%d)" \
    -m "Build completed on: $(date)" \
    -m "Configuration: $(cat /tmp/gcc-version)"
  git push origin gcc-latest -f
  popd
}

build_zstd
build_binutils
build_gcc
strip_binaries
git_push
