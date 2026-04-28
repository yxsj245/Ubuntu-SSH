#!/bin/bash
# 虚拟磁盘管理脚本
# 用法:
#   sudo ./init-disk.sh [路径] [大小]       创建并挂载虚拟磁盘（默认10G）
#   sudo ./init-disk.sh --delete [路径]     卸载并删除虚拟磁盘
#
# 路径参数同时决定磁盘文件和挂载目录：
#   /mnt/disk1/data  ->  磁盘文件: /mnt/disk1/data.img  挂载目录: /mnt/disk1/data/

# 默认路径
DEFAULT_PATH="/mnt/disk1/docker/ubuntu_ssh/data"

# 根据路径生成磁盘文件和挂载目录
set_paths() {
    local base="${1:-$DEFAULT_PATH}"
    # 自动转为绝对路径
    base="$(cd "$(dirname "$base")" 2>/dev/null && pwd)/$(basename "$base")"
    DISK_FILE="${base}.img"
    MOUNT_DIR="${base}"
}

# 删除虚拟磁盘
delete_disk() {
    set_paths "$1"
    echo "正在停止容器..."
    docker compose down 2>/dev/null

    if mountpoint -q "$MOUNT_DIR" 2>/dev/null; then
        echo "正在卸载..."
        umount "$MOUNT_DIR"
    fi

    if [ -f "$DISK_FILE" ]; then
        rm -f "$DISK_FILE"
        echo "已删除磁盘文件: $DISK_FILE"
    fi

    echo "清理完成"
}

# 创建并挂载虚拟磁盘
create_disk() {
    set_paths "$1"
    DISK_SIZE=${2:-10G}

    if [ -f "$DISK_FILE" ]; then
        echo "磁盘文件已存在，跳过创建"
    else
        echo "正在创建 ${DISK_SIZE} 虚拟磁盘（精简置备）..."
        truncate -s "$DISK_SIZE" "$DISK_FILE"
        echo "正在格式化为 ext4..."
        mkfs.ext4 "$DISK_FILE"
        echo "虚拟磁盘创建完成: $DISK_FILE"
    fi

    mkdir -p "$MOUNT_DIR"

    if mountpoint -q "$MOUNT_DIR"; then
        echo "已经挂载，跳过"
    else
        echo "正在挂载到 ${MOUNT_DIR}..."
        mount -o loop "$DISK_FILE" "$MOUNT_DIR"
        echo "挂载完成"
    fi

    echo "完成！可以启动容器了: docker compose up -d"
}

# 参数处理
case "$1" in
    --delete|-d)
        delete_disk "$2"
        ;;
    --help|-h)
        echo "用法:"
        echo "  sudo ./init-disk.sh [路径] [大小]       创建并挂载虚拟磁盘（默认10G）"
        echo "  sudo ./init-disk.sh --delete [路径]      卸载并删除虚拟磁盘"
        echo "  sudo ./init-disk.sh --help               显示帮助"
        echo ""
        echo "路径默认: $DEFAULT_PATH"
        echo "  磁盘文件: <路径>.img"
        echo "  挂载目录: <路径>/"
        ;;
    *)
        create_disk "$1" "$2"
        ;;
esac
