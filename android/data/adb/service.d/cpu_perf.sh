#!/system/bin/sh
until [ "$(getprop sys.boot_completed)" = "1" ]; do
  sleep 2
done
# Wait past vendor on property:sys.boot_completed=1 governor write (init.amlogic.board.rc)
sleep 10
for p in /sys/devices/system/cpu/cpufreq/policy*; do
  echo performance > "$p/scaling_governor" 2>/dev/null || true
done
echo 4 > /sys/class/mpgpu/min_freq 2>/dev/null || true
echo always_on > /sys/class/misc/mali0/device/power_policy 2>/dev/null || true
for q in /sys/block/mmcblk0/queue; do
  echo kyber > "$q/scheduler" 2>/dev/null || true
  echo 256 > "$q/read_ahead_kb" 2>/dev/null || true
  echo 0 > "$q/iostats" 2>/dev/null || true
  echo 0 > "$q/add_random" 2>/dev/null || true
done

# Keep VPU at 666.67MHz (level 8) to prevent 4K60 HDR10 FIFO underruns
echo set 8 > /sys/class/vpu/clk 2>/dev/null
