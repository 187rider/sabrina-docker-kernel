#!/usr/bin/env bash
set -euo pipefail

export PATH="/usr/lib/llvm-17/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export KBUILD_BUILD_USER="${KBUILD_BUILD_USER:-sabrina-builder}"
export KBUILD_BUILD_HOST="${KBUILD_BUILD_HOST:-build-host}"

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KSRC_DIR="${KSRC_DIR:-/work/ksrc}"
SRC="${SRC:-$KSRC_DIR/aml_kernel}"
OUT="${OUT:-/work/out_docker}"

export GENKSYMS_STOCK_SYMVERS="${GENKSYMS_STOCK_SYMVERS:-$REPO_DIR/configs/stock_symvers.txt}"

echo "=== 1. Preparing build output directory ($OUT) ==="
mkdir -p "$OUT"
cp "$REPO_DIR/configs/stock.config" "$OUT/.config"

echo "=== 2. Configuring Hardware + Docker + NTFS3 + CIFS + BBR flags ==="
"$SRC/scripts/config" --file "$OUT/.config" \
  --enable CONFIG_AMLOGIC_PWM \
  --enable CONFIG_AMLOGIC_PWM_MESON \
  --enable CONFIG_AMLOGIC_PWM_MESON_TEE \
  --enable CONFIG_AMLOGIC_PWM_32K \
  --enable CONFIG_AMLOGIC_PWM_REGULATOR \
  --module CONFIG_AMLOGIC_ADC \
  --enable CONFIG_AMLOGIC_MESON_SARADC \
  --enable CONFIG_AMLOGIC_ADC_KEYPADS \
  --enable CONFIG_AMLOGIC_RFKILL_INIT_SW_UNBLOCK \
  --enable CONFIG_AMLOGIC_DRM_HDMI \
  --disable CONFIG_MODULE_SIG_ALL \
  --set-str CONFIG_MODULE_SIG_KEY "" \
  --set-str CONFIG_LOCALVERSION "-android14-sabrina-docker" \
  --disable CONFIG_LOCALVERSION_AUTO \
  --disable CONFIG_WERROR \
  --disable CONFIG_FRAME_WARN_ERROR \
  --disable CONFIG_UAPI_HEADER_TEST \
  --enable CONFIG_OVERLAY_FS \
  --enable CONFIG_VETH \
  --enable CONFIG_BRIDGE \
  --enable CONFIG_IP_NF_TARGET_MASQUERADE \
  --enable CONFIG_CPUSETS \
  --enable CONFIG_MEMCG \
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
  --enable CONFIG_NET_CLS_ACT \
  --enable CONFIG_NTFS3_FS \
  --enable CONFIG_NTFS3_64BIT_CLUSTER \
  --enable CONFIG_NTFS3_LZX_XPRESS \
  --enable CONFIG_NLS_UTF8 \
  --set-str CONFIG_NLS_DEFAULT "utf8" \
  --enable CONFIG_CIFS \
  --enable CONFIG_CIFS_XATTR \
  --enable CONFIG_CIFS_POSIX \
  --enable CONFIG_CRYPTO_MD5 \
  --enable CONFIG_CRYPTO_HMAC \
  --enable CONFIG_CRYPTO_CMAC \
  --enable CONFIG_CRYPTO_CCM \
  --enable CONFIG_CRYPTO_GCM \
  --enable CONFIG_CRYPTO_ARC4 \
  --enable CONFIG_TCP_CONG_ADVANCED \
  --enable CONFIG_TCP_CONG_BBR \
  --enable CONFIG_DEFAULT_BBR \
  --set-str CONFIG_DEFAULT_TCP_CONG "bbr" \
  --enable CONFIG_NET_SCH_FQ \
  --enable CONFIG_NET_SCH_FQ_CODEL

echo "=== 3. Ensuring common_drivers symlink ==="
ln -sfn ../common_drivers "${SRC}/common_drivers"

echo "=== 4. Updating config with olddefconfig ==="
make -C "$SRC" O="$OUT" ARCH=arm64 LLVM=1 LLVM_IAS=1 KCONFIG_EXT_PREFIX=common_drivers/ olddefconfig

echo "=== 5. Compiling host scripts including genksyms with stock CRC hook ==="
make -C "$SRC" O="$OUT" ARCH=arm64 LLVM=1 LLVM_IAS=1 KCONFIG_EXT_PREFIX=common_drivers/ scripts

echo "=== 6. Building kernel Image with $(nproc) jobs ==="
make -C "$SRC" O="$OUT" ARCH=arm64 LLVM=1 LLVM_IAS=1 KCONFIG_EXT_PREFIX=common_drivers/ \
  -j"$(nproc)" KCFLAGS="-Wno-error" Image

echo "=== 7. Comparing vmlinux.symvers against configs/all_vendor_symvers.txt ==="
python3 - "$REPO_DIR/configs/all_vendor_symvers.txt" "$GENKSYMS_STOCK_SYMVERS" "$OUT/vmlinux.symvers" <<'PY'
import sys

vendor_path, stock_path, vmlinux_path = sys.argv[1:4]

def load_symvers(path, sep=None):
    syms = {}
    with open(path) as f:
        for line in f:
            parts = line.strip().split(sep) if sep else line.strip().split()
            if len(parts) >= 2:
                syms[parts[1]] = int(parts[0], 16)
    return syms

vendor_syms = load_symvers(vendor_path)
stock_syms = load_symvers(stock_path)
vmlinux_syms = load_symvers(vmlinux_path, "\t")

overlap = set(vendor_syms.keys()) & set(vmlinux_syms.keys())
matched = sum(1 for s in overlap if vendor_syms[s] == vmlinux_syms[s])
mismatched = [(s, hex(vendor_syms[s]), hex(vmlinux_syms[s])) for s in overlap if vendor_syms[s] != vmlinux_syms[s]]

expected_vmlinux_syms = set(vendor_syms.keys()) & set(stock_syms.keys())
missing_from_vmlinux = expected_vmlinux_syms - set(vmlinux_syms.keys())
inter_module_syms = set(vendor_syms.keys()) - set(stock_syms.keys())

print(f"Total vendor symbols analyzed: {len(vendor_syms)}")
print(f"  - Expected from vmlinux: {len(expected_vmlinux_syms)}")
print(f"  - Inter-vendor module exports: {len(inter_module_syms)}")
print(f"Vmlinux vendor symbols matched: {matched} / {len(expected_vmlinux_syms)} ({matched/len(expected_vmlinux_syms)*100:.2f}%)")
print(f"Mismatched CRCs: {len(mismatched)}")
print(f"Missing from vmlinux: {len(missing_from_vmlinux)}")

if mismatched or missing_from_vmlinux:
    for m in mismatched[:10]:
        print(f"  MISMATCH {m[0]}: vendor={m[1]} built={m[2]}")
    for s in sorted(missing_from_vmlinux)[:10]:
        print(f"  MISSING: {s}")
    sys.exit(1)
PY

echo "=== 8. Writing Image_docker & Image_docker.lzma ==="
mkdir -p "$REPO_DIR/out"
cp "$OUT/arch/arm64/boot/Image" "$REPO_DIR/out/Image_docker"
lzma -f -k -c "$REPO_DIR/out/Image_docker" > "$REPO_DIR/out/Image_docker.lzma"
ls -la "$REPO_DIR/out/Image_docker" "$REPO_DIR/out/Image_docker.lzma"
echo "=== BUILD SUCCESSFUL ==="
