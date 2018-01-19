resource ${RESOURCE_NAME} {
    protocol ${PROTOCOL};
    net {
        after-sb-0pri discard-least-changes;
        after-sb-1pri call-pri-lost-after-sb;
        after-sb-2pri call-pri-lost-after-sb;
    }
    on ${NODE1_NAME}
    {
        device ${DEVICE};
        disk ${NODE1_DISK};
        address ${NODE1_IP}:${NODE1_PORT};
        meta-disk ${NODE1_METADISK};
    }
    on ${NODE2_NAME}
    {
        device ${DEVICE};
        disk ${NODE2_DISK};
        address ${NODE2_IP}:${NODE2_PORT};
        meta-disk ${NODE2_METADISK};
    }
}
