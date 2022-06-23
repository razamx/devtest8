#!/bin/bash
# FROM ubuntu:20.04

# LABEL TCC_BASE_PUBLIC="0.8"

# Make sure we are being passed a build folder.
if [ -z "$1" ] ; then
    echo "ERROR: \$1 argument required." ;
    echo "       \$1 specifies the local build directory." ;
    exit 1 ;
fi

dirBuildSource=$(readlink -e "$1")

if [ ! -e "$dirBuildSource" ] || [ ! -d "$dirBuildSource" ] ; then
    echo "ERROR: \$1 argument ($1) is not a directory or does not exist." ;
    echo "       \$1 specifies the local build directory." ;
    exit 1 ;
fi

dirBuildRoot=${dirBuildSource}
echo "INFO: Root build folder is: \"$dirBuildRoot\""


# Configure env vars needed to prep build environment.
export http_proxy=http://proxy-dmz.intel.com:911
export https_proxy=http://proxy-dmz.intel.com:912
export no_proxy=127.0.0.1,localhost,.intel.com
#export DEBIAN_FRONTEND=noninteractive
#export TZ=Europe/Moscow

#echo 'Acquire::http::Proxy "http://proxy-chain.intel.com:911/";' \
#    >> /etc/apt/apt.conf.d/00aptitude

# Downloading necessary packages
(
    apt-get update && \
    apt-get -y upgrade && \
    apt-get install -y \
    apt-utils \
    autoconf \
    automake \
    bandit \
    checkinstall \
    clang-tidy-8 \
    cmake \
    connect-proxy \
    csh \
    curl \
    dblatex \
    debhelper \
    debmake \
    default-jre \
    dmidecode \
    docbook-utils \
    dos2unix \
    doxygen \
    expect \
    g++-9 \
    g++-9-multilib \
    gcc-9 \
    gcovr \
    gettext \
    git \
    git-lfs \
    graphviz \
    jq \
    clang-format-8 \
    libglib2.0-dev \
    libjson-c-dev \
    libncurses5-dev \
    libncursesw5-dev \
    libtool \
    make \
    mc \
    nano \
    net-tools \
    p7zip-full \
    patchutils \
    pkg-config \
    python-is-python3 \
    python3-pip \
    python3.8 \
    ssh \
    sshpass \
    sudo \
    tar \
    vim \
    wget \
    xmlto \
    xsltproc \
    xutils-dev
)


# Updating git-lfs
(
    curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash
)
(
    apt update
)
(
    apt install -y git-lfs
)

# Install XDP support libs
(
    apt-get update && \
    apt-get install -y \
    python3-sphinx \
    pkg-config \
    libelf-dev
)


# Set required Python modules
(
echo '\n\
lz4\n\
transitions >= 0.8.1, == 0.8.*\n\
matplotlib >= 3.1.2, == 3.1.*\n\
numpy\n\
cryptography\n\
click\n\
xmlrunner\n\
unittest-xml-reporting\n\
robotframework\n\
robotframework-sshlibrary\n\
flake8\n\
junit2html\n\
bandit\n\
coverage\n'\
>> python_prereqs.txt
)

# Installing required Python modules
(
    pip3 install -r python_prereqs.txt
)


# Install ittnotify
(
    git clone -b v3.18.10 https://github.com/intel/ittapi
)
(
    cd ittapi && python3 buildall.py
)
(
    cd ittapi && \
    cp build_linux/64/bin/libittnotify.a /usr/lib && \
    cp -r include /usr/include/ittnotify && \
    cp src/ittnotify/*.h /usr/include/ittnotify/ && \
    rm -rf /usr/include/ittnotify/fortran/win32 && \
    rm -rf /usr/include/ittnotify/fortran/posix/x86
)

# Install EDKII dependencies
(
    apt-get update && \
    apt-get install -y uuid-dev \
    iasl \
    nasm
)

# Download open62541 and libbpf patches
(
    git clone https://github.com/intel/iotg-yocto-ese-main.git && \
    cd iotg-yocto-ese-main && \
    git checkout 56aceb22632b9451c991529889f8c90def22153e
)

export OPEN62541_PATCHES_PATH=${dirBuildRoot}/iotg-yocto-ese-main/recipes-connectivity/open62541/open62541-iotg/
export LIBBPF_PATCHES_PATH=${dirBuildRoot}/iotg-yocto-ese-main/backports/dunfell/recipes-connectivity/libbpf/libbpf

# Cloning of libbpf
(
    git clone https://github.com/libbpf/libbpf.git && \
    cd libbpf && \
    git checkout ab067ed3710550c6d1b127aac6437f96f8f99447
)

# Patching libbpf
(
    cd libbpf && \
    git apply ${LIBBPF_PATCHES_PATH}/0001-libbpf-add-txtime-field-in-xdp_desc-struct.patch  && \
    git apply ${LIBBPF_PATCHES_PATH}/0002-makefile-don-t-preserve-ownership-when-installing-fr.patch  && \
    git apply ${LIBBPF_PATCHES_PATH}/0003-makefile-remove-check-for-reallocarray.patch
)

# Building libbpf
(
    cd libbpf/src && \
    make
)

# Installing libbpf
(
    cd libbpf/src && \
    checkinstall -D --pkgname=libbpf -y
)
(
    cd libbpf/src && \
    make install_uapi_headers
)
(
    cp libbpf/include/uapi/linux/*.h /usr/include/linux/
)

# Cloning of open62541
(
    git clone https://github.com/open62541/open62541.git && \
    cd open62541 && \
    git checkout a77b20ff940115266200d31d30d3290d6f2d57bd
)

# Patching open62541
(
    cd open62541 && \
    git apply ${OPEN62541_PATCHES_PATH}/0001-CMakeLists.txt-Mark-as-IOTG-fork.patch && \
    git apply ${OPEN62541_PATCHES_PATH}/0001-fix-PubSub-Enable-dynamic-compilation-of-pubsub-exam.patch && \
    git apply ${OPEN62541_PATCHES_PATH}/0002-feature-PubSub-Use-libbpf-for-AF_XDP-receive-update-.patch && \
    git apply ${OPEN62541_PATCHES_PATH}/0003-feature-PubSub-add-support-for-AF_XDP-transmission.patch && \
    git apply ${OPEN62541_PATCHES_PATH}/0004-fix-PubSub-XDP-dynamic-compilation.patch && \
    git apply ${OPEN62541_PATCHES_PATH}/0005-fix-PubSub-update-example-to-set-XDP-queue-flags.patch && \
    git apply ${OPEN62541_PATCHES_PATH}/0006-test-PubSub-Configuration-used-for-compile-test.patch && \
    git apply ${OPEN62541_PATCHES_PATH}/0007-feature-PubSub-Add-ETF-LaunchTime-support-for-XDP-tr.patch && \
    git apply ${OPEN62541_PATCHES_PATH}/0008-fix-PubSub-AF_XDP-RX-release-mechanism-AF_PACKET-com.patch && \
    git apply ${OPEN62541_PATCHES_PATH}/0009-fix-PubSub-Fix-ETF-XDP-plugin-buffer-overflow.patch && \
    git apply ${OPEN62541_PATCHES_PATH}/0010-fix-PubSub-xdp-socket-cleanup-routine.patch && \
    git apply ${OPEN62541_PATCHES_PATH}/0011-fix-PubSub-fix-null-checking-possible-memleak-klocwo.patch && \
    git apply ${OPEN62541_PATCHES_PATH}/0012-fix-PubSub-remove-hardcoded-etf-layer-receive-timeou.patch
)

# Building of open6254
(
    cd open62541 && \
    mkdir build && \
    cd build && \
    cmake -DUA_ENABLE_PUBSUB=ON -DUA_ENABLE_PUBSUB_ETH_UADP=ON -DUA_ENABLE_PUBSUB_ETH_UADP_ETF=ON -DUA_ENABLE_PUBSUB_ETH_UADP_XDP=ON -DUA_ENABLE_SUBSCRIPTIONS=ON -DUA_ENABLE_PUBSUB_SOCKET_PRIORITY=ON -DUA_ENABLE_PUBSUB_CUSTOM_PUBLISH_HANDLING=ON -DUA_ENABLE_PUBSUB_SOTXTIME=ON -DUA_ENABLE_SCHEDULED_SERVER=ON -DUA_BUILD_EXAMPLES=OFF -DUA_ENABLE_AMALGAMATION=OFF -DBUILD_SHARED_LIBS=ON -DCMAKE_INSTALL_PREFIX=/usr/ ..
)

# Installation of open62541
(
    cd open62541/build && \
    checkinstall -D --pkgname=open62541-iotg -y
)

# # Clean apt
# (
#     rm -rf /var/lib/apt/lists/*
# )

# # Set default user
# (
#     useradd -m tcc && \
#     usermod -aG sudo tcc && \
#     chown -R tcc /opt
# )
# (
#     echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
# )
# USER tcc

#ENTRYPOINT ["/bin/bash", "-c"]
# ENTRYPOINT ["/bin/bash"]
