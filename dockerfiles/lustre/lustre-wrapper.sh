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
    mdt-mgs )
        TYPE_CMD="--mdt --mgs"
        POOL="${POOL:-$FSNAME-mdt${INDEX}}"
        NAME="${NAME:-mdt${INDEX}}"
    ;;
    * )
        >&2 echo "Error: variable TYPE is unspecified, or specified wrong"
        >&2 echo "       TYPE=<mgs|mdt|ost|mdt-mgs>"
        exit 1
    ;;
esac

if [ "${#FSNAME}" -gt "8" ]; then
    >&2 echo "Error: variable FSNAME cannot be greater than 8 symbols, example:"
    >&2 echo "       FSNAME=lustre1"
    exit 1
else
    FSNAME_CMD="--fsname=$FSNAME"
fi

if [ "$TYPE" != "mgs" ]; then
    if [ -z "$INDEX" ]; then
        >&2 echo "Error: variable INDEX is not specified, example:"
        >&2 echo "       INDEX=1"
        exit 1
    else
        INDEX_CMD="--index=$INDEX"
    fi
fi

if ( [ "$TYPE" == "ost" ] || [ "$TYPE" == "mgs" ] ); then
    if [ -z "$MGSNODE" ]; then
        >&2 echo "Error: variable MGSNODE is not specified, example:"
        >&2 echo "       MGSNODE=\"10.28.38.11@tcp,10.28.38.12@tcp\""
        exit 1
    else
        MGSNODE_CMD="--mgsnode=$MGSNODE"
    fi
fi

if [ "$HA_BACKEND" == "drbd" ]; then
    case "" in
        "$RESOURCE_NAME" )
            >&2 echo "Error: variable RESOURCE_NAME is not specified for HA_BACKEND=drbd"
            exit 1
        ;;
        "$SERVICENODE" )
            >&2 echo "Error: variable SERVICENODE is not specified for HA_BACKEND=drbd, example:"
            >&2 echo "       SERVICENODE=\"10.28.38.13@tcp,10.28.38.14@tcp\""
            exit 1
        ;;
    esac
    SERVICENODE_CMD="--servicenode=$SERVICENODE"
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
$MODPROBE zfs
$MODPROBE lustre

# Check for drbd resource
if [ "$HA_BACKEND" == "drbd" ]; then
    $DRBDADM status "$RESOURCE_NAME"
fi

# Set exit trap
if [ "$HA_BACKEND" == "drbd" ]; then
    trap "($ZPOOL export -f \"$POOL\"; $DRBDADM secondary \"$RESOURCE_NAME\") && exit 0 || exit 1" SIGINT SIGHUP SIGTERM EXIT
else
    trap "$ZPOOL export -f \"$POOL\" && exit 0 || exit 1" SIGINT SIGHUP SIGTERM EXIT
fi

# Enable drbd primary
if [ "$HA_BACKEND" == "drbd" ]; then
    $DRBDADM primary "$RESOURCE_NAME"
fi

if ! $WIPEFS "$DEVICE" | grep -q "."; then
    # Prepare drive
    $MKFS_LUSTRE $FSNAME_CMD $MGSNODE_CMD $SERVICENODE_CMD $INDEX_CMD $TYPE_CMD --backfstype=zfs --force-nohostid "$POOL/$NAME" "$DEVICE"
else
    # Start daemon
    $ZPOOL import -o cachefile=none "$POOL"
fi

# Sleep calm
tail -f /dev/null & wait $!
