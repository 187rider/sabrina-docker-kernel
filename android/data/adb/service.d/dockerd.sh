#!/system/bin/sh
(
exec >/data/local/tmp/docker_boot.log 2>&1
until [ "$(getprop sys.boot_completed)" = "1" ]; do
  sleep 1
done

ROOT=/data/local/alpine
BB=/data/adb/magisk/busybox
is_mounted() { "$BB" mountpoint -q "$1" 2>/dev/null || grep -q " $1 " /proc/mounts; }

if ! is_mounted "$ROOT"; then
  "$BB" mount --bind "$ROOT" "$ROOT"
  "$BB" mount --make-rprivate "$ROOT"
fi
is_mounted "$ROOT/proc" || mount -t proc proc "$ROOT/proc"
is_mounted "$ROOT/sys" || mount -t sysfs sysfs "$ROOT/sys"
is_mounted "$ROOT/sys/fs/cgroup" || mount --bind /sys/fs/cgroup "$ROOT/sys/fs/cgroup"
is_mounted "$ROOT/sys/fs/bpf" || mount --bind /sys/fs/bpf "$ROOT/sys/fs/bpf"
is_mounted "$ROOT/dev" || mount --bind /dev "$ROOT/dev"
is_mounted "$ROOT/dev/pts" || mount -t devpts devpts "$ROOT/dev/pts"
mkdir -p /dev/shm
is_mounted "/dev/shm" || mount -t tmpfs tmpfs /dev/shm
for d in system linkerconfig; do
  if [ -d "/$d" ]; then
    mkdir -p "$ROOT/$d"
    is_mounted "$ROOT/$d" || mount --bind -o ro "/$d" "$ROOT/$d"
  fi
done
mkdir -p "$ROOT/apex" "$ROOT/.oldroot"
is_mounted "$ROOT/apex" || mount --rbind /apex "$ROOT/apex"

sysctl -w net.ipv4.ip_forward=1 >/dev/null
ip rule show | grep -q "^9000:" || ip rule add pref 9000 from all lookup main

pkill -x dockerd 2>/dev/null || true
pkill -x containerd 2>/dev/null || true
sleep 1

"$BB" setsid "$BB" unshare -m /system/bin/sh -c "
  $BB mount --make-rprivate /
  cd $ROOT
  $BB pivot_root . .oldroot
  export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
  /bin/busybox umount -l /.oldroot 2>/dev/null || true
  /bin/busybox mount --make-rprivate /
  rm -rf /var/run/docker.pid /var/run/docker.sock /run/containerd/containerd.sock
  containerd >/var/log/containerd.log 2>&1 &
  j=0
  while [ \$j -lt 10 ] && [ ! -S /run/containerd/containerd.sock ]; do
    j=\$((j+1)); sleep 1
  done
  exec dockerd --iptables=true --ip-masq=true --storage-driver=overlay2 >/var/log/dockerd.log 2>&1
" </dev/null >/data/local/tmp/docker_ns.log 2>&1 &

# Sync container outbound ip rule once wlan0/eth0 table appears (without delaying dockerd startup)
i=0
while [ $i -lt 30 ]; do
  DEFAULT_TBL=$(ip rule show | awk '/lookup (wlan0|eth0)/{print $NF; exit}')
  if [ -n "$DEFAULT_TBL" ]; then
    ip rule show | grep -q "^9500:.*lookup $DEFAULT_TBL" || {
      ip rule del pref 9500 2>/dev/null || true
      ip rule add pref 9500 from 172.16.0.0/12 lookup "$DEFAULT_TBL"
    }
    break
  fi
  i=$((i+1)); sleep 2
done
) </dev/null >/dev/null 2>&1 &
