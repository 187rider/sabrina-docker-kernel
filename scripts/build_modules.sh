#!/usr/bin/env bash
set -euo pipefail

export PATH="/usr/lib/llvm-17/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${SRC:-/work/ksrc/aml_kernel}"
DOCKER_OUT="${DOCKER_OUT:-/work/out_docker}"
MOD_OUT="${MOD_OUT:-/work/out_modules}"

mkdir -p "$MOD_OUT" "$REPO_DIR/out/modules"
cp "$DOCKER_OUT/.config" "$MOD_OUT/.config"
cp "$DOCKER_OUT/vmlinux.symvers" "$MOD_OUT/Module.symvers"

make -C "$SRC" O="$MOD_OUT" ARCH=arm64 LLVM=1 LLVM_IAS=1 KCONFIG_EXT_PREFIX=common_drivers/ olddefconfig
make -C "$SRC" O="$MOD_OUT" ARCH=arm64 LLVM=1 LLVM_IAS=1 KCONFIG_EXT_PREFIX=common_drivers/ -j"$(nproc)" M=fs/ntfs3 modules
make -C "$SRC" O="$MOD_OUT" ARCH=arm64 LLVM=1 LLVM_IAS=1 KCONFIG_EXT_PREFIX=common_drivers/ -j"$(nproc)" M=fs/cifs modules

find "$MOD_OUT" -name "*.ko" -exec cp -v {} "$REPO_DIR/out/modules/" \;
ls -lh "$REPO_DIR/out/modules"
