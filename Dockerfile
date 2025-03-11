# this is a dockerfile aimed at running the kuka robot packages in ros noetic in different ubuntu distribution in a docker container. 
# This file is adapted from Zhaoting Li and Yuxuan Hu @ TU Delft   
# generated from docker_images/create_ros_image.Dockerfile.em

FROM osrf/ros:noetic-desktop-focal

# install ros packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-noetic-desktop-full=1.5.0-1* \
    && rm -rf /var/lib/apt/lists/*

#Maintainer info 
LABEL maintainer = "i.belli@tudelft.nl"

ARG USERNAME=kuka_cor
ARG USER_UID=1000
ARG USER_GID=$USER_UID

#create a non-root user
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && mkdir /home/$USERNAME/.config && chown $USER_UID:$USER_GID /home/$USERNAME/.config


# copy dependancies needed
COPY ./kuka_dependencies /kuka_dependencies

# python fix for when waf can't identify python environment
RUN apt-get update && apt-get install python-is-python3 && apt-get install cmake 

#get catkin tools
RUN apt-get install -y python3-pip && \
    apt-get install -y \
    ros-noetic-catkin  &&\
    pip3 install catkin-tools


#boost version fix
RUN apt-get install -y libboost-all-dev 

# install development libraries 
RUN sudo apt-get install -y doxygen && apt-get install -y libeigen3-dev

#get ROS dependencies
RUN sudo apt-get install -y \
    ros-noetic-moveit-ros-visualization \
    ros-noetic-moveit-planners-ompl \
    ros-noetic-moveit \
    ros-noetic-joint-trajectory-controller \
    ros-noetic-ros-controllers \
    ros-noetic-ros-control \
    ros-noetic-moveit-simple-controller-manager


#mesa
RUN sudo apt-get update && sudo apt-get install -y \
    x11-apps \
    x11-xserver-utils \
    libgl1-mesa-glx \
    mesa-utils

# uncomment below to use mesa without gpu
RUN export LIBGL_ALWAYS_SOFTWARE=1


#install gpu driver (makes sense only if you have a gpu on your machine)
RUN sudo apt-get install curl 

#install ping command
RUN sudo apt-get install -y iputils-ping

#set up sudo
RUN apt-get install -y sudo\
&& echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
&& chmod 0440 /etc/sudoers.d/$USERNAME \
&& rm -rf /var/lib/apt/lists/*

# Build and install kuka_fri
WORKDIR /kuka_dependencies/kuka_fri
RUN ./waf configure && \
    ./waf && \
    ./waf install

# Build and install SpaceVecAlg
WORKDIR /kuka_dependencies/SpaceVecAlg
RUN mkdir -p build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release -DENABLE_SIMD=ON -DPYTHON_BINDING=OFF .. && \
    make -j && \
    make install

# Build and install RBDyn
WORKDIR /kuka_dependencies/RBDyn
RUN mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release -DENABLE_SIMD=ON -DPYTHON_BINDING=OFF .. && \
    make -j && \
    make install

# Build and install mc_rbdyn_urdf
WORKDIR /kuka_dependencies/mc_rbdyn_urdf
RUN mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release -DENABLE_SIMD=ON -DPYTHON_BINDING=OFF .. && \
    make -j && \
    make install

# Build and install corrade
WORKDIR /kuka_dependencies/corrade
RUN mkdir build && cd build && \
    cmake .. && \
    make -j && \
    make install

# Build and install robot_controllers
WORKDIR /kuka_dependencies/robot_controllers
RUN mkdir build && cd build && \
    cmake .. && \
    make -j && \
    make install

# install robotics toolbox
RUN pip install \
    roboticstoolbox-python \
    spatialmath-rospy \
    spatialgeometry

RUN pip install "numpy>=1.20.0"
RUN pip install --upgrade scipy
RUN pip install spatialmath-python
RUN pip install spatialmath-python==1.0.5


# python fix
RUN apt-get update
RUN apt-get install python3-tk -y
RUN apt-get update 
RUN apt-get install -y mesa-utils libgl1-mesa-glx libgl1-mesa-dri

# install IPOPT and MUMPS for optimization
RUN apt update 
RUN apt install coinor-libipopt-dev libmumps-seq-dev

# Display environment setup. 
ENV DISPLAY=host.docker.internal:0.0
ENV QT_X11_NO_MITSHM=1
ENV NVIDIA_DRIVER_CAPABILITIES=all

WORKDIR /

COPY bashrc /home/${USERNAME}/.bashrc

# connect to real kuka robot
RUN export ROS_MASTER_URI=http://192.180.1.5:30202
RUN export ROS_IP=192.180.1.15
