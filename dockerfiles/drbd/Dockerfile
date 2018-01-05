# docker run -v /:/host-root --net=host --privileged \
#    -e CHROOT=/host-root \
#    -e RESOURCE_NAME=lustre1-mdt0 \
#    -e DEVICE=/dev/drbd0 \
#    -e NODE1_NAME=m1c1 \
#    -e NODE1_DISK=/dev/vdb \
#    -e NODE1_IP=10.28.38.11 \
#    -e NODE1_PORT=7788 \
#    -e NODE2_NAME=m1c2 \
#    -e NODE2_DISK=/dev/vdb \
#    -e NODE2_IP=10.28.38.12 \
#    -e NODE2_PORT=7788 \
#    kvaps/drbd

FROM alpine
ADD drbd-wrapper.sh template.res /
CMD ["/drbd-wrapper.sh"]
