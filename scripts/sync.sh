#!/bin/bash
# set -x # 显示执行的命令
set -e # 遇到错误立即退出

# 定义颜色代码
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 帮助信息
show_help() {
    echo -e "${BLUE}用法: $0 [选项]${NC}"
    echo -e "${BLUE}选项:${NC}"
    echo -e "${BLUE}  -c, --check      检查是否已同步，不执行实际同步操作${NC}"
    echo -e "${BLUE}  -r, --reverse    执行反向同步（从目标到源）${NC}"
    echo -e "${BLUE}  -h, --help       显示此帮助信息${NC}"
    echo -e ""
    echo -e "${BLUE}默认行为: 执行正向同步（从源到目标）${NC}"
}

# 检查目录是否已同步
check_sync_status() {
    local source_path="$1"
    local target_path="$2"
    local description="$3"

    echo -e "${BLUE}🔍 正在检查 $description 是否已同步...${NC}"

    # 检查源目录是否存在
    if [ ! -d "$source_path" ]; then
        echo -e "${RED}错误: 源目录 '$source_path' 不存在${NC}"
        return 1
    fi

    # 检查目标目录是否存在
    if [ ! -d "$target_path" ]; then
        echo -e "${YELLOW}目标目录 '$target_path' 不存在，未同步${NC}"
        # 显示差异（实际上是列出源目录中的文件）
        echo -e "${YELLOW}文件差异:${NC}"
        find "$source_path" -type f | sort
        return 1
    fi

    # 使用diff -r对比目录差异
    local diff_output
    diff_output=$(diff -r "$source_path" "$target_path" 2>&1 || true)

    if [ -z "$diff_output" ]; then
        echo -e "${GREEN}✅ $description 已经完全同步${NC}"
        return 0
    else
        echo -e "${YELLOW}❌ $description 未完全同步，发现差异:${NC}"
        # 显示完整的diff输出
        diff -r "$source_path" "$target_path"
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
        echo -e "${BLUE}🔄 正在执行反向同步 $description（从 $target_path 到 $source_path）...${NC}"
        # 交换源和目标以实现反向同步
        local temp="$source_path"
        source_path="$target_path"
        target_path="$temp"
    else
        echo -e "${BLUE}🔄 正在同步 $description 到 $target_path...${NC}"
    fi

    # 检查源目录是否存在
    if [ ! -d "$source_path" ]; then
        echo -e "${RED}错误: 源目录 '$source_path' 不存在${NC}"
        return 1
    fi

    # 确保目标目录的父目录存在
    local target_parent="$(dirname "$target_path")"
    mkdir -p "$target_parent"

    # 使用rsync进行同步，删除目标目录中不存在的文件，保持时间戳等属性
    rsync -av --delete "$source_path/" "$target_path"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}$description 同步成功${NC}"
        return 0
    else
        echo -e "${RED}错误: $description 同步失败${NC}"
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
            echo -e "${RED}未知选项: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

CURRENT_DIR="$(pwd)"

# 定义需要同步的目录对
# 注意：这里使用了相对路径，根据实际情况可能需要调整
SOURCE_BUILD="$CURRENT_DIR/sophcam_bsp/build/boards/cv184x/cv1842cp_sm3_81_spinand"
TARGET_BUILD="$CURRENT_DIR/build/boards/cv184x/cv1842cp_sm3_81_spinand"

SOURCE_ALIOS="$CURRENT_DIR/sophcam_bsp/cvi_alios/solutions/normboot/customization/cv1842cp_sm3_81_spinand"
TARGET_ALIOS="$CURRENT_DIR/cvi_alios/solutions/normboot/customization/cv1842cp_sm3_81_spinand"

SOURCE_RAMDISK="$CURRENT_DIR/sophcam_bsp/ramdisk/rootfs/overlay/cv1842cp_sm3_81_spinand"
TARGET_RAMDISK="$CURRENT_DIR/ramdisk/rootfs/overlay/cv1842cp_sm3_81_spinand"

# 根据模式执行操作
if [ "$CHECK_MODE" = "true" ]; then
    echo -e "${BLUE}执行检查模式...${NC}"
    check_sync_status "$SOURCE_BUILD" "$TARGET_BUILD" "build目录"
    check_sync_status "$SOURCE_RAMDISK" "$TARGET_RAMDISK" "ramdisk目录"
    check_sync_status "$SOURCE_ALIOS" "$TARGET_ALIOS" "alios目录"
else
    echo -e "${BLUE}执行同步模式...${NC}"
    sync_directory "$SOURCE_BUILD" "$TARGET_BUILD" "build目录" "$REVERSE_MODE"
    sync_directory "$SOURCE_RAMDISK" "$TARGET_RAMDISK" "ramdisk目录" "$REVERSE_MODE"
    sync_directory "$SOURCE_ALIOS" "$TARGET_ALIOS" "alios目录" "$REVERSE_MODE"
fi
