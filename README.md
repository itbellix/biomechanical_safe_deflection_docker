- [Introduction](#introduction)
- [Prerequisite](#prerequisite)
- [Installation](#installation)
- [Container](#Container)
- [Venv](#venv)
- [Run](#run)
- [Troubleshooting](#troubleshooting)
# Introduction
This is a self-contained package aimed at running the code developed for our paper ``A Shared Control Approach to Safely Limiting Patient Motion Based on Tendon Strain During Robotic-Assisted Shoulder Rehabilitation" using [Docker](https://www.docker.com/). This should save you from having to install manually all the dependencies, and allow you to run the code in simulation (with Gazebo) as well as on the KUKA robot. 

# Prerequisite
You should have a working Ubuntu distribution ready on your computer (e.g. Ubuntu 22.04 LTS). Please follow the instruction on [Docker](https://www.docker.com/) and install Docker. 

# Installation
Go to your home folder and install this repo by 
```console
git clone git@github.com:itbellix/biomechanical_safe_deflection_docker.git
cd biomechanical_safe_deflection_docker
```
Follow the instructions on cloning the repos to use the controllers. **You don't need to build any of the packages, the dockerfile will build them as it builds the docker image.** However, please make sure to switch to the correct branch on each repo. 

For kuka_fri (used for the real robot). If you don't have access to it, you can skip the next instruction block, and still work in simulation.
```console
mkdir kuka_dependencies
cd kuka_dependencies
git clone --recurse-submodules git@gitlab.tudelft.nl:kuka-iiwa-7-cor-lab/kuka_fri.git
cd kuka_fri
git checkout legacy
cd ..
```

For other repos
```console
git clone --recurse-submodules git@github.com:costashatz/SpaceVecAlg.git
git clone --recurse-submodules git@github.com:costashatz/RBDyn.git
git clone --recurse-submodules --recursive git@github.com:costashatz/mc_rbdyn_urdf.git
git clone --recurse-submodules git@github.com:mosra/corrade.git
cd corrade
git checkout 0d149ee9f26a6e35c30b1b44f281b272397842f5
cd ..
git clone --recurse-submodules git@github.com:epfl-lasa/robot_controllers.git
cd ..
```
Now you can build you docker image by
```console
docker build -t biomech_safe_defl .
```
this can take a while, grab a coffee, make some tea, and after image is finished building, you can check your list of available docker image by
``` console
docker image list
```
You should see information about the image `biomech_safe_defl` which we just built!

In the docker file, we created a user `kuka_cor` with `USER_UID` and `USER_GID` both at 1000, same as your host. This mean that you can share volumes and files between docker image and host.

# Container
Here, you create the actual docker container that will allow to run the code.
You should put packages you wish to run on kuka into the catkin workspace's **src**. This always includes the TU Delft implementation of [`iiwa_ros`](https://gitlab.tudelft.nl/kuka-iiwa-7-cor-lab/iiwa_ros). Here, we will also install the [`biomechanical_safe_deflection`](https://github.com/itbellix/biomechanical_safe_deflection) package, and check out to a tested version of it. Clone and set up the packages by
```console
cd catkin_ws
mkdir src && cd src 
git clone --recurse-submodules git@gitlab.tudelft.nl:kuka-iiwa-7-cor-lab/iiwa_ros.git
git clone --recurse-submodules git@github.com:itbellix/biomechanical_safe_deflection.git
cd biomechanical_safe_deflection
git checkout b000b7e8c6629c67e60df490efa02ee064cbc8ce
cd ../../..
```
If you are working only in simulation (i.e., you don't have access to the `kuka_fri` package), run the following:
```console
cd iiwa_ros/src/iiwa_driver
touch CATKIN_IGNORE
cd ../../..
```

Run the docker image and load directory `iiwa_ros` as an volume
```console
docker run -it --user kuka_cor --name my_container --network=host --ipc=host -v $PWD/catkin_ws:/catkin_ws -v /temp/.X11-unix:/temp/.X11-unix:rw --env=DISPLAY biomech_safe_defl
```

This will create a container named `my_container` with the image `kuka_ros`, and at any point, you can exit the container with `ctrl+ d`.

*Note*: the first time you run this you should see this error `bash: /catkin_ws/devel/setup.bash: No such file or directory`. This is because we have not run `catkin build` yet, so don't worry!

You can start it again with 
```console
docker start -i my_container
```
or you can also open up a different terminal in the same container by 
```console
docker exec -it my_container bash
```
Firstly, you should build your working package by 
```console
cd catkin_ws
catkin build
cd ..
source catkin_ws/devel/setup.bash
```
Any changes made by `catkin_make` will also show up in the host directory so you don't need to rebuild the package every time you rerun your image. And sourcing of your package is taken care of in bashrc. 

# Venv
To avoid dependency conflicts, we have set up a virtual environment used only by some of the code. You can create by running:
```console
sudo python -m venv venv_project
source venv_project/bin/activate
pip install -r /home/kuka_cor/requirements.txt
```

# Run
Open 2 terminals in the container, and :
1. the robot controller (and Gazebo if `simulation` argument is set to `true`)
```console
roslaunch biomechanical_safe_deflection controller.launch simulation:=true
```

2. the shared controllers
```console
roslaunch biomechanical_safe_deflection start_all.launch simulation:=true venv:=/catkin_ws/src/biomechanical_safe_deflection/venv_project/bin/python3
```

You should be see Gazeb firing up with a KUKA LBR iiwa 7 model, and a `dynamic_reconfigure` window that allows to select the task to execute.

*Note 1*: we do not ship the HSL libraries necessary to run the MA27 solver with IPOPT. As such, the default solver is MUMPS, which achieves similar performances but is a bit slower. You can always build the HSL libraries from source yourself, and use a linear solver of your choice.

*Note 2*: likely, the scripts running in the docker container will not have access to the audio drivers of your device. If this is the case, you will see a warning being printed during the *high-authority interventions* instead of hearing a sound as described in our paper.

*Note 3*: our controllers are designed for actual human-robot interaction, so the simulation setup is quite minimal and allows only to have a rough idea of the overall functioning of our system... For example, when estimating online the position of the center of the human shoulder, the simulation will gradually drift and accumulate errors, so it appears as if the robot is moving away. If you want to have a better sense of the desired results, check out our video or try connecting your robot!


# Troubleshooting

## Nvidia Issues [Docker]
If you are having problem using your Nvidia GPU in docker GUIs, please take a look at [Nvidia Container toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/sample-workload.html) and follow their instruction. Generally, adding args into the `docker run` command helps, e.g. `--runtime=nvidia` and `--gpus all`. 
For example, the run command will be like
```console
    docker run -it --runtime=nvidia --gpus all --user kuka_cor --name my_container --network=host --ipc=host -v $PWD/catkin_ws:/catkin_ws -v /temp/.X11-unix:/temp/.X11-unix:rw --env=DISPLAY kuka_ros
```

## Missing GPU [Docker]
If your system does not have a GPU, you will see an error like the following when trying to run some applications (e.g. Gazebo):
```console
libGL error: MESA-LOADER: failed to retrieve device information
Segmentation fault (core dumped)
```

You should make sure that OpenGL uses software rendering instead, by running:
```console
export LIBGL_ALWAYS_SOFTWARE=1
```
You need to run this in every terminal, so add this line to the `~/.bashrc` in your container, to set it on every terminal session.

## ROS Service Issues [Docker]
If ROS service is having trouble to run, a possible cause this that RBDyn can't be found. Run this line in terminal and try again:
```console
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib:/kuka_dependencies/RBDyn/build/src
```
