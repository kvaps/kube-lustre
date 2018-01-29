#!/bin/sh
[ "$DEBUG" == "1" ] && set -x
set -e

CONFIG_DIR="${CONFIG_DIR:-/etc/kube-lustre}"
CONFIGURATIONS_FILE="$CONFIG_DIR/configuration.json"
DAEMONS_FILE="$CONFIG_DIR/daemons.json"
CLIENTS_FILE="$CONFIG_DIR/clients.json"

load_variables() {
    NODE1_NAME="$(jq -r ".$CONFIGURATION[\"$DAEMON\"][0]" "$DAEMONS_FILE")"
    NODE2_NAME="$(jq -r ".$CONFIGURATION[\"$DAEMON\"][1]" "$DAEMONS_FILE")"
    NODE3_NAME="$(jq -r ".$CONFIGURATION[\"$DAEMON\"][2]" "$DAEMONS_FILE")"
    NODE1_IP="$(getent ahosts "$NODE1_NAME" | grep -v -m1 ':' | awk '{print $1}')"
    NODE2_IP="$(getent ahosts "$NODE2_NAME" | grep -v -m1 ':' | awk '{print $1}')"
    LUSTRE="$(jq -r ".$CONFIGURATION | keys | contains([\"lustre\"])" "$CONFIGURATIONS_FILE")"
    LUSTRE_FSNAME="$(jq -r ".$CONFIGURATION.lustre.fsname" "$CONFIGURATIONS_FILE")"
    LUSTRE_DEBUG="$(jq -r ".$CONFIGURATION.lustre.debug" "$CONFIGURATIONS_FILE")"
    LUSTRE_INSTALL="$(jq -r ".$CONFIGURATION.lustre.install" "$CONFIGURATIONS_FILE")"
    LUSTRE_FORCE_CREATE="$(jq -r ".$CONFIGURATION.lustre.force_create" "$CONFIGURATIONS_FILE")"
    LUSTRE_MGSNODE="$(jq -r ".$CONFIGURATION.lustre.mgsnode" "$CONFIGURATIONS_FILE")"
    LUSTRE_DEVICE="$(jq -r ".$CONFIGURATION.lustre.device" "$CONFIGURATIONS_FILE")"
    LUSTRE_MOUNTPOINT="$(jq -r ".$CONFIGURATION.lustre.mountpoint" "$CONFIGURATIONS_FILE")"
    DRBD="$(jq -r ".$CONFIGURATION | keys | contains([\"drbd\"])" "$CONFIGURATIONS_FILE")"
    DRBD_DEBUG="$(jq -r ".$CONFIGURATION.drbd.debug" "$CONFIGURATIONS_FILE")"
    DRBD_INSTALL="$(jq -r ".$CONFIGURATION.drbd.install" "$CONFIGURATIONS_FILE")"
    DRBD_FORCE_CREATE="$(jq -r ".$CONFIGURATION.drbd.force_create" "$CONFIGURATIONS_FILE")"
    DRBD_DEVICE="$(jq -r ".$CONFIGURATION.drbd.device" "$CONFIGURATIONS_FILE")"
    DRBD_PORT="$(jq -r ".$CONFIGURATION.drbd.port" "$CONFIGURATIONS_FILE")"
    DRBD_SYNCER_RATE="$(jq -r ".$CONFIGURATION.drbd.syncer_rate" "$CONFIGURATIONS_FILE")"
    DRBD_PROTOCOL="$(jq -r ".$CONFIGURATION.drbd.protocol" "$CONFIGURATIONS_FILE")"
    DRBD_NODE1_DISK="$(jq -r ".$CONFIGURATION.drbd.disks[0]" "$CONFIGURATIONS_FILE")"
    DRBD_NODE2_DISK="$(jq -r ".$CONFIGURATION.drbd.disks[1]" "$CONFIGURATIONS_FILE")"
    NODE_LABEL="$LUSTRE_FSNAME/$DAEMON"
    APP_NAME="$LUSTRE_FSNAME-$DAEMON"
    LUSTRE_TYPE="$(echo "$DAEMON" | sed 's/[0-9]//g')"
    LUSTRE_INDEX="$(echo "$DAEMON" | sed 's/[^0-9]//g')"

    if [ "$DRBD" == "true" ]; then
        LUSTRE_HA_BACKEND="drbd"
        LUSTRE_SERVICENODE="${NODE1_NAME}:${NODE2_NAME}"
    fi

    [ "$LUSTRE_DEBUG" == "true" ] && LUSTRE_DEBUG="1" || LUSTRE_DEBUG="0"
    [ "$DRBD_DEBUG"   == "true" ] && DRBD_DEBUG="1"   || DRBD_DEBUG="0"
    [ "$LUSTRE_FORCE_CREATE" == "true" ] && LUSTRE_FORCE_CREATE="1" || LUSTRE_FORCE_CREATE="0"
    [ "$DRBD_FORCE_CREATE"   == "true" ] && DRBD_FORCE_CREATE="1"   || DRBD_FORCE_CREATE="0"
}

echo "Parsing $CONFIGURATIONS_FILE"
jq . "$CONFIGURATIONS_FILE"

if [ "$CONFIGURE_SERVERS" == "1" ]; then
    echo "Parsing $DAEMONS_FILE"
    jq . "$DAEMONS_FILE"
fi
if [ "$CONFIGURE_CLIENTS" == "1" ]; then
    echo "Parsing $CLIENTS_FILE"
    jq . "$CLIENTS_FILE"
fi

# Check kubectl
kubectl get nodes 1> /dev/null

CONFIGURATIONS="$(jq -r '. | keys[]' "$DAEMONS_FILE")"

# Checking configuration
for CONFIGURATION in $CONFIGURATIONS; do

    [ "$CONFIGURE_SERVERS" == "1" ] && DAEMONS="$(jq -r ".$CONFIGURATION | keys[]" "$DAEMONS_FILE")"
    [ "$CONFIGURE_CLIENTS" == "1" ] && CLIENTS="$(jq -r ".$CONFIGURATION | keys[]" "$CLIENTS_FILE")"

    for DAEMON in $DAEMONS; do

        load_variables

        if [ "$LUSTRE" == "false" ]; then
            >&2 echo "Error: Lustre configuration $CONFIGURATION not found for DAEMON=$DAEMON"
            exit 1
        fi

        if [ "$DRBD" == "true" ] && [ "$NODE3_NAME" != "null" ]; then
            >&2 echo "Error: Only two nodes alowed for drbd configuration for DAEMON=$DAEMON"
            exit 1
        elif [ "$DRBD" == "false" ] && [ "$NODE2_NAME" != "null" ]; then
            >&2 echo "Error: Only one node alowed for configuration without drbd for DAEMON=$DAEMON"
            exit 1
        fi

        for i in NODE1_NAME NODE1_IP LUSTRE_FSNAME LUSTRE_INSTALL LUSTRE_MGSNODE LUSTRE_DEVICE LUSTRE_TYPE LUSTRE_INDEX; do
            if [ -z "$(eval "echo \"\$$i"\")" ] || [ "$(eval "echo \"\$$i"\")" == "null" ]; then
                >&2 echo "Error: variable $i is not specified for DAEMON=$DAEMON"
                exit 1
            fi
        done

        if [ "$DRBD" == "true" ]; then
            for i in NODE2_NAME NODE2_IP DRBD_INSTALL DRBD_DEVICE DRBD_PORT  DRBD_NODE1_DISK DRBD_NODE2_DISK; do
                if [ -z "$(eval "echo \"\$$i"\")" ] || [ "$(eval "echo \"\$$i"\")" == "null" ]; then
                    >&2 echo "Error: variable $i is not specified for DAEMON=$DAEMON"
                    exit 1
                fi
            done
        fi

        case "$LUSTRE_TYPE" in
            ost ) : ;;
            mdt ) : ;;
            mgs ) : ;;
            mdt-mgs ) : ;;
            * )
                >&2 echo "Error: variable LUSTRE_TYPE is specified wrong for DAEMON=$DAEMON"
                >&2 echo "       LUSTRE_TYPE=<mgs|mdt|ost|mdt-mgs>"
                exit 1
            ;;
        esac

        if [ "${#LUSTRE_FSNAME}" -gt "8" ]; then
            >&2 echo "Error: variable FSNAME cannot be greater than 8 symbols for DAEMON=$DAEMON, example:"
            >&2 echo "       LUSTRE_FSNAME=lustre1"
            exit 1
        fi

        NODES_BY_LABEL="$(kubectl get nodes -l "$NODE_LABEL=" -o json 2>/dev/null | jq -r '.items[].metadata.name' )"
        if [ "$DRBD" == "true" ]; then
            WRONG_NODES="$(echo "$NODES_BY_LABEL" | grep -v "^\(${NODE1_NAME}\|${NODE2_NAME}\)$" || true)"
        else
            WRONG_NODES="$(echo "$NODES_BY_LABEL" | grep -v "^${NODE1_NAME}$" || true)"
        fi

        if [ ! -z "$WRONG_NODES" ]; then
            >&2 echo "Error: Wrong nodes nodes was found with label $NODE_LABEL:"
            >&2 echo "     " $WRONG_NODES
            exit 1
        fi

    done

    for CLIENT in $CLIENTS; do

        load_variables

        if [ "$LUSTRE" == "false" ]; then
            >&2 echo "Error: Lustre configuration $CONFIGURATION not found for CLIENT=$CLIENT"
            exit 1
        fi

        for i in LUSTRE_MOUNTPOINT LUSTRE_FSNAME LUSTRE_INSTALL LUSTRE_MGSNODE; do
            if [ -z "$(eval "echo \"\$$i"\")" ] || [ "$(eval "echo \"\$$i"\")" == "null" ]; then
                >&2 echo "Error: variable $i is not specified for CLIENT=$CLIENT"
                exit 1
            fi
        done

    done

done

# Run configuration
for CONFIGURATION in $CONFIGURATIONS; do

    [ "$CONFIGURE_SERVERS" == "1" ] && DAEMONS="$(jq -r ".$CONFIGURATION | keys[]" "$DAEMONS_FILE")"

    for DAEMON in $DAEMONS; do

        load_variables

        # label nodes
        kubectl label node --overwrite "$NODE1_NAME" "$NODE_LABEL="
        kubectl label node --overwrite "$NODE1_NAME" "$LUSTRE_FSNAME/server="
        if [ "$DRBD" == "true" ]; then
            kubectl label node --overwrite "$NODE2_NAME" "$NODE_LABEL="
            kubectl label node --overwrite "$NODE2_NAME" "$LUSTRE_FSNAME/server="
        fi

        # apply drbd resources
        if [ "$DRBD" == "true" ]; then
            [ "$DRBD_SYNCER_RATE" == "null" ] && DRBD_SYNCER_RATE="5M"
            [ "$DRBD_PROTOCOL" == "null" ] && DRBD_PROTOCOL="C"

            if [ "$DRBD_INSTALL" == "true" ]; then
                eval "echo \"$(cat drbd.yaml | sed 's/"/\\"/g' )\"" | kubectl apply -f -
            else
                eval "echo \"$(cat drbd.yaml | sed 's/"/\\"/g' )\"" | sed '/^ *initContainers: *$/,/^ *containers: *$/{/^ *containers: *$/!d}' | kubectl apply -f -
            fi
        fi

        # apply lustre resources
        if [ "$LUSTRE_INSTALL" == "true" ]; then
            eval "echo \"$(cat lustre.yaml | sed 's/"/\\"/g' )\"" | kubectl apply -f -
        elif [ "$LUSTRE_INSTALL" == "false" ]; then
            eval "echo \"$(cat lustre.yaml | sed 's/"/\\"/g' )\"" | sed '/^ *initContainers: *$/,/^ *containers: *$/{/^ *containers: *$/!d}' | kubectl apply -f -
        fi

    done


    if [ "$CONFIGURE_CLIENTS" == "1" ]; then
        CLIENTS="$(jq -r ".$CONFIGURATION[]" "$CLIENTS_FILE")"

        load_variables

        for CLIENT in $CLIENTS; do
            # label nodes
            kubectl label node --overwrite "$CLIENT" "$LUSTRE_FSNAME/client="
        done

        # apply lustre client
        if [ "$LUSTRE_INSTALL" == "true" ]; then
            eval "echo \"$(cat lustre-client.yaml | sed 's/"/\\"/g' )\"" | kubectl apply -f -
        elif [ "$LUSTRE_INSTALL" == "false" ]; then
            eval "echo \"$(cat lustre-client.yaml | sed 's/"/\\"/g' )\"" | sed '/^ *initContainers: *$/,/^ *containers: *$/{/^ *containers: *$/!d}' | kubectl apply -f -
        fi
    fi

done
