#!/bin/sh
set -e

# if chroot is set, use yum and rpm from chroot
if [ ! -z "$CHROOT" ]; then
    alias rpm="chroot $CHROOT rpm"
    alias yum="chroot $CHROOT yum"
fi

# check for distro
if ! grep -q 'VERSION_ID="7"' "$CHROOT/etc/os-release"; then
    >&2 echo "Error: Host system not supported"
    exit 1
fi

rpm -q --quiet epel-release || yum -y install epel-release
rpm -q --quiet zfs-release || yum -y install --nogpgcheck http://download.zfsonlinux.org/epel/zfs-release.el7.noarch.rpm

case "$MODE" in
    kmod) sed -e 's/^enabled=.\?/enabled=0/' -e '/\[zfs-kmod\]/,/^\[.*\]$/ s/^enabled=.\?/enabled=1/' -i /etc/yum.repos.d/zfs.repo ;;
    kmod-testing) sed -e 's/^enabled=.\?/enabled=0/' -e '/\[zfs-testing-kmod\]/,/^\[.*\]$/ s/^enabled=.\?/enabled=1/' -i /etc/yum.repos.d/zfs.repo && MODE=kmod ;;
    dkms) sed -e 's/^enabled=.\?/enabled=0/' -e '/\[zfs\]/,/^\[.*\]$/ s/^enabled=.\?/enabled=1/' -i /etc/yum.repos.d/zfs.repo ;;
    dkms-testing) sed -e 's/^enabled=.\?/enabled=0/' -e '/\[zfs-testing\]/,/^\[.*\]$/ s/^enabled=.\?/enabled=1/' -i /etc/yum.repos.d/zfs.repo && MODE=dkms ;;
    *) 
        >&2 echo "Error: Please specify MODE variable"
        >&2 echo "       MODE=<dkms|kmod|dkms-testing|kmod-testing>"
        exit 1
    ;;
esac

if [ "$MODE" == "kmod" ]; then
    # enable kmod / disable dkms
    (rpm -q --quiet zfs-dkms || rpm -q --quiet spl-dkms) && yum remove -y zfs-dkms spl-dkms
    rpm -q --quiet zfs kmod-zfs || yum install -y zfs kmod-zfs
elif [ "$MODE" == "dkms" ]; then
    # enable dkms / disable kmod
    (rpm -q --quiet kmod-zfs || rpm -q --quiet kmod-spl) && yum remove -y kmod-zfs kmod-spl
    rpm -q --quiet zfs zfs-dkms || yum install -y zfs zfs-dkms
    if [ ! -f "/lib/modules/$(uname -r)/build" ]; then
        if ! yum install "kernel-devel-uname-r == $(uname -r)"; then
            >&2 echo "Error: Can not found kernel-headers for current kernel"
            >&2 echo "       try to ugrade kernel then reboot your system"
            >&2 echo "       or install kernel-headers package manually"
            exit 1
        fi
    fi

    SPL_VERSION="$(dkms status | awk -F'[ :]' '$1 == "spl," {print $2}')"
    ZFS_VERSION="$(dkms status | awk -F'[ :]' '$1 == "zfs," {print $2}')"

    # build dkms module
    if ! (dkms install "spl/$ZFS_VERSION" && dkms install "zfs/$ZFS_VERSION"); then
         >&2 echo "Error: Can not build zfs dkms module"
         exit 1
    fi
fi

# check for module
if ! (find "/lib/modules/$(uname -r)" -name zfs.ko | grep -q "."); then
     >&2 echo "Error: Can not found zfs module for current kernel"
     exit 1
fi
