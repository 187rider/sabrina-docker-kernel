FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/usr/lib/llvm-17/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
RUN apt-get update && apt-get install -y --no-install-recommends \
    clang-17 lld-17 llvm-17 lldb-17 \
    make bc bison flex libssl-dev libelf-dev dwarves \
    kmod e2fsprogs cpio lz4 xz-utils python3 git ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && for t in clang clang++ ld.lld llvm-ar llvm-nm llvm-objcopy llvm-objdump llvm-readelf llvm-strip llvm-addr2line; do \
         ln -sf "/usr/bin/${t}-17" "/usr/local/bin/${t}"; \
       done
WORKDIR /work
