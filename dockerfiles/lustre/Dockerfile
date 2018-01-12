# docker run -v /:/host-root --net=host --privileged \
#    -e CHROOT=/host-root \
#    -e HA_BACKEND=drbd \
#    -e RESOURCE_NAME=lustre1-ost0 \
#    -e DEVICE=/dev/drbd0 \
#    -e FSNAME=lustre1 \
#    -e TYPE=ost \
#    -e INDEX=0 \
#    -e MGSNODE="10.28.38.11@tcp:10.28.38.12@tcp" \
#    -e SERVICENODE="10.28.38.13@tcp:10.28.38.14@tcp" \
#    kvaps/lustre

FROM alpine
RUN apk add --no-cache curl \
 && curl -Lo /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl \
 && chmod +x /usr/local/bin/kubectl
ADD lustre-wrapper.sh /
CMD ["/lustre-wrapper.sh"]
