# syntax=docker/dockerfile:experimental

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
    ln -sf /bin/busybox /usr/bin/env

COPY passwd group /etc/
ENV PATH=/bin:/usr/bin
WORKDIR /tmp
WORKDIR /
COPY nix.conf /etc/nix/nix.conf
