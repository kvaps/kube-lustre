#!/bin/sh

load_variables() {
    NODE1_NAME="$(jq -r ".$CONFIGURATION[\"$DAEMON\"][0]" "$DAEMONS_FILE")"
    NODE2_NAME="$(jq -r ".$CONFIGURATION[\"$DAEMON\"][1]" "$DAEMONS_FILE")"
    NODE3_NAME="$(jq -r ".$CONFIGURATION[\"$DAEMON\"][2]" "$DAEMONS_FILE")"
    NODE1_IP="$(getent ahosts "$NODE1_NAME" | grep -v -m1 ':' | awk '{print $1}')"
    NODE2_IP="$(getent ahosts "$NODE2_NAME" | grep -v -m1 ':' | awk '{print $1}')"
    LUSTRE="$(jq -r ".$CONFIGURATION | keys | contains([\"lustre\"])" "$CONFIGURATIONS_FILE")"
    LUSTRE_FSNAME="$(jq -r ".$CONFIGURATION.lustre.fsname" "$CONFIGURATIONS_FILE")"
    LUSTRE_INSTALL="$(jq -r ".$CONFIGURATION.lustre.install" "$CONFIGURATIONS_FILE")"
    LUSTRE_MGSNODE="$(jq -r ".$CONFIGURATION.lustre.mgsnode" "$CONFIGURATIONS_FILE")"
    LUSTRE_DEVICE="$(jq -r ".$CONFIGURATION.lustre.device" "$CONFIGURATIONS_FILE")"
    DRBD="$(jq -r ".$CONFIGURATION | keys | contains([\"drbd\"])" "$CONFIGURATIONS_FILE")"
    DRBD_INSTALL="$(jq -r ".$CONFIGURATION.drbd.install" "$CONFIGURATIONS_FILE")"
    DRBD_DEVICE="$(jq -r ".$CONFIGURATION.drbd.device" "$CONFIGURATIONS_FILE")"
    DRBD_NODE1_PORT="$(jq -r ".$CONFIGURATION.drbd.port[0]" "$CONFIGURATIONS_FILE")"
    DRBD_NODE1_PORT="$(jq -r ".$CONFIGURATION.drbd.port[1]" "$CONFIGURATIONS_FILE")"
    DRBD_NODE1_DISK="$(jq -r ".$CONFIGURATION.drbd.disks[0]" "$CONFIGURATIONS_FILE")"
    DRBD_NODE2_DISK="$(jq -r ".$CONFIGURATION.drbd.disks[1]" "$CONFIGURATIONS_FILE")"
    NODE_LABEL="$LUSTRE_FSNAME/$DAEMON="
    APP_NAME="$LUSTRE_FSNAME-$DAEMON"
}

CONFIGURATIONS_FILE="configuration.json"
DAEMONS_FILE="daemons.json"
CONFIGURATIONS="$(jq -r '. | keys[]' "$DAEMONS_FILE")"

if [ -f "$CONFIGURATIONS_FILE" ]; then
    >&2 echo "Error: Configurations file not found: $CONFIGURATIONS_FILE"
    exit 1
fi

if [ -f "$DAEMONS_FILE" ]; then
    >&2 echo "Error: Daemons file not found: $DAEMONS_FILE"
    exit 1
fi

# Checking configuration
for CONFIGURATION in $CONFIGURATIONS; do
    DAEMONS="$(jq -r ".$CONFIGURATION | keys[]" "$DAEMONS_FILE")"
    for DAEMON in $DAEMONS; do

        load_variables

        if [ "$LUSTRE" == "false" ]; then
            >&2 echo "Error: Lustre configuration $CONFIGURATION not found for $DAEMON"
            exit 1
        fi

        if [ "$DRBD" == "true" ] && [ "$NODE3_NAME" != "null"]; then
            >&2 echo "Error: Only two nodes alowed for drbd configuration for $DAEMON"
            exit 1
        elif [ "$DRBD" == "false" ] && [ "$NODE2_NAME" != "null"]; then
            >&2 echo "Error: Only one node alowed for configuration without drbd for $DAEMON"
            exit 1
        fi

        for i in NODE1_NAME NODE1_IP LUSTRE_FSNAME LUSTRE_INSTALL LUSTRE_MGSNODE LUSTRE_DEVICE; do
            if [ "$(eval "echo \"\$$i"\")" == "null" ]; then
                >&2 echo "Error: variable $i is not specified for $DAEMON"
                exit 1
            fi
        done

        if [ "$DRBD" == "true" ]; then
            for i in NODE2_NAME NODE2_IP DRBD_INSTALL DRBD_DEVICE DRBD_NODE1_PORT DRBD_NODE1_PORT DRBD_NODE2_PORT DRBD_NODE1_DISK DRBD_NODE2_DISK; do
                if [ "$(eval "echo \"\$$i"\")" == "null" ]; then
                    >&2 echo "Error: variable $i is not specified for $DAEMON"
                    exit 1
                fi
            done
        fi

        NODES_BY_LABEL="$(kubectl get nodes -l "$NODE_LABEL" -o json | jq -r '.items[].metadata.name')"
        WRONG_NODES="$(echo "$NODES_BY_LABEL" | grep -v "^\(${NODE1}\|${NODE2}\)$")"
        if [ -z "$WRONG_NODES" ]; then
            >&2 echo "Error: Wrong nodes nodes found with label $NODE_LABEL:"
            >&2 echo "     " $WRONG_NODES
            exit 1
        fi

    done
done

# Run configuration
for CONFIGURATION in $CONFIGURATIONS; do
    DAEMONS="$(jq -r ".$CONFIGURATION | keys[]" "$DAEMONS_FILE")"
    for DAEMON in $DAEMONS; do

        load_variables

        # label nodes
        kubectl label node --overwrite "$NODE1" "$NODE_LABEL"
        kubectl label node --overwrite "$NODE2" "$NODE_LABEL"

        # apply drbd resources
        if [ "$DRBD" == "true" ] && [ "$DRBD_INSTALL" == "true" ]; then
            eval "echo \"$(cat drbd.yaml)\"" | kubectl apply -f -
        elif [ "$DRBD" == "true" ] && [ "$DRBD_INSTALL" == "false" ]; then
            eval "echo \"$(cat drbd.yaml)\"" | sed -z 's/initContainers.*containers:/containers:/' | kubectl apply -f -
        fi

        # apply lustre resources
        if [ "$LUSTRE_INSTALL" == "true" ]; then
            eval "echo \"$(cat lustre.yaml)\"" | kubectl apply -f -
        elif [ "$LUSTRE_INSTALL" == "false" ]; then
            eval "echo \"$(cat lustre.yaml)\"" | sed -z 's/initContainers.*containers:/containers:/' | kubectl apply -f -
        fi

    done
done
