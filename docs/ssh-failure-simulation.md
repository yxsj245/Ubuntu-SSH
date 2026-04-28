# SSH 故障模拟与容器侧修复说明

## 目标

模拟以下场景之一：

- 跨版本升级后遗留了无效 SSH 配置，导致 `ssh.service` 无法启动
- SSH 配置被错误重置，导致原有连接方式不可用

本次采用的是第一种方式：向宿主机 `/etc/ssh/sshd_config.d/` 注入一个无效配置文件，使 `sshd -t` 失败，然后直接对宿主机 `ssh.service` 执行重启，模拟“升级后管理员重启 SSH，结果服务启动失败”的场景，最终造成宿主机 `22` 端口不可连接。

## 前提条件

容器必须具备以下能力，否则不要先破坏宿主机 SSH：

1. 容器以 `root` 身份运行
2. 容器开启 `privileged`
3. 容器将宿主机根目录挂载到容器内，例如 `/:/host-root:rw`
4. 容器内可以访问宿主机 D-Bus Socket：
   - `/host-root/run/dbus/system_bus_socket`

本次实际验证到的关键条件如下：

```bash
docker inspect ubuntu24 --format '{{json .HostConfig.Privileged}} {{json .Config.User}} {{json .HostConfig.Binds}}'
```

返回结果等价于：

```text
true "root:root" ["/:/host-root:rw"]
```

这说明容器当前权限已经足够接管宿主机 SSH 修复。

## Host 网络模式补充

如果容器使用 `network_mode: host`，容器内的 `sshd` 不应继续监听宿主机默认的 `22` 端口，否则会与宿主机 SSH 冲突，导致容器自身反复重启。

建议通过环境变量单独指定容器 SSH 端口，例如：

```bash
SSH_PORT=2222
```

这样既能保留 `host` 网络带来的宿主机贴近性，也能保留一个独立的容器 SSH 维修入口。

## 备份建议

在注入故障前，先备份宿主机 SSH 目录：

```bash
ts=$(date +%Y%m%d-%H%M%S)
backup_dir=/host-root/root/ssh-sim-backup-$ts
mkdir -p "$backup_dir"
cp -a /host-root/etc/ssh "$backup_dir/"
```

## 容器侧检查项

### 1. 校验当前宿主机 SSH 配置有效

```bash
nsenter --mount=/host-root/proc/1/ns/mnt /usr/sbin/sshd -t
```

### 2. 校验容器可以控制宿主机 SSH 单元

```bash
busctl --address=unix:path=/host-root/run/dbus/system_bus_socket \
  call org.freedesktop.systemd1 \
  /org/freedesktop/systemd1 \
  org.freedesktop.systemd1.Manager \
  ReloadUnit ss ssh.service replace
```

## 故障注入

向宿主机写入一个无效配置文件：

```bash
printf '%s\n' 'InvalidLegacyOption yes' > /host-root/etc/ssh/sshd_config.d/99-restart-failure.conf
```

此时可用下面的命令确认配置已经损坏：

```bash
nsenter --mount=/host-root/proc/1/ns/mnt /usr/sbin/sshd -t
```

然后直接重启宿主机 `ssh.service`，让其在重启过程中进入失败状态：

```bash
busctl --address=unix:path=/host-root/run/dbus/system_bus_socket \
  call org.freedesktop.systemd1 \
  /org/freedesktop/systemd1 \
  org.freedesktop.systemd1.Manager \
  RestartUnit ss ssh.service replace
```

在 Ubuntu 的 `ssh.socket` 激活模式下，`ssh.service` 重启失败时，`ssh.socket` 也可能一起进入失败状态，因此最终现象仍然可能是 `22` 端口不可连接。

## 故障验证

验证宿主机 SSH 单元状态：

```bash
busctl --address=unix:path=/host-root/run/dbus/system_bus_socket \
  get-property org.freedesktop.systemd1 \
  /org/freedesktop/systemd1/unit/ssh_2eservice \
  org.freedesktop.systemd1.Unit ActiveState
```

验证 `22` 端口已经拒绝连接：

```bash
timeout 5 bash -lc 'cat < /dev/null > /dev/tcp/192.168.11.15/22' && echo tcp22_open || echo tcp22_closed
```

## 容器侧修复

删除坏配置并重新拉起宿主机 SSH：

```bash
rm -f /host-root/etc/ssh/sshd_config.d/99-restart-failure.conf

busctl --address=unix:path=/host-root/run/dbus/system_bus_socket \
  call org.freedesktop.systemd1 \
  /org/freedesktop/systemd1 \
  org.freedesktop.systemd1.Manager \
  StartUnit ss ssh.socket replace

busctl --address=unix:path=/host-root/run/dbus/system_bus_socket \
  call org.freedesktop.systemd1 \
  /org/freedesktop/systemd1 \
  org.freedesktop.systemd1.Manager \
  StartUnit ss ssh.service replace
```

## 修复验证

检查宿主机 SSH Banner：

```bash
timeout 5 bash -lc 'exec 3<>/dev/tcp/192.168.11.15/22; head -n 1 <&3'
```

期望返回类似：

```text
SSH-2.0-OpenSSH_9.6p1 Ubuntu-3ubuntu13.15
```

## 本次实操结论

1. 容器当前权限满足宿主机 SSH 故障修复要求
2. 可以真实模拟“修改配置后重启 SSH，结果服务启动失败”的运维场景
3. 宿主机 SSH 已被成功模拟为不可连接状态
4. 仅通过容器侧操作，已成功恢复宿主机 `ssh.service` 与 `22` 端口

## 注意事项

1. 不要在未验证容器修复链路前直接停止宿主机 SSH
2. 如果宿主机使用 `ssh.socket` 激活模式，恢复时优先同时处理 `ssh.socket` 与 `ssh.service`
3. 如果后续要改为“配置重置导致凭据失效”的模拟方式，可以改为注入新的认证策略，而不是写入无效配置
