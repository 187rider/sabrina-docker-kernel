#!/system/bin/sh
# Reference Magisk service.d script for 1.5 GiB lz4 ZRAM on sabrina (2 GiB RAM)
until [ "$(getprop sys.boot_completed)" = "1" ]; do
  sleep 2
done

ZRAM_DEV=/dev/block/zram0
ZRAM_SYS=/sys/block/zram0

swapoff "$ZRAM_DEV" 2>/dev/null || true
echo 1 > "$ZRAM_SYS/reset"
echo 4 > "$ZRAM_SYS/max_comp_streams" 2>/dev/null || true
echo lz4 > "$ZRAM_SYS/comp_algorithm"
echo 1610612736 > "$ZRAM_SYS/disksize"
echo 671088640 > "$ZRAM_SYS/mem_limit"
mkswap "$ZRAM_DEV" >/dev/null
swapon -p 100 "$ZRAM_DEV"

sysctl -w vm.swappiness=100 >/dev/null
sysctl -w vm.page-cluster=0 >/dev/null
