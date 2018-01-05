# docker run -e CHROOT=/host-root -v /:/host-root kvaps/lustre-install

FROM alpine
ADD install-lustre.sh /
ENTRYPOINT /install-lustre.sh
