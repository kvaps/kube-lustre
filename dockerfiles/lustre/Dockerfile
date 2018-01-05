# docker run -v /:/host-root --net=host --privileged \
#    -e CHROOT=/host-root \
#    -e HA_BACKEND=drbd \
#    -e RESOURCE_NAME=lustre1-mdt0 \
#    -e DEVICE=/dev/drbd0 \
#    -e FSNAME=lustre1 \
#    -e SERVICENODES=\"10.28.38.11@tcp 10.28.38.12@tcp\""
#    kvaps/lustre

FROM alpine
ADD lustre-wrapper.sh /
CMD ["/lustre-wrapper.sh"]
