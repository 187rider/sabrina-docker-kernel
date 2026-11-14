#!/usr/bin/env bash
set -euo pipefail

# Clone and patch Amlogic 5.15 kernel sources at the exact base revisions
# used for the Chromecast with Google TV 4K (sabrina) Docker kernel.
WORK_DIR="${1:-/work/ksrc}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "$WORK_DIR"

if [ ! -d "$WORK_DIR/aml_kernel/.git" ]; then
  git clone https://github.com/LineageOS/android_kernel_amlogic_kernel-5.15 "$WORK_DIR/aml_kernel"
fi
git -C "$WORK_DIR/aml_kernel" fetch origin 1c244a9cff6384fb1eddc1a9554fcf116ad9367d --depth=1 || true
git -C "$WORK_DIR/aml_kernel" checkout --force 1c244a9cff6384fb1eddc1a9554fcf116ad9367d
git -C "$WORK_DIR/aml_kernel" apply --check "$REPO_DIR/patches/aml_kernel.patch"
git -C "$WORK_DIR/aml_kernel" apply "$REPO_DIR/patches/aml_kernel.patch"

if [ ! -d "$WORK_DIR/common_drivers/.git" ]; then
  git clone https://github.com/LineageOS/android_kernel_amlogic_common_drivers "$WORK_DIR/common_drivers"
fi
git -C "$WORK_DIR/common_drivers" fetch origin 11f9da28a599bb93fee1bd6ef493a161deaf75de --depth=1 || true
git -C "$WORK_DIR/common_drivers" checkout --force 11f9da28a599bb93fee1bd6ef493a161deaf75de
git -C "$WORK_DIR/common_drivers" apply --check "$REPO_DIR/patches/common_drivers.patch"
git -C "$WORK_DIR/common_drivers" apply "$REPO_DIR/patches/common_drivers.patch"

ln -sfn ../common_drivers "$WORK_DIR/aml_kernel/common_drivers"
echo "Sources ready in $WORK_DIR"
