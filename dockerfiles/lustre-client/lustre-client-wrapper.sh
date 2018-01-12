#!/bin/sh
[ "$DEBUG" == "1" ] && set -x
set -e

for i in FSNAME MGSNODE MOUNTPOINT; do
    if [ -z "$(eval "echo \"\$$i"\")" ]; then
        >&2 echo "Error: variable $i is not specified"
        exit 1
    fi
done

if [ "${#FSNAME}" -gt "8" ]; then
    >&2 echo "Error: variable FSNAME cannot be greater than 8 symbols, example:"
    >&2 echo "       FSNAME=lustre1"
    exit 1
fi

if [ ! -z "$CHROOT" ]; then
    MODPROBE="chroot $CHROOT modprobe"
    SYSTEMCTL="chroot $CHROOT systemctl"
else
    MODPROBE="modprobe"
    SYSTEMCTL="systemctl"
fi

# Check for module
$MODPROBE lustre

# Create mount target
MOUNT_TARGET="$MOUNTPOINT"
SYSTEMD_UNIT="$(echo $MOUNT_TARGET | sed -e 's/-/\\x2d/g' -e 's/\//-/g' -e 's/^-//').mount"
SYSTEMD_UNIT_FILE="$CHROOT/run/systemd/system/$SYSTEMD_UNIT"

cleanup() {
    set +e

    # kill tail process if exist
    kill $TAILF_PID 2>/dev/null
    # kill mount process if exist
    kill -SIGINT $MOUNT_PID 2>/dev/null && wait $MOUNT_PID

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

    exit 0
}

# Set exit trap
trap cleanup SIGINT SIGHUP SIGTERM EXIT

# Write unit
cat > "$SYSTEMD_UNIT_FILE" <<EOT
[Mount]
What=$MGSNODE:/$FSNAME
Where=$MOUNT_TARGET
Type=lustre
EOT

# Start daemon
$SYSTEMCTL daemon-reload
if ! $SYSTEMCTL start "$SYSTEMD_UNIT"; then
    # print error
    $SYSTEMCTL status "$SYSTEMD_UNIT"
    exit 1
fi &

MOUNT_PID=$!
wait $MOUNT_PID

# Sleep calm
tail -f /dev/null &
TAILF_PID=$!
wait $TAILF_PID
