FROM osrf/ros:jazzy-desktop

# creates a generic non-root user and installs ros team workspace + some extra tools we usually need.

# Use bash as the default shell
SHELL ["/bin/bash", "-c"]

# timezone and locale
ENV TZ=Etc/UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN apt update && apt install -y locales && \
    sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# some utils
# TODO: do we remove the upgrade? that adds 5-6 mins to build time and I'd argue makes the thing less reproducible.
RUN apt upgrade -y && \
    apt install -y \
        git \
        nano \
        sudo \
        tmux \
        vim \
        iputils-ping \
        iproute2 \
        wget \
        bash-completion \
        python3-pip \
        openssh-client \
    && rm -rf /var/lib/apt/lists/*

# ros2 dev tools
RUN apt update && apt install -y \
        python3-colcon-common-extensions \
        python3-vcstool \
        ros-jazzy-ros2controlcli \
        ros-jazzy-rmw-zenoh-cpp \
        chrony \
        ros-jazzy-ros2-control \
        ros-jazzy-ros2-controllers \
    && rm -rf /var/lib/apt/lists/*

# add local network 
RUN echo "allow 192.168.28.0/24" >> /etc/chrony/chrony.conf

# add entrypoint
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# add utility script for later. It clones the robot dir from b_ctrld_commissioning into a container workspace
COPY clone_robot_dir.sh /usr/local/bin/clone_robot_dir
RUN chmod +x /usr/local/bin/clone_robot_dir

# setup ros_team_ws
RUN git clone -b master https://github.com/b-robotized/ros_team_workspace.git /opt/ros_team_workspace/
RUN cd /opt/ros_team_workspace/rtwcli && pip3 install -r requirements.txt --break-system-packages && cd -

# generic, non-root user for the client environment
RUN groupadd --gid 1001 b-robotized
RUN useradd --create-home --shell /bin/bash --uid 1001 --gid 1001 b-robotized && \
    echo "b-robotized ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/b-robotized" && \
    chmod 0440 "/etc/sudoers.d/b-robotized" && \
    usermod -aG sudo b-robotized

ENTRYPOINT ["entrypoint.sh"]
CMD ["tail", "-f", "/dev/null"]