#!/bin/sh
set -e

# default parameters
SOURCES_DIR="${SOURCES_DIR:-$CHROOT/usr/src/kube-lustre}"
[ -z "$KERNEL_VERSION" ] && KERNEL_VERSION="$(uname -r)"

cleanup_wrong_versions() {
    WRONG_PACKAGES="$(rpm -qa lustre-server kmod-lustre kmod-lustre-osd-ldiskfs kmod-lustre-osd-zfs kmod-lustre-tests lustre lustre-debuginfo lustre-dkms \
        lustre-iokit lustre-osd-ldiskfs-mount lustre-osd-zfs-mount lustre-resource-agents lustre-tests | grep -v "$1" | xargs)"
    [ -z "$WRONG_PACKAGES" ] || yum -y remove $WRONG_PACKAGES
}

install_lustre_repo() {
    if [ -z "$1" ]; then
        RELEASE="latest-release"
    else
        RELEASE="lustre-$1"
    fi

    cat > "$CHROOT/etc/yum.repos.d/lustre.repo" <<EOF
[lustre-server]
name=lustre-server
baseurl=https://downloads.hpdd.intel.com/public/lustre/$RELEASE/el7/server
# exclude=*debuginfo*
gpgcheck=0

[lustre-client]
name=lustre-client
baseurl=https://downloads.hpdd.intel.com/public/lustre/$RELEASE/el7/client
# exclude=*debuginfo*
gpgcheck=0

[e2fsprogs-wc]
name=e2fsprogs-wc
baseurl=https://downloads.hpdd.intel.com/public/e2fsprogs/latest/el7
# exclude=*debuginfo*
gpgcheck=0
EOF

}

# if chroot is set, use yum and rpm from chroot
if [ ! -z "$CHROOT" ]; then
    alias rpm="chroot $CHROOT rpm"
    alias yum="chroot $CHROOT yum"
    alias dkms="chroot $CHROOT dkms"
fi

# check for distro
if [ "$(sed 's/.*release\ //' "$CHROOT/etc/redhat-release" | cut -d. -f1)" != "7" ]; then
    >&2 echo "Error: Host system not supported"
    exit 1
fi

# check for mode
if [ "$MODE" != "from-source" ] && [ "$MODE" != "from-repo" ]; then
    >&2 echo "Error: Please specify MODE variable"
    >&2 echo "       MODE=<from-repo|from-source>"
    exit 1
fi

# check for type
if [ "$TYPE" != "kmod" ] && [ "$TYPE" != "dkms" ]; then
    >&2 echo "Error: Please specify TYPE variable"
    >&2 echo "       TYPE=<dkms|kmod>"
    exit 1
fi

# install repositories
rpm -q --quiet epel-release || yum -y install epel-release
install_lustre_repo "$VERSION"

# check for module
if ! (find "$CHROOT/lib/modules/$KERNEL_VERSION" -name lustre.ko | grep -q "."); then
    FORCE_REINSTALL=1
fi

# check for source repository
if [ -z "$FORCE_REINSTALL" ]; then
    case "$MODE" in
        from-repo   ) yum list installed lustre | tail -n 1 | grep -q '@lustre-server$' || FORCE_REINSTALL=1 ;;
        from-source ) yum list installed lustre | tail -n 1 | grep -q '@lustre-server$' && FORCE_REINSTALL=1 ;;
    esac
fi

# get installed version
INSTALLED_VERSION="$(rpm -qa lustre | awk -F- '{print $2}')"
VERSION="${VERSION:-$INSTALLED_VERSION}"

# get latest version
if [ -z "$VERSION" ] || [ "$AUTO_UPDATE" == "1" ] || [ "$FORCE_REINSTALL" == "1" ]; then
    LATEST_VERSION="$(yum list available lustre --showduplicates | tail -n 1 | awk '{print $2}' | cut -d- -f1)"
    VERSION="$LATEST_VERSION"
fi


# check for needed packages and version
if [ -z "$FORCE_REINSTALL" ]; then
    case "$TYPE" in
        kmod ) [ "$(rpm -qa lustre kmod-lustre | grep -c "$VERSION")" == "2" ] || FORCE_REINSTALL=1 ;;
        dkms ) [ "$(rpm -qa lustre lustre-dkms | grep -c "$VERSION")" == "2" ] || FORCE_REINSTALL=1 ;;
    esac
fi


# install kernel-headers
if ! ( [ "$MODE" == "from-repo" ] && [ "$TYPE" == "kmod" ] ) && [ ! -d "$CHROOT/lib/modules/$KERNEL_VERSION/build" ]; then
    if ! yum -y install "kernel-devel-uname-r == $KERNEL_VERSION"; then
        >&2 echo "Error: Can not found kernel-headers for current kernel"
        >&2 echo "       try to ugrade kernel then reboot your system"
        >&2 echo "       or install kernel-headers package manually"
        exit 1
    fi
fi


# install packages
if [ "$MODE" == "from-repo" ]; then

    if [ "$FORCE_REINSTALL" != "1" ]; then
        echo "Info: Needed packages already installed"
    else
        if ! echo "$KERNEL_VERSION" | grep -q lustre; then
            >&2 echo "Error: Your current booted kernel have no lustre patches"
            >&2 echo "       Can not continue installing lustre from packages"
            exit 1
        fi
        case "$TYPE" in
            kmod )
                cleanup_wrong_versions "$VERSION"
                yum install -y lustre kmod-lustre
            ;;
            dkms )
                cleanup_wrong_versions "$VERSION"
                yum install -y lustre lustre-dkms
            ;;
        esac
    fi

elif [ "$MODE" == "from-source" ]; then

    if [ "$FORCE_REINSTALL" != "1" ]; then
        echo "Info: Needed packages already installed and have version $VERSION"
    else
        yum -y groupinstall 'Development Tools'
        yum -y install git xmlto asciidoc elfutils-libelf-devel zlib-devel kernel-devel libyaml-devel \
            binutils-devel newt-devel python-devel hmaccalc perl-ExtUtils-Embed \
            bison elfutils-devel  audit-libs-devel python-docutils sg3_utils expect \
            attr lsof quilt libselinux-devel

        mkdir -p "$SOURCES_DIR"

        if [ ! -d "$SOURCES_DIR/lustre-$VERSION" ]; then
            pushd "$SOURCES_DIR"
            curl "https://downloads.hpdd.intel.com/public/lustre/lustre-$VERSION/el7/server/SRPMS/lustre-$VERSION-1.src.rpm" | rpm2cpio | cpio -idmuv "lustre-$VERSION.tar.gz"
            tar -xzf "lustre-$VERSION.tar.gz"
            rm -f "lustre-$VERSION.tar.gz"
            popd
        fi

        # Build and install lustre packages
        pushd "$SOURCES_DIR/lustre-$VERSION"
        ./configure --disable-ldiskfs
        rm -f *.rpm
        make rpms
        cleanup_wrong_versions "$VERSION"
        yum localinstall -y $(ls -1 *.rpm | grep -v debuginfo | grep -v 'src\.rpm' | sed -e "s|^|$SOURCES_DIR/lustre-$VERSION/|" -e "s|^$CHROOT||" )
        popd

    fi

fi

# build dkms module
if [ "$TYPE" == "dkms" ]; then
    VERSION="$(rpm -qa zfs-dkms | awk -F- '{print $3}')"
    if ! (dkms install "spl/$VERSION" && dkms install "zfs/$VERSION"); then
         >&2 echo "Error: Can not build zfs dkms module"
         exit 1
    fi
fi

# final check for module
if ! (find "$CHROOT/lib/modules/$KERNEL_VERSION" -name zfs.ko | grep -q "."); then
     >&2 echo "Error: Can not found installed zfs module for current kernel"
     exit 1
fi

echo "Success"
