FROM nvidia/cuda:11.2.1-cudnn8-devel-ubuntu20.04@sha256:fd1afca8e3960642c58db2f2b1694fc8c34625fd13612ad600c62fe833052aa4

RUN export DEBIAN_FRONTEND=noninteractive \
  && apt-get update \
  && apt-get install -y \
    build-essential \
    curl \
    cmake \
    git \
    python3-dev \
    python3-pip \
    libopenexr-dev \
    libxi-dev \
    libglfw3-dev \
    libglew-dev \
    libomp-dev \
    libxinerama-dev \
    libxcursor-dev

RUN pip install \
  commentjson~=0.9.0 \
  imageio~=2.16.0 \
  numpy~=1.21.2 \
  pybind11~=2.7.1 \
  scipy~=1.7.1 \
  tqdm~=4.62.2 \
  opencv-python~=4.5.5.62

WORKDIR /build/cmake
RUN curl -OL https://github.com/Kitware/CMake/releases/download/v3.22.3/cmake-3.22.3.tar.gz \
  && tar -xf cmake-3.22.3.tar.gz \
  && cd cmake-3.22.3 \
  && cmake . -DCMAKE_USE_OPENSSL=OFF \
  && make \
  && make install

RUN ln -s $(which python3.8) /usr/bin/python
