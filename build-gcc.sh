#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0
# Author: Vaisakh Murali
set -e

echo "*****************************************"
echo "* Building Bare-Metal Bleeding Edge GCC *"
echo "*****************************************"

export WORK_DIR="$PWD"
export PREFIX="${WORK_DIR}/install"
export PATH="${PREFIX}/bin:/usr/bin/core_perl:${PATH}"
export OPT_FLAGS="-O3 -pipe -ffunction-sections -fdata-sections"
export BUILD_DATE="$(date +%Y%m%d)"
export BUILD_DAY="$(date "+%d %B %Y")"
mkdir ${PREFIX}

send_info(){
  MESSAGE=$1
  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d chat_id="${CHAT_ID}" \
    -d "parse_mode=html" \
    -d text="${MESSAGE}" > /dev/null 2>&1
}

build_zstd() {
  send_info "<pre>GitHub Action       : Zstd build started . . .</pre>"
  mkdir ${WORK_DIR}/build-zstd
  pushd ${WORK_DIR}/build-zstd
  cmake ${WORK_DIR}/zstd/build/cmake -DCMAKE_INSTALL_PREFIX:PATH="${PREFIX}"
  make CFLAGS="-O3" CXXFLAGS="-O3" -j$(nproc --all)
  make install -j$(nproc --all)
  popd
  rm -rf ${WORK_DIR}/build-zstd
  send_info "<pre>GitHub Action       : Zstd build finished ! ! !</pre>"
}

build_binutils() {
  # Better target handling
  ARCH=$1
  case "${ARCH}" in
    "arm") TARGET="arm-eabi" ;;
    "arm64") TARGET="aarch64-elf" ;;
    "arm64gnu") TARGET="aarch64-linux-gnu" ;;
    "x86") TARGET="x86_64-elf" ;;
  esac

  send_info "<pre>GitHub Action       : Binutils build started . . .</pre><pre>Target              : [${TARGET}]</pre>"
  mkdir ${WORK_DIR}/build-binutils-${ARCH}
  pushd ${WORK_DIR}/build-binutils-${ARCH}
  env CFLAGS="${OPT_FLAGS}" CXXFLAGS="${OPT_FLAGS}" \
    ../binutils/configure \
    --target=${TARGET} \
    --disable-docs \
    --disable-gdb \
    --disable-nls \
    --disable-werror \
    --enable-gold \
    --prefix="${PREFIX}" \
    --with-pkgversion='CAT Binutils (=^ェ^=)' \
    --with-sysroot
  make -j$(nproc --all)
  make install -j$(nproc --all)
  popd
  rm -rf ${WORK_DIR}/build-binutils-${ARCH}
  send_info "<pre>GitHub Action       : Binutils build finished ! ! !</pre>"
}

build_gcc() {
  # Better target handling
  ARCH=$1
  case "${ARCH}" in
    "arm") TARGET="arm-eabi" ;;
    "arm64") TARGET="aarch64-elf" ;;
    "arm64gnu") TARGET="aarch64-linux-gnu" ;;
    "x86") TARGET="x86_64-elf" ;;
  esac

  echo "Building GCC"
  send_info "<pre>GitHub Action       : GCC build started . . .</pre><pre>Target              : [${TARGET}]</pre>"
  mkdir ${WORK_DIR}/build-gcc-${ARCH}
  pushd ${WORK_DIR}/build-gcc-${ARCH}
  env CFLAGS="${OPT_FLAGS}" CXXFLAGS="${OPT_FLAGS}" \
    ../gcc/configure \
    --target=${TARGET} \
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
    --prefix="${PREFIX}" \
    --with-gnu-as \
    --with-gnu-ld \
    --with-headers="/usr/include" \
    --with-linker-hash-style=gnu \
    --with-newlib \
    --with-pkgversion='CAT GCC (=^ェ^=)' \
    --with-sysroot \
    --with-zstd="${PREFIX}" \
    --with-zstd-include="${PREFIX}/include" \
    --with-zstd-lib="${PREFIX}/lib"
  make all-gcc -j$(nproc --all)
  make all-target-libgcc -j$(nproc --all)
  make install-gcc -j$(nproc --all)
  make install-target-libgcc -j$(nproc --all)
  popd
  rm -rf ${WORK_DIR}/build-gcc-${ARCH}
  send_info "<pre>GitHub Action       : GCC build finished ! ! !</pre>"
}

strip_binaries(){
  send_info "<pre>GitHub Action       : Strip binaries . . .</pre>"
  ${PREFIX}/bin/aarch64-elf-gcc -v 2>&1 | tee /tmp/gcc-version
  ${WORK_DIR}/strip-binaries.sh
}

git_push(){
  send_info "<pre>GitHub Action       : Release into GitHub . . .</pre>"
  GCC_VERSION="$(${PREFIX}/bin/aarch64-elf-gcc --version | head -n1 | cut -d' ' -f5)"
  BINUTILS_VERSION="$(${PREFIX}/bin/aarch64-elf-ld --version | head -n1 | cut -d' ' -f6)"
  git config --global user.name "${GITHUB_USER}"
  git config --global user.email "${GITHUB_EMAIL}"
  git clone https://"${GITHUB_USER}":"${GITHUB_TOKEN}"@github.com/"${GITHUB_USER}"/gcc gcc-repo -b main
  pushd gcc-repo
  cat README | \
    sed s/GCCVERSION/$(echo ${GCC_VERSION}-${BUILD_DATE})/g | \
    sed s/BINUTILSVERSION/$(echo ${BINUTILS_VERSION})/g > README.md
  git commit -as \
    -m "GCC: ${GCC_VERSION}-${BUILD_DATE}, Binutils: ${BINUTILS_VERSION}" \
    -m "Configuration: $(cat /tmp/gcc-version)"

  # Generate archive
  cp -rf ${PREFIX}/* .
  rm README*
  tar --use-compress-program='./bin/zstd -12' -cf gcc.tar.zst *
  git push origin main
  hub release create -a gcc.tar.zst -m "GCC: ${GCC_VERSION}-${BUILD_DATE}, Binutils: ${BINUTILS_VERSION}" ${BUILD_DATE}
  popd
}

send_info "<pre>Date                : ${BUILD_DAY}</pre><pre>GitHub Action       : Toolchain compilation started . . .</pre>"
build_zstd
build_binutils arm64
build_binutils arm
build_binutils x86
build_gcc arm64
build_gcc arm
build_gcc x86
strip_binaries
git_push
send_info "<pre>GitHub Action       : All job finished ! ! !</pre>"
