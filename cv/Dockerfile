from nvidia/cuda:8.0-cudnn6-runtime-ubuntu16.04

RUN set -ex \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
    git wget unzip \
    pkg-config build-essential \
    make cmake gcc \
    software-properties-common \
    language-pack-ja-base language-pack-ja \
  && add-apt-repository -y ppa:jonathonf/python-3.6 \
  && apt-get update \
  && apt-get install -y \
    python3.6 \
    python3.6-dev \
    python3-pip \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN update-locale LANG=ja_JP.UTF-8 LANGUAGE=ja_JP:ja
ENV LANG ja_JP.UTF-8
ENV LC_ALL ja_JP.UTF-8
ENV LC_CTYPE ja_JP.UTF-8

RUN python3.6 -m pip install pip --upgrade \
  && python3.6 -m pip install \
    wheel setuptools \
    numpy \
    pillow

WORKDIR /
RUN set -x \
  && wget -q https://github.com/opencv/opencv/archive/3.4.0.tar.gz -O opencv.tar.gz \
  && wget -q https://github.com/opencv/opencv_contrib/archive/3.4.0.tar.gz -O opencv_contrib.tar.gz \
  && tar -zxvf opencv.tar.gz \
  && tar -zxvf opencv_contrib.tar.gz \
  && rm opencv.tar.gz opencv_contrib.tar.gz

# https://github.com/atinfinity/lab/wiki/Linux%E7%92%B0%E5%A2%83%E3%81%A7%E3%81%AEOpenCV%E3%83%93%E3%83%AB%E3%83%89#ubuntu16.04
# TODO: 不要なものを削除
RUN set -ex \
  && add-apt-repository -y ppa:jonathonf/ffmpeg-3 \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
    libgtk2.0-dev \
    ffmpeg \
    libdc1394-22 \
    libdc1394-22-dev libjpeg-dev libpng12-dev libtiff5-dev libjasper-dev \
    libavcodec-dev libavformat-dev libswscale-dev \
    libv4l-dev libfaac-dev v4l-utils x264 \
    libmp3lame-dev \
    libopencore-amrnb-dev \
    libopencore-amrwb-dev \
    libtheora-dev \
    libvorbis-dev \
    libxvidcore-dev \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /opencv-3.4.0
RUN set -x \
  && mkdir build \
  && cd build \
  && cmake .. \
    -DOPENCV_EXTRA_MODULES_PATH=/opencv_contrib-3.4.0/modules/ \
    -DBUILD_TESTS=OFF \
    -DBUILD_DOCS=OFF \
    -DBUILD_PERF_TESTS=OFF \
    -DBUILD_opencv_dnn=OFF \
    -DBUILD_opencv_ml=OFF \
    -DBUILD_opencv_aruco=OFF \
    -DBUILD_opencv_bgsegm=ON \
    -DBUILD_opencv_bioinspired=OFF \
    -DBUILD_opencv_ccalib=OFF \
    -DBUILD_opencv_cnn_3dobj=OFF \
    -DBUILD_opencv_cvv=OFF \
    -DBUILD_opencv_datasets=OFF \
    -DBUILD_opencv_dnn_modern=OFF \
    -DBUILD_opencv_dnns_easily_fooled=OFF \
    -DBUILD_opencv_dpm=OFF \
    -DBUILD_opencv_face=OFF \
    -DBUILD_opencv_freetype=OFF \
    -DBUILD_opencv_fuzzy=OFF \
    -DBUILD_opencv_hdf=OFF \
    -DBUILD_opencv_img_hash=OFF \
    -DBUILD_opencv_line_descriptor=OFF \
    -DBUILD_opencv_matlab=OFF \
    -DBUILD_opencv_optflow=ON \
    -DBUILD_opencv_ovis=OFF \
    -DBUILD_opencv_phase_unwrapping=OFF \
    -DBUILD_opencv_plot=OFF \
    -DBUILD_opencv_reg=OFF \
    -DBUILD_opencv_rgbd=OFF \
    -DBUILD_opencv_saliency=OFF \
    -DBUILD_opencv_sfm=OFF \
    -DBUILD_opencv_stereo=OFF \
    -DBUILD_opencv_structured_light=OFF \
    -DBUILD_opencv_surface_matching=OFF \
    -DBUILD_opencv_text=OFF \
    -DBUILD_opencv_tracking=OFF \
    -DBUILD_opencv_xfeatures2d=OFF \
    -DBUILD_opencv_ximgproc=OFF \
    -DBUILD_opencv_xobjdetect=OFF \
    -DBUILD_opencv_xphoto=OFF \
    -DWITH_CUDA=OFF \
    -DWITH_GTK=ON \
    -DWITH_OPENCL=OFF \
    -DWITH_QT=OFF \
    -DWITH_LIBV4L=ON \
    -DCMAKE_BUILD_TYPE=RELEASE \
    -DPYTHON3_EXECUTABLE=/usr/bin/python3.6 \
    -DPYTHON3_DEFAULT_EXECUTABLE=/usr/bin/python3.6 \
    -DPYTHON3_INCLUDE_DIRS=/usr/include/python3.6m \
    -DPYTHON3_PACKAGES_PATH=/usr/lib/python3.6/dist-packages \
    -Dopencv_dnn_BUILD_TORCH_IMPORTER:BOOL=OFF \
  && make -j5 \
  && make install \
  && python3.6 -c "import cv2"

RUN ldconfig -v

RUN python3.6 -m pip install \
    scipy \
    scikit-learn \
    tensorflow-gpu
WORKDIR /

# 開発用
RUN set -ex \
  && add-apt-repository -y ppa:neovim-ppa/stable \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
    sudo zsh tmux tree less bc curl \
    ibus-mozc ctags editorconfig \
    x11-apps tig neovim apt-utils

RUN set -ex \
  && python3.6 -m pip install \
    ipython neovim jedi tox flake8 \
    dm-sonnet

ENV USERNAME developer
RUN useradd -m $USERNAME \
  && echo "$USERNAME:$USERNAME" | chpasswd \
  && usermod --shell /bin/bash $USERNAME \
  && usermod -aG sudo $USERNAME \
  && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/$USERNAME \
  && chmod 0440 /etc/sudoers.d/$USERNAME \
  && usermod  --uid 1000 $USERNAME \
  && groupmod --gid 1000 $USERNAME
# Replace 1000 with your user/group id

RUN ln -sf /usr/bin/python3.6 /usr/bin/python3 \
  && ln -sf /usr/bin/python3.6 /usr/bin/python

ENV SHELL=/bin/zsh

WORKDIR /work
