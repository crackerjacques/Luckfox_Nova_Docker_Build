FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Tokyo
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

RUN apt-get update && apt-get install -y \
    git \
    ssh \
    make \
    gcc \
    libssl-dev \
    liblz4-tool \
    expect \
    expect-dev \
    g++ \
    patchelf \
    chrpath \
    gawk \
    texinfo \
    diffstat \
    binfmt-support \
    qemu-user-static \
    live-build \
    bison \
    flex \
    fakeroot \
    cmake \
    gcc-multilib \
    g++-multilib \
    unzip \
    device-tree-compiler \
    ncurses-dev \
    libncurses5-dev \
    libgucharmap-2-90-dev \
    bzip2 \
    expat \
    gpgv2 \
    cpp-aarch64-linux-gnu \
    libgmp-dev \
    libmpc-dev \
    bc \
    python-is-python3 \
    python2 \
    curl \
    sudo \
    vim \
    wget \
    tar \
    file \
    rsync \
    cpio \
    xxd \
    util-linux \
    bsdutils \
    bsdmainutils \
    libmagic1 \
    libmagic-dev \
    && rm -rf /var/lib/apt/lists/*

RUN echo '#!/bin/bash\ncommand -v "$1" 2>/dev/null' > /usr/local/bin/which && \
    chmod +x /usr/local/bin/which

# Set up Python environment (following documentation instructions ...but i dont do this...)
RUN ln -sf /usr/bin/python2 /usr/bin/python

# Create development user
RUN useradd -m -s /bin/bash nova && \
    echo "nova ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER nova
WORKDIR /home/nova

RUN mkdir -p /home/nova/nova-sdk

CMD ["/bin/bash"]