#!/usr/bin/env python3
"""Repack an Android boot.img (v2 header, e.g. Magisk-patched arm32 stock boot.img)
with a newly built LZMA-compressed sabrina kernel Image while keeping the stock
ramdisk, DTB, cmdline, and 16 MiB partition layout intact.
"""
import argparse
import os
import struct
import sys


def align(n, page_size=2048):
    return (n + page_size - 1) & ~(page_size - 1)


def repack(src_boot, kernel_lzma, out_boot):
    if not os.path.exists(src_boot):
        print(f"Error: source boot image not found: {src_boot}")
        return 1
    if not os.path.exists(kernel_lzma):
        print(f"Error: compressed kernel image not found: {kernel_lzma}")
        return 1

    with open(src_boot, 'rb') as f:
        src_data = f.read()

    hdr_fmt = '<8s8I2I16s512s32s1024sIQIIQ'
    hdr = struct.unpack_from(hdr_fmt, src_data, 0)
    (
        magic, orig_k_size, k_addr, orig_rd_size, rd_addr,
        orig_sec_size, sec_addr, tags_addr, page_size,
        header_version, os_version, name, cmdline, id_sha, extra_cmdline,
        rec_dtbo_size, rec_dtbo_offset, header_size, orig_dtb_size, dtb_addr,
    ) = hdr

    pos = page_size
    pos += align(orig_k_size, page_size)
    ramdisk_data = src_data[pos : pos + orig_rd_size]

    pos += align(orig_rd_size, page_size)
    second_data = src_data[pos : pos + orig_sec_size]

    pos += align(orig_sec_size, page_size)
    dtb_data = src_data[pos : pos + orig_dtb_size]

    with open(kernel_lzma, 'rb') as f:
        new_k_data = f.read()
    new_k_size = len(new_k_data)

    print(f"Original kernel size: {orig_k_size} bytes")
    print(f"New Docker kernel size (lzma): {new_k_size} bytes")
    print(f"Ramdisk size: {orig_rd_size} bytes")
    print(f"DTB size: {orig_dtb_size} bytes")

    new_hdr = struct.pack(
        hdr_fmt,
        magic,
        new_k_size, k_addr,
        orig_rd_size, rd_addr,
        orig_sec_size, sec_addr,
        tags_addr, page_size,
        header_version, os_version,
        name, cmdline, id_sha, extra_cmdline,
        rec_dtbo_size, rec_dtbo_offset,
        header_size,
        orig_dtb_size, dtb_addr,
    )
    new_hdr += b'\x00' * (page_size - len(new_hdr))

    new_k_padded = new_k_data + b'\x00' * (align(new_k_size, page_size) - new_k_size)
    rd_padded = ramdisk_data + b'\x00' * (align(orig_rd_size, page_size) - orig_rd_size)
    sec_padded = second_data + b'\x00' * (align(orig_sec_size, page_size) - orig_sec_size)
    dtb_padded = dtb_data + b'\x00' * (align(orig_dtb_size, page_size) - orig_dtb_size)

    total_data = new_hdr + new_k_padded + rd_padded + sec_padded + dtb_padded
    target_partition_size = 16777216  # 16 MiB sabrina boot partition
    if len(total_data) > target_partition_size:
        print(f"FATAL: total image size {len(total_data)} exceeds 16 MiB partition limit!")
        return 1

    total_data += b'\x00' * (target_partition_size - len(total_data))

    with open(out_boot, 'wb') as f:
        f.write(total_data)

    print(f"Successfully generated: {out_boot} ({len(total_data)} bytes)")
    return 0


def main():
    p = argparse.ArgumentParser(description="Repack sabrina boot.img with Image_docker.lzma")
    p.add_argument("--boot", default="magisk_arm32_boot.img", help="Base boot.img (stock or Magisk arm32 patched)")
    p.add_argument("--kernel", default="out/Image_docker.lzma", help="LZMA-compressed kernel Image")
    p.add_argument("--out", default="out/sabrina_docker_magisk_boot.img", help="Output boot image path")
    args = p.parse_args()
    return repack(args.boot, args.kernel, args.out)


if __name__ == '__main__':
    sys.exit(main())
