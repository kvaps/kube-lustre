#!/bin/sh
[ "$DEBUG" == "1" ] && set -x
set -e

for i in FSNAME DEVICE; do
    if [ -z "$(eval "echo \"\$$i"\")" ]; then
        >&2 echo "Error: variable $i is not specified"
        exit 1
    fi
done

MOUNT_DIR=${MOUNT_DIR:-/var/lib/lustre}
[ "$FORCE_CREATE" == "1" ] && FORCE_CREATE_CMD="--force"

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
        POOL="${POOL:-$FSNAME-mdt${INDEX}-mgs}"
        NAME="${NAME:-mdt${INDEX}-mgs}"
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
    SYSTEMCTL="chroot $CHROOT systemctl"
    MKFS_LUSTRE="chroot $CHROOT mkfs.lustre"
else
    DRBDADM="drbdadm"
    WIPEFS="wipefs"
    MODPROBE="modprobe"
    ZPOOL="zpool"
    SYSTEMCTL="systemctl"
    MKFS_LUSTRE="mkfs.lustre"
fi

# Check for module
$MODPROBE zfs
$MODPROBE lustre

# Check for drbd resource
if [ "$HA_BACKEND" == "drbd" ]; then
    $DRBDADM status "$RESOURCE_NAME" 1>/dev/null
fi

# Create mount target
MOUNT_TARGET="$MOUNT_DIR/$POOL/$NAME"
SYSTEMD_UNIT="$(echo $MOUNT_TARGET | sed -e 's/-/\\x2d/g' -e 's/\//-/g' -e 's/^-//').mount"
SYSTEMD_UNIT_FILE="$CHROOT/run/systemd/system/$SYSTEMD_UNIT"

cleanup() {
    set +e

    # kill tail process if exist
    kill $TAILF_PID 2>/dev/null
    # kill mount process if exist
    kill -SIGINT $MOUNT_PID 2>/dev/null && wait $MOUNT_PID
    # kill zpool process if exist
    kill -SIGINT $ZPOOL_PID 2>/dev/null && wait $ZPOOL_PID

    # umount lustre target if mounted
    if $SYSTEMCTL is-active "$SYSTEMD_UNIT"; then
        $SYSTEMCTL stop "$SYSTEMD_UNIT"
    fi

    rm -f "$SYSTEMD_UNIT_FILE"

    # export zpool if imported
    if $ZPOOL list "$POOL" &>/dev/null; then
        $ZPOOL export -f "$POOL"
    fi

    # mark secondary if drbd backend
    [ "$HA_BACKEND" == "drbd" ] && $DRBDADM secondary "$RESOURCE_NAME"

    rmdir "$MOUNT_TARGET" 2>/dev/null

    # kill the pod for not wait when Terminating are finished
    [ "$KUBE_NOTIFY" == "1" ] && kubectl delete pod "$RESOURCE_NAME-0" --force --grace-period=0

    exit 0
}

# Set exit trap
trap cleanup SIGINT SIGHUP SIGTERM EXIT

# Enable drbd primary
if [ "$HA_BACKEND" == "drbd" ]; then
    $DRBDADM primary "$RESOURCE_NAME"
fi

if ! $WIPEFS "$DEVICE" | grep -q "."; then
    # Prepare drive
    $MKFS_LUSTRE $FSNAME_CMD $FORCE_CREATE_CMD $MGSNODE_CMD $SERVICENODE_CMD $INDEX_CMD $TYPE_CMD --backfstype=zfs --force-nohostid "$POOL/$NAME" "$DEVICE"
else
    # Import zfs-pool
    if ! $ZPOOL list | grep -q "^$POOL "; then
        $ZPOOL import -o cachefile=none "$POOL" &
        ZPOOL_PID=$!
        wait $ZPOOL_PID
    fi
fi

# Write unit
cat > "$SYSTEMD_UNIT_FILE" <<EOT
[Mount]
What=$POOL/$NAME
Where=$MOUNT_TARGET
Type=lustre
EOT

# Start daemon
$SYSTEMCTL daemon-reload
if ! $SYSTEMCTL start "$SYSTEMD_UNIT"; then
    # print error
    $SYSTEMCTL status "$SYSTEMD_UNIT" | grep 'mount\[' | sed 's/^.*\]: //g' >&2
    exit 1
fi &

MOUNT_PID=$!
wait $MOUNT_PID

# Sleep calm
tail -f /dev/null &
TAILF_PID=$!
wait $TAILF_PID
