#!/bin/sh
set -e

PROTOCOL=${PROTOCOL:-C}
SYNCER_RATE=${SYNCER_RATE:-5M}
NODE1_METADISK=${NODE1_METADISK:-internal}
NODE2_METADISK=${NODE1_METADISK:-internal}
CREATION_TIMEOUT=${CREATION_TIMEOUT:-120}

for i in RESOURCE_NAME DEVICE NODE1_DISK NODE1_IP NODE1_PORT DEVICE NODE2_DISK NODE2_IP NODE2_PORT NODE1_NAME NODE2_NAME; do
    if [ -z "$(eval "echo \"\$$i"\")" ]; then
        >&2 echo "Error: variable $i is not specified"
        exit 1
    fi
done

case "$HOSTNAME" in
    $NODE1_NAME ) NODE_DISK="$NODE1_DISK" ;;
    $NODE2_NAME ) NODE_DISK="$NODE2_DISK" ;;
    * )
        >&2 echo "Error: $HOSTNAME is not match $NODE1_NAME or $NODE2_NAME"
        exit 1
    ;;
esac

if [ ! -z "$CHROOT" ]; then
    DRBDADM="chroot $CHROOT drbdadm"
    WIPEFS="chroot $CHROOT wipefs"
    MODPROBE="chroot $CHROOT modprobe"
else
    DRBDADM="drbdadm"
    WIPEFS="wipefs"
    MODPROBE="modprobe"
fi

# Check for module
$MODPROBE drbd

# Stopping resource if it is already exists
if $DRBDADM status lustre1-mdt0 &>/dev/null; then
    $DRBDADM down "$RESOURCE_NAME"
fi

# Write config
rm -f "$CHROOT/etc/drbd.d/$RESOURCE_NAME.res"
eval "echo \"$(cat template.res)\"" > "$CHROOT/tmp/$RESOURCE_NAME.res"
$DRBDADM sh-nop -t "/tmp/$RESOURCE_NAME.res"
mv "$CHROOT/tmp/$RESOURCE_NAME.res" "$CHROOT/etc/drbd.d/$RESOURCE_NAME.res"

# Prepare drive
if ! $WIPEFS "$NODE_DISK" | grep -q "."; then
    $DRBDADM create-md "$RESOURCE_NAME" &&
    case "$HOSTNAME" in
        $NODE1_NAME )
            JUST_CREATED="$(echo yes | nc -w "$CREATION_TIMEOUT" -n -l -p "$NODE1_PORT" )"
        ;;
        $NODE2_NAME )
            JUST_CREATED="$(
                until echo 'yes' | nc "$NODE1_NAME" "$NODE1_PORT"; do
                    [ "$((CREATION_TIMEOUT--))" -gt 0 ] && sleep 1 || exit 0;
                done
            )"
        ;;
    esac
fi

# Set exit trap
trap "rm -f \"$CHROOT/etc/drbd.d/$RESOURCE_NAME.res\"; $DRBDADM down \"$RESOURCE_NAME\" && exit 0 || exit 1" SIGINT SIGHUP SIGTERM

# Start daemon
$DRBDADM up "$RESOURCE_NAME"

# Define master for first time
sleep 5
if [ "$JUST_CREATED" == "yes" ] && [ "$HOSTNAME" == "$NODE1_NAME" ] &&
   [ "$($DRBDADM status "$RESOURCE_NAME" | grep -c '\( disk:Inconsistent\| role:Secondary\| replication:Established\| peer-disk:Inconsistent\)')" == "4" ]
then
    $DRBDADM primary --force "$RESOURCE_NAME"
    sleep 1
    $DRBDADM secondary "$RESOURCE_NAME"
fi

# Sleep calm
tail -f /dev/null & wait $!
