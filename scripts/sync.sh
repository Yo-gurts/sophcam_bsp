#!/bin/bash
# set -x # 显示执行的命令
set -e # 遇到错误立即退出

# 帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  -c, --check      检查是否已同步，不执行实际同步操作"
    echo "  -r, --reverse    执行反向同步（从目标到源）"
    echo "  -h, --help       显示此帮助信息"
    echo ""
    echo "默认行为: 执行正向同步（从源到目标）"
}

# 检查目录是否已同步
check_sync_status() {
    local source_path="$1"
    local target_path="$2"
    local description="$3"

    echo "正在检查 $description 是否已同步..."

    # 检查源目录是否存在
    if [ ! -d "$source_path" ]; then
        echo "错误: 源目录 '$source_path' 不存在"
        return 1
    fi

    # 检查目标目录是否存在
    if [ ! -d "$target_path" ]; then
        echo "目标目录 '$target_path' 不存在，未同步"
        # 显示差异（实际上是列出源目录中的文件）
        echo "文件差异:"
        find "$source_path" -type f | sort
        return 1
    fi

    # 使用rsync的dry-run模式检查差异
    local diff_output
    diff_output=$(rsync -avn --delete "$source_path/" "$target_path" 2>&1)

    if [ -z "$diff_output" ]; then
        echo "$description 已经完全同步"
        return 0
    else
        echo "$description 未完全同步，发现差异:"
        echo "$diff_output"
        return 1
    fi
}

# 同步目录函数
sync_directory() {
    local source_path="$1"
    local target_path="$2"
    local description="$3"
    local is_reverse="$4"

    if [ "$is_reverse" = "true" ]; then
        echo "正在执行反向同步 $description（从 $target_path 到 $source_path）..."
        # 交换源和目标以实现反向同步
        local temp="$source_path"
        source_path="$target_path"
        target_path="$temp"
    else
        echo "正在同步 $description 到 $target_path..."
    fi

    # 检查源目录是否存在
    if [ ! -d "$source_path" ]; then
        echo "错误: 源目录 '$source_path' 不存在"
        return 1
    fi

    # 确保目标目录的父目录存在
    local target_parent="$(dirname "$target_path")"
    mkdir -p "$target_parent"

    # 使用rsync进行同步，删除目标目录中不存在的文件，保持时间戳等属性
    rsync -av --delete "$source_path/" "$target_path"
    if [ $? -eq 0 ]; then
        echo "$description 同步成功"
        return 0
    else
        echo "错误: $description 同步失败"
        return 1
    fi
}

# 解析命令行参数
CHECK_MODE=false
REVERSE_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--check)
            CHECK_MODE=true
            shift
            ;;
        -r|--reverse)
            REVERSE_MODE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

CURRENT_DIR="$(pwd)"

# 定义需要同步的目录对
# 注意：这里使用了相对路径，根据实际情况可能需要调整
SOURCE_BUILD="$CURRENT_DIR/nana/build/boards/cv180x/cv1842cp_sophcam_spinand"
TARGET_BUILD="$CURRENT_DIR/build/boards/cv180x/cv1842cp_sophcam_spinand"

SOURCE_RAMDISK="$CURRENT_DIR/nana/ramdisk/rootfs/overlay/cv1842cp_sophcam_spinand"
TARGET_RAMDISK="$CURRENT_DIR/ramdisk/rootfs/overlay/cv1842cp_sophcam_spinand"

# 根据模式执行操作
if [ "$CHECK_MODE" = "true" ]; then
    echo "执行检查模式..."
    check_sync_status "$SOURCE_BUILD" "$TARGET_BUILD" "build目录"
    BUILD_RESULT=$?

    check_sync_status "$SOURCE_RAMDISK" "$TARGET_RAMDISK" "ramdisk目录"
    RAMDISK_RESULT=$?
else
    echo "执行同步模式..."
    sync_directory "$SOURCE_BUILD" "$TARGET_BUILD" "build目录" "$REVERSE_MODE"
    BUILD_RESULT=$?

    sync_directory "$SOURCE_RAMDISK" "$TARGET_RAMDISK" "ramdisk目录" "$REVERSE_MODE"
    RAMDISK_RESULT=$?
fi

# 检查结果
if [ $BUILD_RESULT -eq 0 ] && [ $RAMDISK_RESULT -eq 0 ]; then
    echo "所有操作完成成功"
    exit 0
else
    echo "部分操作失败"
    exit 1
fi
