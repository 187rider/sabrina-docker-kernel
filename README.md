# Sabrina Docker Kernel (`5.15.220-android14-sabrina-docker+`)

Custom Linux `5.15.220` kernel, build system, ABI compatibility patches, and Android runtime scripts for **Chromecast with Google TV 4K (`sabrina` / Amlogic S905D3 / SM1)** on **Android 14** (`UTTC.250917.004`).

Brings full **Docker / containerd / runc** support, **WireGuard**, **TCP BBR**, **in-kernel NTFS3 / CIFS / exFAT**, **USB UASP (`USB_UAS`)**, and **`1.5 GiB` `lz4` ZRAM** tuning while maintaining **100% symbol CRC and struct ABI compatibility** with stock vendor `.ko` modules and hardware H.264/HEVC video decoding/encoding.

---

## Verified Target & Build Info

- **Device:** Google Chromecast with Google TV 4K (`sabrina`, Amlogic S905D3 / SM1)
- **OS / Userland:** Stock Android 14 (`32-bit` `armeabi-v7a` userspace on `64-bit` `aarch64` kernel)
- **Kernel Version:** `5.15.220-android14-sabrina-docker+ #13 SMP PREEMPT` (Clang 17.0.6 + LLD 17.0.6)
- **Vendor Module ABI Check:** `1636` / `1636` expected vmlinux symbols matched (**`0` mismatched, `0` missing**)
- **Base Upstream Trees:**
  - `LineageOS/android_kernel_amlogic_kernel-5.15` @ `1c244a9cff6384fb1eddc1a9554fcf116ad9367d`
  - `LineageOS/android_kernel_amlogic_common_drivers` @ `11f9da28a599bb93fee1bd6ef493a161deaf75de`

---

## Enabled Kernel Features

### Containers & Docker
- **Namespaces:** `CONFIG_NAMESPACES`, `CONFIG_PID_NS`, `CONFIG_NET_NS`, `CONFIG_IPC_NS`, `CONFIG_UTS_NS`, `CONFIG_USER_NS`
- **Cgroups:** `CONFIG_CGROUPS`, `CONFIG_MEMCG`, `CONFIG_MEMCG_SWAP`, `CONFIG_BLK_CGROUP`, `CONFIG_CFS_BANDWIDTH`, `CONFIG_CGROUP_PIDS`, `CONFIG_CGROUP_DEVICE`, `CONFIG_CPUSETS`, `CONFIG_CGROUP_FREEZER`, `CONFIG_CGROUP_NET_CLASSID`
- **IPC & Storage:** `CONFIG_SYSVIPC`, `CONFIG_POSIX_MQUEUE`, `CONFIG_OVERLAY_FS`, `CONFIG_BLK_DEV_LOOP`
- **Networking / Netfilter:** `CONFIG_VETH`, `CONFIG_BRIDGE`, `CONFIG_BRIDGE_NETFILTER`, `CONFIG_IP_NF_IPTABLES`, `CONFIG_IP_NF_NAT`, `CONFIG_IP_NF_TARGET_MASQUERADE`, `CONFIG_NETFILTER_XT_MATCH_ADDRTYPE`, `CONFIG_NETFILTER_XT_MATCH_CONNTRACK`, `CONFIG_NET_CLS_ACT`

> **Note on Android Cgroups & `iptables`:**
> - Android mounts `blkio`, `cpu`, `cpuset`, and `memory` as cgroup v1 under `/dev/*` while `/sys/fs/cgroup` runs cgroup v2 (`pids`). Docker containers run via cgroup v2 `cgroupfs`, leaving Android's native `lmkd`/cgroup layout untouched (note `--memory`/`--cpus` cgroup throttling is not active under this hybrid layout).
> - `CONFIG_NF_TABLES` is disabled; Docker works natively using Android's legacy `iptables` (`xtables`) with `/sys/fs/bpf` bind-mounted into the Alpine rootfs (required for Android `netd` `xt_bpf` rules).

### Networking, Filesystems & Hardware
- **Networking / VPN:** `CONFIG_WIREGUARD=y`, `CONFIG_TUN=y`, `CONFIG_TCP_CONG_BBR=y`, `CONFIG_DEFAULT_BBR=y` (`bbr`), `CONFIG_NET_SCH_FQ=y`, `CONFIG_NET_SCH_FQ_CODEL=y`
- **Filesystems:** `CONFIG_NTFS3_FS=y` (`NTFS3_64BIT_CLUSTER`, `NTFS3_LZX_XPRESS`), `CONFIG_CIFS=y` (`CIFS_XATTR`, `CIFS_POSIX`), `CONFIG_EXFAT_FS=y`, `CONFIG_FUSE_FS=y`
- **USB & Hardware:** `CONFIG_USB_DWC3=y`, `CONFIG_USB_XHCI_HCD=y`, `CONFIG_USB_STORAGE=y`, `CONFIG_USB_UAS=y`, `CONFIG_AMLOGIC_PWM*`, `CONFIG_AMLOGIC_MESON_SARADC`, `CONFIG_AMLOGIC_ADC_KEYPADS`
- **Media:** Hardware H.264 / HEVC decode (`ammvdec_h264_v4l`, `vdec_hevc`) and H.264 encode verified working with stock `/vendor/lib/modules/*.ko` and `/dev/amvideo`. (S905D3 silicon has no hardware AV1 block.)

---

## Key Kernel Patches Explained

### 1. Core Kernel ABI & SYSVIPC (`patches/aml_kernel.patch`)
- **`include/linux/sched.h` (`KABI`-safe `SYSVIPC`):** Enables `CONFIG_SYSVIPC` (`sysvsem`, `sysvshm`) inside existing `ANDROID_KABI_RESERVE(2..4)` slots in `struct task_struct` instead of growing or shifting struct offsets used by prebuilt vendor modules.
- **`include/linux/fs.h` & `include/linux/mount.h`:** Restores `alloc_mnt_data` in `struct file_system_type` and `void *data` in `struct vfsmount` to match stock Android VFS / `sdcardfs` expectations.
- **`scripts/genksyms/genksyms.c` (`GENKSYMS_STOCK_SYMVERS`):** Adds an optional lookup against `configs/stock_symvers.txt` during symbol CRC calculation so exported kernel symbols stay compatible with stock `/vendor/lib/modules/*.ko` (`0` mismatched / `0` missing out of `1636`).
- **`fs/cifs/*` & `fs/ntfs3/super.c`:** Adds `MODULE_IMPORT_NS(VFS_internal_I_am_really_a_filesystem_and_am_NOT_a_driver)` and fixes `fs/cifs/trace.h` `TRACE_INCLUDE_PATH` for out-of-tree/modular builds.

### 2. Amlogic SM1 Clocks, DRM Hotplug & Decoder Struct Alignment (`patches/common_drivers.patch`)
- **`include/dt-bindings/clock/amlogic,g12a-clkc.h` (Critical Video Fix):** Inserts `CLKID_GEN_CLK_SEL` (`263`), `CLKID_GEN_CLK_DIV` (`264`), and `CLKID_GEN_CLK` (`265`) and shifts `MEDIA_BASE` from `(263 + 1)` to `(265 + 1)`. This aligns all SM1 media clock IDs (`266..357`) with `sabrina`'s stock DTB so `hevc_mux`, `hevcf_mux`, `vdec_hevc`, and `vdec_hevcf` bind to the right hardware clock controllers without register hangs/watchdog resets during hardware video playback.
- **`drivers/drm/meson_drv.c` (HDMI Hotplug & Cold-Boot Recovery Fix):** Marks encoders sharing `possible_crtcs` symmetrically clone-compatible (`possible_clones |= drm_encoder_mask(enc_b)`) before `drm_mode_config_reset()`. Upstream `5.15` LTS added `drm_atomic_check_valid_clones()`, which otherwise rejects Amlogic `MesonHwc` multi-encoder states (`HDMI-A-1` + `MESON-DUMMYL`, or `TV-1` `576cvbs` -> `HDMI-A-1`) with `-EINVAL` (`-22`) on hot-unplug/replug or cold-boot recovery.
- **`drivers/media/cec/hdmi_ao_cec.c` (HDMI-CEC RX Uevent Fix):** Restores `queue_delayed_work(cec_dev->cec_rx_event_wq, &cec_dev->work_cec_rx, ...)` in `cec_new_msg_push()` and `cec_stored_msg_push()` (reverted upstream by `fffc03ada226`). Sabrina's stock Android 14 `/vendor/lib/libhdmi_cec.so` (`HdmiCecBusMonitor`) waits for `cec_rx_msg=1` uevents before calling `read(/dev/cec)`.
- **`drivers/debug/sched.c`:** Uses `android_oem_data1[0..4]` instead of `android_kabi_reserved*`.
- **`drivers/media/*` & Amlogic media headers (`dmabuf_manage`, `meson_uvm_core`, `vframe.h`, `video_composer`, `video_sink`, `vpp`):** Aligns `uvm_alloc->sgt`, `dmabuf_manage_block`, and `vframe_s` layouts with `sabrina`'s stock vendor video decoder/pipeline modules.

---

## Repository Layout

```text
.
├── Dockerfile                         # Ubuntu 24.04 + LLVM/Clang 17 cross-build image
├── configs/
│   ├── stock.config                   # Extracted stock sabrina 5.15 kernel config
│   ├── stock_symvers.txt              # Stock vmlinux symbol CRCs
│   ├── all_vendor_symvers.txt         # All symbols imported by stock vendor .ko modules
│   └── vendor_symvers.txt             # Vendor module symbol baseline
├── patches/
│   ├── aml_kernel.patch               # Kernel ABI, SYSVIPC, genksyms, CIFS/NTFS3 patches
│   └── common_drivers.patch           # SM1 clock ID fix + Amlogic media/sched ABI alignment
├── scripts/
│   ├── setup_sources.sh               # Clones exact LineageOS 5.15 bases & applies patches
│   ├── build_sabrina_docker_kernel.sh # Configures, builds Image, verifies 100% CRC match
│   ├── repack_magisk_boot.py          # Packs Image_docker.lzma into 16 MiB Magisk boot.img
│   ├── prep_cfg.sh                    # Minimal config helper
│   ├── build_modules.sh               # Optional standalone module build helper
│   └── build_cifs.sh                  # Optional standalone cifs/dns_resolver build helper
└── android/                           # On-device Alpine Docker, ZRAM, and governor scripts
    └── data/
        ├── local/bin/{enter-alpine,docker}
        └── adb/service.d/{dockerd.sh,cpu_perf.sh,zram_tune.sh}
```

---

## How to Build From Source

```bash
# 1. Build the Docker toolchain container
docker build -t sabrina-kbuild .

# 2. Clone pinned kernel trees, apply patches, build Image_docker.lzma, and verify CRCs
docker run --rm -v "$(pwd)":/repo -v sabrina_work:/work -w /repo sabrina-kbuild bash -c '
  bash scripts/setup_sources.sh /work/ksrc
  REPO_DIR=/repo KSRC_DIR=/work/ksrc OUT=/work/out_docker bash scripts/build_sabrina_docker_kernel.sh
'
```

Outputs are generated in `out/Image_docker` and `out/Image_docker.lzma`.

---

## Repacking & Flashing `boot.img`

You need a `magisk_arm32_boot.img` created from `sabrina`'s stock `boot.img` using **32-bit (`armeabi-v7a`) Magisk** (`PREINITDEVICE=metadata`).

```bash
# 1. Repack your Magisk arm32 boot image with the compiled kernel
python3 scripts/repack_magisk_boot.py \
  --boot magisk_arm32_boot.img \
  --kernel out/Image_docker.lzma \
  --out out/sabrina_docker_magisk_boot.img

# 2. Flash via userspace fastbootd (recommended on macOS/Linux)
adb reboot fastboot
fastboot getvar is-userspace   # expect: yes
fastboot flash boot out/sabrina_docker_magisk_boot.img
fastboot reboot
```

*(Never flash via standard U-Boot fastboot if your host USB stack stalls bulk transfers — use `adb reboot fastboot`.)*

---

## Running Docker on `sabrina` (Alpine Chroot + `pivot_root`)

1. Set up an `armv7` Alpine rootfs in `/data/local/alpine` and install:
   ```sh
   apk add --no-cache docker iptables-legacy
   ```
2. Inside `/data/local/alpine/sbin/`, point `iptables*` and `ip6tables*` symlinks to `/system/bin/iptables` (so `dockerd` uses Android's native `xtables-legacy` binary that understands `xt_bpf` pinned rules in `/sys/fs/bpf`).
3. Copy `android/data/local/bin/*` to `/data/local/bin/` (`0755`) and `android/data/adb/service.d/*.sh` to `/data/adb/service.d/` (`0755`).
4. Optionally symlink `/data/local/bin/docker` into `/data/adb/openssh/bin/` or a Magisk `/system/xbin` module to make `docker` directly available in SSH shells.

`dockerd.sh` uses `busybox setsid` + `unshare -m` + `pivot_root` so container `runc` `pivot_root` and `overlay2` layer extraction work cleanly, sets `net.ipv4.ip_forward=1`, and adds Android policy routing rules (`pref 9000` -> `main`, `pref 9500` -> `wlan0`/`eth0`) so containers have full internet/DNS access.

---

## Prebuilt Images & Checksums (`v5.15.220-sabrina-docker+ #13`)

Prebuilt binaries are attached to the [GitHub Release (`v5.15.220-sabrina-docker-r13`)](https://github.com/187rider/sabrina-docker-kernel/releases/tag/v5.15.220-sabrina-docker-r13):

| File | Description | SHA-256 |
| --- | --- | --- |
| `sabrina_docker_magisk_boot.img` | **Custom** `#13` Docker kernel (`Image_docker.lzma`) + 32-bit Magisk ramdisk (`16 MiB`) | `76203629cd01228d41a5175cca1bcca9acaceb34ba11129f6f0eb2ab4ffb1c75` |
| `stock_boot.img` | Unpatched **stock** `UTTC.250917.004` `boot.img` (`16 MiB`) | `c4cb0f2e405227e058d367b4ced20fa49fdc0cc89686c0c8dff5b6e3fa115934` |
| `stock_magisk_arm32_boot.img` | Stock kernel + 32-bit Magisk ramdisk (`16 MiB`, base used for repacking) | `56db95c2076583e9c7d81e052cda0d27f71c017ac10e8054e59a828e64f102dd` |
| `Image_docker.lzma` | Compressed custom kernel image (`8.9 MiB`) | `c977c7666074cbe8dc7992028b0baa4667dd880b1fecf7c1e006a3ed717bd022` |
| `Image_docker` | Uncompressed custom kernel `Image` (build output) | `14ca37f1c711c2f9ba28bd3876829e6213b62d5624d28357a772922d880d00d1` |

## License

Linux kernel patches follow upstream **GPL-2.0**. Helper scripts and Android runtime configurations are provided as-is.
