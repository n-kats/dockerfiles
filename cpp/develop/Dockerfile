FROM ubuntu:16.04

RUN set -x \
  && apt-get update \
  && apt-get install -y \
    make \
    cmake \
    gcc \
    g++ \
    python \
    libtool \
    zlib1g \
    zlib1g-dev \
    subversion \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /
RUN mkdir llvm \
  && cd /llvm \
  && svn co http://llvm.org/svn/llvm-project/llvm/trunk llvm \
  && cd /llvm/llvm/tools \
  && svn co http://llvm.org/svn/llvm-project/cfe/trunk clang \
  && cd /llvm/llvm/tools/clang/tools \
  && svn co http://llvm.org/svn/llvm-project/clang-tools-extra/trunk extra \
  && cd /llvm/llvm/projects \
  && svn co http://llvm.org/svn/llvm-project/compiler-rt/trunk compiler-rt \
  && cd /llvm \
  && mkdir build \
  && cd build \
  && cmake -G "Unix Makefiles" ../llvm/ -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Release \
  &&  make -j$(grep processor /proc/cpuinfo | wc -l) REQUIRES_RTTI=1 \
  &&  make install \
  &&  cd / \
  &&  rm -rf llvm

#RUN set -x \
#  && apt-get update \
#  && apt-get install -y \
#    git \
#  && apt-get clean \
#  && rm -rf /var/lib/apt/lists/*
#
#WORKDIR /
#RUN set -x \
#  && mkdir llvm_plugin \
#  && cd llvm_plugin \
#  && git clone --depth 1 git://sourceware.org/git/binutils-gdb.git binutils \
#  && mkdir build \
#  && cd build \
#  && ../binutils/configure --enable-gold --enable-plugins --disable-werror
##&& make all-gold


# opecv
RUN set -x \
  && apt-get update \
  && apt-get install -y \
    libopencv-dev \
    build-essential \
    cmake \
    git \
    libgtk2.0-dev \
    pkg-config \
    python-dev \
    python-numpy \
    libdc1394-22 \
    libdc1394-22-dev \
    libjpeg-dev \
    libpng12-dev \
    libtiff5-dev \
    libjasper-dev \
    libavcodec-dev \
    libavformat-dev \
    libswscale-dev \
    libxine2-dev \
    libgstreamer0.10-dev \
    libgstreamer-plugins-base0.10-dev \
    libv4l-dev \
    libtbb-dev \
    libqt4-dev \
    libfaac-dev \
    libmp3lame-dev \
    libopencore-amrnb-dev \
    libopencore-amrwb-dev \
    libtheora-dev \
    libvorbis-dev \
    libxvidcore-dev \
    x264 \
    v4l-utils \
    unzip \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN set -x \
  && apt-get update \
  && apt-get install -y \
    wget \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /
RUN set -x \
  && wget https://github.com/opencv/opencv/archive/3.2.0.tar.gz -O opencv.tar.gz \
  && wget https://github.com/opencv/opencv_contrib/archive/3.2.0.tar.gz -O opencv_contrib.tar.gz \
  && tar -zxvf opencv.tar.gz \
  && tar -zxvf opencv_contrib.tar.gz \
  && rm opencv.tar.gz opencv_contrib.tar.gz \
  && cd opencv-3.2.0 \
  && mkdir build \
  && cmake \
    -DBUILD_DOCS=ON \
    -DBUILD_EXAMPLES=ON \
    -DCMAKE_BUILD_TYPE=RELEASE \
    -DOPENCV_EXTRA_MODULES_PATH=/opencv_contrib-3.2.0/modules \
    -DWITH_TBB=ON \
    -DWITH_GTK=ON \
    -DWITH_OPENGL=ON \
    -DWITH_QT=ON \
    -DINSTALL_C_EXAMPLES=ON \
    -DWITH_OPENCL=OFF \
    -DWITH_CUDA=OFF \
    -DWITH_OPENNI=ON \
    -DWITH_UNICAP=ON \
    -DWITH_V4L=ON \
    -DWITH_XINE=ON . \
  && make -j5 \
  && make install

RUN ldconfig -v
ENTRYPOINT ["/bin/bash"]
