#!/usr/bin/env bash
set -euo pipefail

export PATH="/usr/lib/llvm-17/bin:$PATH"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${SRC:-/work/ksrc/aml_kernel}"
OUT="${OUT:-/work/out_docker}"

mkdir -p "$OUT"
cp "$REPO_DIR/configs/stock.config" "$OUT/.config"

"$SRC/scripts/config" --file "$OUT/.config" \
  --enable CONFIG_AMLOGIC_PWM \
  --enable CONFIG_AMLOGIC_PWM_MESON \
  --enable CONFIG_AMLOGIC_PWM_MESON_TEE \
  --enable CONFIG_AMLOGIC_PWM_32K \
  --enable CONFIG_AMLOGIC_PWM_REGULATOR \
  --module CONFIG_AMLOGIC_ADC \
  --enable CONFIG_AMLOGIC_MESON_SARADC \
  --enable CONFIG_AMLOGIC_ADC_KEYPADS \
  --disable CONFIG_MODULE_SIG_ALL \
  --set-str CONFIG_MODULE_SIG_KEY "" \
  --set-str CONFIG_LOCALVERSION "-android14-sabrina-docker" \
  --disable CONFIG_LOCALVERSION_AUTO \
  --disable CONFIG_WERROR \
  --disable CONFIG_FRAME_WARN_ERROR \
  --disable CONFIG_UAPI_HEADER_TEST \
  --enable CONFIG_PID_NS \
  --enable CONFIG_SYSVIPC \
  --enable CONFIG_IPC_NS \
  --enable CONFIG_POSIX_MQUEUE \
  --enable CONFIG_USER_NS \
  --enable CONFIG_CGROUP_PIDS \
  --enable CONFIG_CGROUP_DEVICE \
  --enable CONFIG_CFS_BANDWIDTH \
  --enable CONFIG_CGROUP_NET_CLASSID \
  --enable CONFIG_NETFILTER_XT_MATCH_ADDRTYPE \
  --enable CONFIG_BRIDGE_NETFILTER \
  --enable CONFIG_NET_CLS_ACT

make -C "$SRC" O="$OUT" ARCH=arm64 LLVM=1 LLVM_IAS=1 KCONFIG_EXT_PREFIX=common_drivers/ olddefconfig
