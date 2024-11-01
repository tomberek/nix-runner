# syntax=docker/dockerfile:1.2

FROM scratch
COPY nix /bin/nix
COPY busybox /bin/busybox
COPY busybox /bin/sh
COPY busybox /usr/bin/env
COPY ca-bundle.crt /etc/ssl/certs/ca-bundle.crt
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt
RUN /bin/busybox ln -sf /bin/busybox /bin/ln
RUN ln -sf /bin/busybox /bin/sh && \
    ln -sf /bin/busybox /bin/sed && \
    ln -sf /bin/busybox /bin/tr && \
    ln -sf /bin/busybox /bin/date && \
    ln -sf /bin/busybox /bin/head && \
    ln -sf /bin/busybox /bin/tar && \
    ln -sf /bin/busybox /bin/hexdump && \
    ln -sf /bin/busybox /bin/mkdir && \
    ln -sf /bin/busybox /bin/rm && \
    ln -sf /bin/busybox /bin/uname && \
    ln -sf /bin/busybox /bin/chmod && \
    ln -sf /bin/busybox /bin/ls && \
    ln -sf /bin/busybox /bin/cat && \
    ln -sf /bin/busybox /bin/xargs && \
    ln -sf /bin/busybox /bin/mkfifo && \
    ln -sf /bin/busybox /bin/echo && \
    ln -sf /bin/busybox /bin/sleep && \
    ln -sf /bin/busybox /bin/seq && \
    ln -sf /bin/busybox /bin/cp && \
    ln -sf /bin/busybox /bin/id && \
    ln -sf /bin/busybox /bin/mount && \
    ln -sf /bin/busybox /usr/bin/env && \
    ln -sf /bin/busybox /usr/bin/tail

COPY passwd group os-release /etc/
COPY nix.conf /etc/nix/
ENV PATH=/root/.nix-profile/bin:/bin:/usr/bin:/root/.nix-profile/bin
WORKDIR /tmp
WORKDIR /

ENV NIX="exec nix --option use-sqlite-wal false -j auto --substituters https://cache.nixos.org?trusted=1"
RUN $NIX registry pin nixpkgs && nix store gc
# RUN $NIX shell nixpkgs#coreutils --command echo cached
# RUN $NIX shell nixpkgs#bashInteractive --command echo cached
# RUN mkdir -p -m 0700 ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts
RUN $NIX profile install nixpkgs#stdenv.cc.cc nixpkgs#bashInteractive
RUN sh -c 'mkdir -p /lib64 && ln -s /nix/store/*glibc*/lib/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2'
RUN sh -c 'echo export LD_LIBRARY_PATH=$(echo /nix/store/*-gcc-*-lib/lib):$(echo /nix/store/*-glibc-2*/lib) >> /etc/profile'
RUN cp /etc/profile /root/.bashrc
ENV ENV=/etc/profile

CMD ["/bin/sh"]
