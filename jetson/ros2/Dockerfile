FROM nvcr.io/nvidia/l4t-base:r32.4.2

ENV DEBIAN_FRONTEND=noninteractive
RUN apt update \
  && apt install -y --no-install-recommends \
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
    curl \
  && curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | sudo apt-key add - \
  && echo "deb http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" > /etc/apt/sources.list.d/ros2-latest.list \
  && apt update \
  && apt install -y --no-install-recommends \
    ros-dashing-desktop ros-dashing-cv-bridge ros-dashing-librealsense2 ros-dashing-message-filters ros-dashing-image-transport \
    libssl-dev libusb-1.0-0-dev pkg-config libgtk-3-dev \
    libglfw3-dev libgl1-mesa-dev libglu1-mesa-dev \
    ros-dashing-realsense-camera-msgs ros-dashing-realsense-ros2-camera \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /config/rviz
RUN wget https://raw.githubusercontent.com/intel/ros2_intel_realsense/master/realsense_ros2_camera/rviz/ros2.rviz

RUN source /opt/ros/dashing/setup.bash
