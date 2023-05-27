#!/usr/bin/env bash

cp ./install/bin/x86_64-elf-strip ./stripp-x86
cp ./install/bin/aarch64-elf-strip ./stripp-a64
cp ./install/bin/arm-eabi-strip ./stripp-a32
find install -type f -exec file {} \; > .file-idx

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

rm ".file-idx" stripp-*
