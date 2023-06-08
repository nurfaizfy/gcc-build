#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0
# Author: Vaisakh Murali
set -e

echo "*****************************************"
echo "* Building Bare-Metal Bleeding Edge GCC *"
echo "*****************************************"

export WORK_DIR="${PWD}"
export NPROC="$(nproc --all)"
export PREFIX="${WORK_DIR}/install"
export PATH="${PREFIX}/bin:${PATH}"
export OPT_FLAGS="-O3 -flto=${NPROC} -fipa-pta -pipe -ffunction-sections -fdata-sections -fgraphite -fgraphite-identity -floop-nest-optimize -Wl,-S,--gc-sections"
export BUILD_DATE="$(date +%Y%m%d)"
export BUILD_DAY="$(date "+%d %B %Y")"
export BUILD_TAG="$(date +%Y%m%d-%H%M-%Z)"
export TARGETS="x86_64-elf aarch64-elf"
export HEAD_SCRIPT="$(git log -1 --oneline)"
export HEAD_GCC="$(git --git-dir gcc/.git log -1 --oneline)"
export HEAD_BINUTILS="$(git --git-dir binutils/.git log -1 --oneline)"
export IS_MASTER="${1}"

send_info(){
  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d chat_id="${CHAT_ID}" \
    -d "parse_mode=html" \
    -d text="${1}" > /dev/null 2>&1
}

send_file(){
  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" \
    -F document=@"${1}" \
    -F chat_id="${CHAT_ID}" \
    -F "parse_mode=html" \
    -F caption="${2}" > /dev/null 2>&1
}

build_zstd() {
#  send_info "<b>GitHub Action : </b><pre>Zstd build started . . .</pre>"
  mkdir ${WORK_DIR}/build-zstd
  pushd ${WORK_DIR}/build-zstd
  env CFLAGS="${OPT_FLAGS}" CXXFLAGS="${OPT_FLAGS}" \
    cmake ${WORK_DIR}/zstd/build/cmake -DCMAKE_INSTALL_PREFIX:PATH="${PREFIX}" |& tee -a build.log
  make -j${NPROC} |& tee -a build.log
  make install -j${NPROC} |& tee -a build.log

  # check Zstd build status
  if [ -f "${PREFIX}/bin/zstd" ]; then
    rm -rf ${WORK_DIR}/build-zstd
#    send_info "<b>GitHub Action : </b><pre>Zstd build finished ! ! !</pre>"
    popd
  else
    send_info "<b>GitHub Action : </b><pre>Zstd build failed ! ! !</pre>"
    send_file ./build.log "Zstd build.log"
    popd
    exit 1
  fi
}

build_binutils() {
#  send_info "<b>GitHub Action : </b><pre>Binutils build started . . .</pre><b>Target : </b><pre>[${TARGET}]</pre>"
  mkdir ${WORK_DIR}/build-binutils
  pushd ${WORK_DIR}/build-binutils
  env CFLAGS="${OPT_FLAGS}" CXXFLAGS="${OPT_FLAGS}" \
    ../binutils/configure \
    --target=${TARGET} \
    --disable-docs \
    --disable-gdb \
    --disable-nls \
    --disable-shared \
    --enable-gold \
    --prefix="${PREFIX}" \
    --quiet \
    --with-pkgversion='CAT (=^ェ^=) Binutils' \
    --with-sysroot |& tee -a build.log
  make -j${NPROC} |& tee -a build.log
  make install -j${NPROC} |& tee -a build.log

  # check Binutils build status
  if [ -f "${PREFIX}/bin/${TARGET}-ld" ]; then
    rm -rf ${WORK_DIR}/build-binutils
#    send_info "<b>GitHub Action : </b><pre>Binutils build finished ! ! !</pre>"
    popd
  else
    send_info "<b>GitHub Action : </b><pre>Binutils build failed ! ! !</pre>"
    send_file ./build.log "Binutils build.log"
    popd
    exit 1
  fi
}

build_gcc() {
#  send_info "<b>GitHub Action : </b><pre>GCC build started . . .</pre><b>Target : </b><pre>[${TARGET}]</pre>"
  mkdir ${WORK_DIR}/build-gcc
  pushd ${WORK_DIR}/build-gcc
  env CFLAGS="${OPT_FLAGS}" CXXFLAGS="${OPT_FLAGS}" \
    ../gcc/configure \
    --target=${TARGET} \
    --disable-decimal-float \
    --disable-docs \
    --disable-libffi \
    --disable-libgomp \
    --disable-libquadmath \
    --disable-libstdcxx-pch \
    --disable-nls \
    --disable-shared \
    --enable-default-ssp \
    --enable-languages=c,c++ \
    --prefix="${PREFIX}" \
    --quiet \
    --with-gnu-as \
    --with-gnu-ld \
    --with-headers="/usr/include" \
    --with-linker-hash-style=gnu \
    --with-newlib \
    --with-pkgversion='CAT (=^ェ^=) GCC' \
    --with-sysroot
#    --with-zstd="${PREFIX}" \
#    --with-zstd-include="${PREFIX}/include" \
#    --with-zstd-lib="${PREFIX}/lib" |& tee -a build.log
  make all-gcc -j${NPROC} |& tee -a build.log
  make all-target-libgcc -j${NPROC} |& tee -a build.log
  make install-gcc -j${NPROC} |& tee -a build.log
  make install-target-libgcc -j${NPROC} |& tee -a build.log

  # check GCC build status
  if [ -f "${PREFIX}/bin/${TARGET}-gcc" ]; then
    rm -rf ${WORK_DIR}/build-gcc
#    send_info "<b>GitHub Action : </b><pre>GCC build finished ! ! !</pre>"
    popd
  else
    send_info "<b>GitHub Action : </b><pre>GCC build failed ! ! !</pre>"
    send_file ./build.log "GCC build.log"
    popd
    exit 1
  fi
}

strip_binaries(){
#  send_info "<b>GitHub Action : </b><pre>Strip binaries . . .</pre>"

  find install -type f -exec file {} \; > .file-idx

  cp -rf ${PREFIX}/bin/x86_64-elf-strip ./stripp-x86 || true
  cp -rf ${PREFIX}/bin/aarch64-elf-strip ./stripp-a64 || true
  cp -rf ${PREFIX}/bin/arm-eabi-strip ./stripp-a32 || true

  grep "x86-64" .file-idx |
    grep "not strip" |
    tr ':' ' ' | awk '{print $1}' |
    while read -r file; do ./stripp-x86 -s "$file"; done

  grep "ARM" .file-idx | grep "aarch64" |
    grep "not strip" |
    tr ':' ' ' | awk '{print $1}' |
    while read -r file; do ./stripp-a64 -s "$file"; done

  grep "ARM" .file-idx | grep "eabi" |
    grep "not strip" |
    tr ':' ' ' | awk '{print $1}' |
    while read -r file; do ./stripp-a32 -s "$file"; done

  # clean unused files
  rm -rf stripp-* .file-idx
}

git_push(){
  send_info "<b>GitHub Action : </b><pre>Release into GitHub . . .</pre>"
  GCC_CONFIG="$(${PREFIX}/bin/aarch64-elf-gcc -v)"
  GCC_VERSION="$(${PREFIX}/bin/aarch64-elf-gcc --version | head -n1 | cut -d' ' -f5)"
  BINUTILS_VERSION="$(${PREFIX}/bin/aarch64-elf-ld --version | head -n1 | cut -d' ' -f6)"
  MESSAGE="GCC: ${GCC_VERSION}-${BUILD_DATE}, Binutils: ${BINUTILS_VERSION}"
  git config --global user.name "${GITHUB_USER}"
  git config --global user.email "${GITHUB_EMAIL}"
  if [ "${IS_MASTER}" == "master" ]; then
    git clone https://"${GITHUB_USER}":"${GITHUB_TOKEN}"@github.com/"${GITHUB_USER}"/gcc ${WORK_DIR}/gcc-repo -b main
  else
    git clone https://"${GITHUB_USER}":"${GITHUB_TOKEN}"@github.com/"${GITHUB_USER}"/gcc-stable ${WORK_DIR}/gcc-repo -b main
  fi
  # Generate archive
  pushd ${WORK_DIR}/gcc-repo
  cp -rf ${PREFIX}/* .
  tar -I"${PREFIX}/bin/zstd -12" -cf gcc.tar.zst *
  cat README | \
    sed s/GCCVERSION/$(echo ${GCC_VERSION}-${BUILD_DATE})/g | \
    sed s/BINUTILSVERSION/$(echo ${BINUTILS_VERSION})/g > README.md
  git commit --allow-empty -as \
    -m "${MESSAGE}" \
    -m "${GCC_CONFIG}"
  git push origin main
  hub release create -a gcc.tar.zst -m "${MESSAGE}" ${BUILD_TAG}
  popd
}

send_info "
<b>Date : </b><pre>${BUILD_DAY}</pre>
<b>GitHub Action : </b><pre>Toolchain compilation started . . .</pre>

<b>Script </b><pre>${HEAD_SCRIPT}</pre>
<b>GCC </b><pre>${HEAD_GCC}</pre>
<b>Binutils </b><pre>${HEAD_BINUTILS}</pre>"
build_zstd
for TARGET in ${TARGETS}; do
  build_binutils
  build_gcc
done
strip_binaries
git_push
send_info "<b>GitHub Action : </b><pre>All job finished ! ! !</pre>"
