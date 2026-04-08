# Start from pre-build rtw-layer image layer
FROM code.b-robotized.com:5050/b_public/b_products/b_controlled_box/b-controlled-box-commissioning-containers/rtw-tools:jazzy
ARG ROBOT_MANUFACTURER

# Use bash as the default shell
SHELL ["/bin/bash", "-c"]

#########################
# root user
#########################
# ssh forwarding from host works only as root user, so we do our vcs import that needs the authentification right here, before switching to b-robotized user.
RUN mkdir -p -m 0700 /root/.ssh && \
    ssh-keyscan code.b-robotized.com >> /root/.ssh/known_hosts

WORKDIR /home/b-robotized/comissioning/ros2_jazzy/src
COPY fanuc.jazzy.repos .

# download big stl files, not just links to them in fanuc_description
RUN apt-get update && apt-get install -y git-lfs && \
    git lfs install

RUN --mount=type=ssh \
  vcs import . < fanuc.jazzy.repos && \
  vcs custom --git --args submodule update --init --recursive
  
RUN chown -R b-robotized:b-robotized /home/b-robotized/comissioning

############################
# now go to our generic user.
USER b-robotized
#########################

WORKDIR /home/b-robotized/comissioning

# commissioning workspace
# `yes` is here to confirm the existing repo we createt via `vcs import` as root user.
RUN yes | rtw workspace create --ws-folder ros2_jazzy --ros-distro jazzy --ignore-ws-cmd-error

############################
# Workspace build
############################

# pull the repos for this robot
WORKDIR /home/b-robotized/comissioning/ros2_jazzy/src

RUN sudo apt update && sudo apt install -y ros-jazzy-moveit ros-jazzy-ros2-control ros-jazzy-ros2-control-cmake ros-jazzy-ros2controlcli ros-jazzy-ros2-controllers 
# run rosdep install
WORKDIR /home/b-robotized/comissioning/ros2_jazzy
RUN rosdep update && rosdep install --from-paths src --ignore-src -r -y

# build the workspace
RUN rtw workspace use ros2_jazzy && \
  source /opt/ros/jazzy/setup.bash && \
  colcon build --symlink-install


###########################
# Finishing up
############################

# set env variables
ENV ROS_STATIC_PEERS="192.168.28.7"
# cd into corresponding robot dir
WORKDIR /home/b-robotized/comissioning/ros2_jazzy/src/b_ctrldbox_commissioning/fanuc
# auto-source on new terminal opening
RUN echo -e "source /opt/ros_team_workspace/setup.bash\nsource /opt/ros_team_workspace/scripts/configuration/terminal_coloring.bash\nrtw ws ros2_jazzy" >> /home/b-robotized/.bashrc
