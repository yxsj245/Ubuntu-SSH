#!/bin/bash
set -e

# 运行时设置 SSH 监听端口，避免与宿主机 22 端口冲突
SSH_PORT="${SSH_PORT:-2222}"

# 简单校验端口格式，避免传入异常值
case "$SSH_PORT" in
  ''|*[!0-9]*)
    echo "错误：SSH_PORT 必须是数字，当前值为: $SSH_PORT" >&2
    exit 1
    ;;
esac

if [ "$SSH_PORT" -lt 1 ] || [ "$SSH_PORT" -gt 65535 ]; then
  echo "错误：SSH_PORT 必须在 1 到 65535 之间，当前值为: $SSH_PORT" >&2
  exit 1
fi

# 运行时设置 root 密码
echo "root:${ROOT_PASSWORD:-123456}" | chpasswd

# 确保 sshd 运行目录存在
mkdir -p /run/sshd

# 启动 SSH 服务
exec /usr/sbin/sshd -D -e -o "Port=$SSH_PORT"
