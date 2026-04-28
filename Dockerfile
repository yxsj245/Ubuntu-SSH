# 基于 Ubuntu 24.04 的 SSH 服务镜像
FROM ubuntu:24.04

# 避免交互式安装提示
ENV DEBIAN_FRONTEND=noninteractive

# 设置清华镜像源
RUN sed -i 's@//.*archive.ubuntu.com@//mirrors.tuna.tsinghua.edu.cn@g' /etc/apt/sources.list.d/ubuntu.sources && \
    sed -i 's@//.*security.ubuntu.com@//mirrors.tuna.tsinghua.edu.cn@g' /etc/apt/sources.list.d/ubuntu.sources

# 安装 OpenSSH 服务器和常用工具
RUN apt-get update && \
    apt-get install -y \
    openssh-server \
    vim \
    curl \
    wget \
    git \
    net-tools \
    iputils-ping \
    iproute2 \
    htop \
    tree \
    unzip \
    zip \
    tar \
    lsof \
    sudo \
    ca-certificates \
    locales \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 设置中文 locale
RUN locale-gen zh_CN.UTF-8
ENV LANG=zh_CN.UTF-8
ENV LC_ALL=zh_CN.UTF-8

# 创建 SSH 运行所需目录
RUN mkdir -p /run/sshd

# 允许 root 登录（可按需修改）
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# 暴露 SSH 端口
EXPOSE 22

# 启动时通过环境变量设置密码，再启动 SSH
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
