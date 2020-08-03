ARG BASE_IMAGE=nvcr.io/nvidia/l4t-base:r32.4.2
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive


#
# install prerequisites - https://docs.nvidia.com/deeplearning/frameworks/install-tf-jetson-platform/index.html#prereqs
#
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    python3-pip \
    python3-dev \
    gfortran \
    build-essential \
    libopenblas-dev \
    libhdf5-serial-dev \
    hdf5-tools \
    libhdf5-dev \
    zlib1g-dev \
    zip \
    libjpeg8-dev \
  && rm -rf /var/lib/apt/lists/*

RUN python3.6 -m pip install -U pip setuptools Cython wheel \
  && python3.6 -m pip install numpy \
  && HDF5_DIR=/usr/lib/aarch64-linux-gnu/hdf5/serial/ python3.6 -m pip install \
    h5py \
    future \
    mock==3.0.5 \
    keras_preprocessing \
    keras_applications \
    gast \
    futures \
    protobuf \
    pybind11


RUN wget --quiet --progress=bar:force:noscroll --no-check-certificate \
    https://developer.download.nvidia.com/compute/redist/jp/v44/tensorflow/tensorflow-2.2.0+nv20.6-cp36-cp36m-linux_aarch64.whl \
  && python3.6 -m pip install tensorflow-2.2.0+nv20.6-cp36-cp36m-linux_aarch64.whl \
  && rm tensorflow-2.2.0+nv20.6-cp36-cp36m-linux_aarch64.whl


ENV PATH="/usr/local/cuda/bin:${PATH}"
ENV LD_LIBRARY_PATH="/usr/local/cuda/lib64:${LD_LIBRARY_PATH}"
RUN echo "$PATH" && echo "$LD_LIBRARY_PATH"

RUN python3.6 -m pip install pycuda --verbose
