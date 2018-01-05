#!/bin/sh
set -e

for i in FSNAME DEVICE; do
    if [ -z "$(eval "echo \"\$$i"\")" ]; then
        >&2 echo "Error: variable $i is not specified"
        exit 1
    fi
done

case "$TYPE" in
    ost )
        TYPE_CMD="--ost"
        POOL="${POOL:-$FSNAME-ost${INDEX}}"
        NAME="${NAME:-ost${INDEX}}"
    ;;
    mdt )
        TYPE_CMD="--mgt"
        POOL="${POOL:-$FSNAME-mdt${INDEX}}"
        NAME="${NAME:-mdt${INDEX}}"
    ;;
    mgs )
        TYPE_CMD="--mgs"
        POOL="${POOL:-$FSNAME-mds}"
        NAME="${NAME:-mgs}"
    ;;
    mdt+mgs|mgs+mdt )
        TYPE_CMD="--mdt --mgs"
        POOL="${POOL:-$FSNAME-mdt${INDEX}}"
        NAME="${NAME:-mdt${INDEX}}"
    ;;
    * )
        >&2 echo "Error: variable TYPE is unspecified, or specified wrong"
        >&2 echo "       TYPE=<mgs|mdt|ost|mdt+mgs>"
        exit 1
    ;;
esac

if [ "${#FSNAME}" -gt "8" ]; then
    >&2 echo "Error: variable FSNAME cannot be greater than 8 symbols"
    exit 1
fi

if [ "$TYPE" != "mgs" ] && [ -z "$INDEX" ]; then
    >&2 echo "Error: variable INDEX is not specified"
    exit 1
fi

if [ "$TYPE" != "mgs" ] && [ -z "$INDEX" ]; then
    >&2 echo "Error: variable INDEX is not specified"
    exit 1
fi

if ( [ "$TYPE" == "ost" ] || [ "$TYPE" == "mgs" ] ) && [ -z "$MGSNODE" ]; then
    >&2 echo "Error: variable MGSNODE is not specified"
    exit 1
fi

if [ "$HA_BACKEND" == "drbd" ]; then
    case "" in
        "$RESOURCE_NAME" )
            >&2 echo "Error: variable RESOURCE_NAME is not specified for HA_BACKEND=drbd"
            exit 1
        ;;
        "$SERVICENODES" )
            >&2 echo "Error: variable SERVICENODES is not specified for HA_BACKEND=drbd, example:"
            >&2 echo "       SERVICENODES=\"10.28.38.11@tcp 10.28.38.12@tcp\""
            exit 1
        ;;
    esac
fi

if [ ! -z "$CHROOT" ]; then
    DRBDADM="chroot $CHROOT drbdadm"
    WIPEFS="chroot $CHROOT wipefs"
    MODPROBE="chroot $CHROOT modprobe"
    ZPOOL="chroot $CHROOT zpool"
    MKFS_LUSTRE="chroot $CHROOT mkfs.lustre"
else
    DRBDADM="drbdadm"
    WIPEFS="wipefs"
    MODPROBE="modprobe"
    ZPOOL="zpool"
    MKFS_LUSTRE="mkfs.lustre"
fi

# Check for module
$MODPROBE lustre

# Check for drbd resource
if [ "$HA_BACKEND" == "drbd" ]; then
    $DRBDADM status "$RESOURCE_NAME"
fi

# Prepare drive
if ! $WIPEFS "$DEVICE" | grep -q "."; then
    $MKFS_LUSTRE --fsname="$FSNAME" --index="$INDEX" $TYPE_CMD --backfstype=zfs "$POOL/$NAME" "$DEVICE"
fi

# Set exit trap
if [ "$HA_BACKEND" == "drbd" ]; then
    trap "$ZPOOL export -f \"$POOL\" && $DRBDADM secondary \"$RESOURCE_NAME\" && exit 0 || exit 1" SIGINT SIGHUP SIGTERM
else
    trap "$ZPOOL export -f \"$POOL\" && exit 0 || exit 1" SIGINT SIGHUP SIGTERM
fi

# Enable drbd primary
if [ "$HA_BACKEND" == "drbd" ]; then
    $DRBDADM primary "$RESOURCE_NAME"
fi

# Start daemon
$ZPOOL import -o cachefile=none "$POOL"

# Sleep calm
tail -f /dev/null & wait $!
