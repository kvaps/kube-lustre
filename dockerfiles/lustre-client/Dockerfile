# docker run -v /:/host-root --net=host --privileged \
#    -e CHROOT=/host-root \
#    -e FSNAME=lustre1 \
#    -e MGSNODE="10.28.38.11@tcp:10.28.38.12@tcp" \
#    -e MOUNTPOINT=/stor/lustre1 \
#    kvaps/lustre

FROM alpine
ADD lustre-client-wrapper.sh /
CMD ["/lustre-client-wrapper.sh"]
