#!/usr/bin/env bash
set -euo pipefail

export PATH="/usr/lib/llvm-17/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${SRC:-/work/ksrc/aml_kernel}"
MOD_OUT="${MOD_OUT:-/work/out_modules}"

mkdir -p "$REPO_DIR/out/modules"
"$SRC/scripts/config" --file "$MOD_OUT/.config" \
  --module CONFIG_DNS_RESOLVER \
  --module CONFIG_CIFS \
  --enable CONFIG_CIFS_ALLOW_INSECURE_LEGACY

make -C "$SRC" O="$MOD_OUT" ARCH=arm64 LLVM=1 LLVM_IAS=1 KCONFIG_EXT_PREFIX=common_drivers/ olddefconfig
rm -rf "$MOD_OUT/fs/cifs"/*.o "$MOD_OUT/fs/cifs"/*.ko
make -C "$SRC" O="$MOD_OUT" ARCH=arm64 LLVM=1 LLVM_IAS=1 KCONFIG_EXT_PREFIX=common_drivers/ -j"$(nproc)" M=net/dns_resolver modules
make -C "$SRC" O="$MOD_OUT" ARCH=arm64 LLVM=1 LLVM_IAS=1 KCONFIG_EXT_PREFIX=common_drivers/ -j"$(nproc)" M=fs/cifs modules

cp -v "$MOD_OUT/net/dns_resolver/dns_resolver.ko" "$REPO_DIR/out/modules/dns_resolver.ko"
cp -v "$MOD_OUT/fs/cifs/cifs.ko" "$REPO_DIR/out/modules/cifs.ko"
ls -lh "$REPO_DIR/out/modules/"*.ko
