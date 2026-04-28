#!/bin/bash
# 运行时设置 root 密码
echo "root:${ROOT_PASSWORD:-123456}" | chpasswd
# 启动 SSH 服务
exec /usr/sbin/sshd -D
