#!/bin/bash

# 打印用法信息
function print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --gitclone xxx.xml      Clone the repo in xml file"
    echo "  --gitpull xxx.xml       Pull the repo in xml file"
    echo "  --run xxx.xml {cmd}     Run command in all repos specified in xml file"
    echo "  --hostslave             Fetch from server: 10.80.65.11"
    echo "  --normal                Clone the repo with all branches"
    echo "  --reproduce xxx.txt     Reproduce the repo as per the commit_id in xxx.txt"
    echo "  --applypatch xxx.txt    Apply patches from sophcam_bsp/patches directory"
    echo ""
    echo "Example:"
    echo "  $0 --gitclone cvi_manifest/golden/cv181x_cv180x_v4.1.0.xml"
    echo "  $0 --gitpull cvi_manifest/golden/cv181x_cv180x_v4.1.0.xml"
    echo "  $0 --gitclone cvi_manifest/golden/cv181x_cv180x_v4.1.0.xml --hostslave"
    echo "  $0 --gitclone cvi_manifest/golden/cv181x_cv180x_v4.1.0.xml --hostslave --normal"
    echo "  $0 --gitclone cvi_manifest/golden/cv181x_cv180x_v4.1.0.xml --hostslave --reproduce git_version_2023-08-18.txt"
    echo "  $0 --run cvi_manifest/golden/cv181x_cv180x_v4.1.0.xml git status"
    echo "  $0 --run cvi_manifest/golden/cv181x_cv180x_v4.1.0.xml st"
    echo "  $0 --applypatch ./sophcam_bsp/scripts/sdk-cv184x-2025-09-26.txt"
}

# 打印等级及颜色设置
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Define special characters
OK_STATUS=$'\u2714'   # ✅
FAIL_STATUS=$'\u274C' # ❌

# 判断传参数目是否合法
if [[ $# -lt 2 ]]; then
    print_usage
    exit 1
fi

# 判断当前目录是否包含.git文件；若包含，提出并退出脚本
if [[ ! " $@ " =~ " --force " ]] && [[ ! " $@ " =~ " --run " ]]; then
if [ -d ".git" ]; then
    echo -e "${YELLOW}Warning: $PWD contains a .git directory, which does not meet the code pulling requirement${NC}"
    echo -e "${YELLOW}Warning: Try again!${NC}"
    exit 1
fi
fi

# 获取 User Name
function get_user_name {
    USERNAME=$(git config --global user.name)
}
get_user_name

# git clone enable
DOWNLOAD=0

# normal clone enable
NORMAL=0

# reproduce enable
REPRODUCE=0

# git run enable
RUN=0

# apply patch enable
APPLYPATCH=0

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# 传入参数并赋值
while [[ $# -gt 0 ]]; do
   case $1 in
        --gitclone)
           shift
           xml_file=$1
           DOWNLOAD=1
           REMOTE_URL=$(grep -o '<remote.*/>' ${xml_file} | sed 's/.*fetch="\([^"]*\)".*/\1/' | sed "s/ssh:\/\/\(.*\)/ssh:\/\/$USERNAME@\1/")
           shift
           ;;
        --gitpull)
           shift
           xml_file=$1
           DOWNLOAD=0
           shift
           ;;
        --run)
           shift
           xml_file=$1
           RUN=1
           shift
           # 保存剩余的所有参数作为要执行的命令
           RUN_COMMAND=("$@")
           break
           ;;
        --hostslave)
           REMOTE_URL=$(grep -o '<remote.*/>' ${xml_file} | sed 's/.*fetch="\([^"]*\)".*/\1/' | sed "s/ssh:\/\/.*:/ssh:\/\/10.80.65.11:/" | sed "s/ssh:\/\/\(.*\)/ssh:\/\/$USERNAME@\1/")
           shift
           ;;
        --normal)
           NORMAL=1
           shift
           ;;
        --reproduce)
           shift
           gitver_txt=$1
           REPRODUCE=1
           shift
           ;;
        --applypatch)
           shift
           gitver_txt=$1
           APPLYPATCH=1
           shift
           ;;
        --force)
           shift
           ;;
        *)
           print_usage
           exit 1
           ;;
   esac
done

# 设置全局变量
if [[ -n "$xml_file" ]]; then
    REMOTE_NAME=$(grep -o '<remote.*/>' ${xml_file} | sed 's/.*name="\([^"]*\)".*/\1/')
    DEFAULT_REVISION=$(grep -o '<default.*/>' ${xml_file} | sed 's/.*revision="\([^"]*\)".*/\1/')
fi
PARAMETERS="--single-branch --depth 2000"

# git log function (参考 gits 脚本)
function git_log {
    # 获取当前分支名称
    current_branch=$(git rev-parse --abbrev-ref HEAD)

    # 获取默认远程仓库名称
    remote=$(git for-each-ref --format='%(upstream:short)' "$(git symbolic-ref -q HEAD)")
    remote_name=${remote%%/*}

    # 检查是否存在默认远程仓库
    if [ -z "$remote" ]; then
        echo -e "${YELLOW}当前分支没有追踪远程分支。${NC}"
    else
        # 检查本地是否有未推送的提交
        local_commits=$(git log ${remote}..HEAD --color --pretty=format:'%Cred%h%Creset - %s %Cgreen(%cr) <%an>%Creset')
        if [ -n "$local_commits" ]; then
            echo -e "${YELLOW}存在未同步到远程仓库的提交 (${FAIL_STATUS}):${NC}"
            echo "$local_commits"
        else
            echo -e "${GREEN}当前分支已经全部同步到远程仓库 (${OK_STATUS} ).${NC}"
        fi

        # 检查远程是否有未拉取的提交
        git fetch ${remote_name} >/dev/null 2>&1
        remote_commits=$(git log HEAD..${remote} --color --pretty=format:'%Cred%h%Creset - %s %Cgreen(%cr) <%an>%Creset')
        if [ -n "$remote_commits" ]; then
            echo -e "${RED}远程仓库存在未拉取的提交 (${FAIL_STATUS}):${NC}"
            echo "$remote_commits"
        else
            echo -e "${GREEN}远程仓库的提交已经全部拉取到本地 (${OK_STATUS} ).${NC}"
        fi
    fi
}

# git status function (参考 gits 脚本)
function st {
    # git status
    echo -e ""
    git_log
    echo -e "${BLUE}==========================================================================${NC}"
}

# release 函数
# 远程仓库名称（分支）: commit_id - commit_message (time) <author>
function release {
    echo -e ""
    git_log

    echo "project_name: $(git remote -v | grep "fetch" | awk -F'/' '{print $NF}' | awk -F'.git' '{print $1}')"
    echo "branch_name: $(git rev-parse --abbrev-ref HEAD)"
    echo "commit_id:"
    echo "$(git log --pretty=oneline -n 5)"
    echo -e "${BLUE}==========================================================================${NC}"
}

# git run function
function git_run {
    # 保存当前目录
    current_dir=$(pwd)

    # 逐行读取 XML 文件
    while IFS= read -r line
    do
        repo=$(echo "$line" | grep -o '<project name="[^"]*"' | sed 's/.*name="\([^"]*\)".*/\1/')
        path=$(echo "$line" | grep -o 'path="[^"]*"' | sed 's/.*path="\([^"]*\)".*/\1/')

        # 判断参数是否匹配到project行
        if [[ -z $repo ]]; then
            continue
        fi

        # 判断参数是否带有path
        if [[ -z $path ]]; then
            path=$repo
        fi

        # 检查目录是否存在
        if [[ ! -d $PWD/$path ]]; then
            echo -e "${RED}ERROR: target project not exist!! $PWD/$path${NC}"
            continue
        fi

        # 进入子目录
        cd "$path"

        # 检查子目录中是否存在.git目录
        if [ -d ".git" ]; then
            echo -e "${BLUE}Executing '${RUN_COMMAND[@]}', Current directory: $(pwd)${NC}"

            # 如果是 st 命令，调用 st 函数
            if [[ "${RUN_COMMAND[0]}" == "st" ]]; then
                st
            elif [[ "${RUN_COMMAND[0]}" == "release" ]]; then
                release
            else
                # 执行传递进来的命令
                "${RUN_COMMAND[@]}"
            fi
        else
            echo -e "${YELLOW}$path is not a git repository${NC}"
        fi

        # 返回初始目录
        cd "$current_dir"
    done < ${xml_file}

    echo "Operation completed for all repositories."
}

# git clone function
function git_clone {
    # 逐行读取 XML 文件
    while IFS= read -r line
    do
        repo=$(echo "$line" | grep -o '<project name="[^"]*"' | sed 's/.*name="\([^"]*\)".*/\1/')
        revision=$(echo "$line" | grep -o 'revision="[^"]*"' | sed 's/.*revision="\([^"]*\)".*/\1/')
        path=$(echo "$line" | grep -o 'path="[^"]*"' | sed 's/.*path="\([^"]*\)".*/\1/')
        sync=$(echo "$line" | grep -o 'sync-s="[^"]*"' | sed 's/.*sync-s="\([^"]*\)".*/\1/')
        remote_url=$(echo "$line" | grep -o 'remote_url="[^"]*"' | sed 's/.*remote_url="\([^"]*\)".*/\1/')
        alias_name=$(echo "$line" | grep -o 'alias="[^"]*"' | sed 's/.*alias="\([^"]*\)".*/\1/')
        soft_link=$(echo "$line" | grep -o 'soft_link="[^"]*"' | sed 's/.*soft_link="\([^"]*\)".*/\1/')

        # 判断参数是否匹配到project行
        if [[ -z $repo ]]; then
            continue
        fi

        # 判断参数是否带有revision
        if [[ -z $revision ]]; then
            revision=$DEFAULT_REVISION
        fi

        # 判断参数是否带有path
        if [[ -z $path ]]; then
            path=$repo
        fi

        # 判断参数是否带有remote_url
        if [[ -z $remote_url ]]; then
            remote_url=$REMOTE_URL
        fi

        # 判断是否已经下载了repo
        if [[ -d $PWD/$path ]]; then
            echo -e "${YELLOW}Warning: target porject already exist!! $PWD/$path${NC}"
            continue
        fi

        # 判断参数是否带有normal
        if [ $NORMAL == 0 ]; then
            git clone $remote_url$repo.git $PWD/$path -b $revision $PARAMETERS
        else
            git clone $remote_url$repo.git $PWD/$path
            pushd $PWD/$path
                git checkout $revision
            popd
        fi

        # 将 commit-msg 文件添加到 .git/hooks/ 目录下
        # cp $SCRIPT_DIR/commit-msg $PWD/$path/.git/hooks/commit-msg

        # 替换 .git/config 中的 10.80.65.11 为 gerrit-ai.sophgo.vip
        sed -i 's/10.80.65.11/gerrit-ai.sophgo.vip/g' $PWD/$path/.git/config

        # repo name 应该是 $repo 按 / 分割的最后一个元素
        repo_name=$(echo $repo | awk -F '/' '{print $NF}')
        # 判断参数是否带有alias_name
        if ! [[ -z $alias_name ]]; then
            repo_name=$alias_name
        fi

        # 如果带有软链接参数，且软连接参数为 "no" 则不创建软连接
        if [[ ! -z $soft_link ]] && [[ $soft_link == "no" ]]; then
            echo -e "${BLUE}Info: Skip soft link for $repo_name ${NC}"
        else
            # 如果有指定 path，且并非在当前目录下，创建软连接
            if [[ ! -z $path ]] && [[ $PWD/$path != $PWD/$repo_name ]]; then
                ln -sf ./$path $repo_name
            fi
        fi

        # 判断参数是否带有sync-s
        if [[ "$sync" == "true" ]]; then
            echo -e "${YELLOW}Warning: Pay attention to managing $repo/, as it requires submodule management${NC}"
            pushd $PWD/$path
                git submodule update --init
            popd
        fi
    done < ${xml_file}
}

# git pull function
function git_pull {
    # 逐行读取 XML 文件
    while IFS= read -r line
    do
        repo=$(echo "$line" | grep -o '<project name="[^"]*"' | sed 's/.*name="\([^"]*\)".*/\1/')
        revision=$(echo "$line" | grep -o 'revision="[^"]*"' | sed 's/.*revision="\([^"]*\)".*/\1/')
        path=$(echo "$line" | grep -o 'path="[^"]*"' | sed 's/.*path="\([^"]*\)".*/\1/')

        # 判断参数是否匹配到project行
        if [[ -z $repo ]]; then
            continue
        fi

        # 判断参数是否带有revision
        if [[ -z $revision ]]; then
            revision=$DEFAULT_REVISION
        fi

        # 判断参数是否带有path
        if [[ -z $path ]]; then
            path=$repo
        fi

        if [[ ! -d $PWD/$path ]]; then
            echo -e "${RED}ERROR: target porject not exist!! $PWD/$path${NC}"
            continue
        fi

        pushd $PWD/$path
            git checkout .
            git clean -f .
            git reset --hard $REMOTE_NAME/$revision
            git pull
        popd
    done < ${xml_file}
}


function get_commit_id {
    local Project_name="$1"
    local File=$2
    local Commit_id=""

    # 使用awk搜索文件，找到匹配的project_name并提取commit_id
    Commit_id=$(awk -v proj="$Project_name" '
        /^project_name: / {
            if ($2 == proj) {
                found = 1;
                next;
            }
            found = 0;
        }
        found && /^commit_id: / {
            split($0, parts, " ");  # 将整行按空格拆分
            print parts[2];         # 打印第二个字段，即提交 ID
            exit;                   # 找到后退出awk,避免打印多余信息
        }
    ' "$File")

    echo "$Commit_id"
}

# git reproduce function
function reproduce_repo {
    # 逐行读取 XML 文件
    while IFS= read -r line
    do
        repo=$(echo "$line" | grep -o '<project name="[^"]*"' | sed 's/.*name="\([^"]*\)".*/\1/')
        path=$(echo "$line" | grep -o 'path="[^"]*"' | sed 's/.*path="\([^"]*\)".*/\1/')

        # 判断参数是否匹配到project行
        if [[ -z $repo ]]; then
            continue
        fi

        commit_id=$(get_commit_id $(basename ${repo}) ${gitver_txt})

        # 判断是否从txt中读取到commit_id
        if [[ -z $commit_id ]]; then
            continue
        fi

        echo -e "\nReproduce: ""${repo}" " reset to " "${commit_id}"

        # 判断参数是否带有path
        if [[ -z $path ]]; then
            path=$repo
        fi

        if [[ ! -d $PWD/$path ]]; then
            echo -e "${RED}ERROR: target porject not exist!! $PWD/$path${NC}"
            continue
        fi

        pushd $PWD/$path
            git reset --hard "${commit_id}" ||
            {
                echo "${RED}ERROR: Unable to reset to project ${repo}${NC}";
                echo "${RED}ERROR: Unable to reset to commit ${commit_id}${NC}";
                exit 1;
            }
        popd
    done < ${xml_file}
}

# git apply patch function
function git_applypatch {
    # 获取patches目录路径
    patches_dir="$SCRIPT_DIR/../patches"

    # 检查patches目录是否存在
    if [[ ! -d $patches_dir ]]; then
        echo -e "${RED}错误: 未找到patches目录: $patches_dir${NC}"
        exit 1
    fi

    # 将txt文件路径转换为绝对路径
    gitver_txt_abs=$(cd $(dirname "$gitver_txt") && pwd)/$(basename "$gitver_txt")

    # 检查txt文件是否存在
    if [[ ! -f $gitver_txt_abs ]]; then
        echo -e "${RED}错误: 未找到git版本文件: $gitver_txt_abs${NC}"
        exit 1
    fi

    # 保存当前目录
    current_dir=$(pwd)

    # 创建一个临时文件来存储唯一的仓库名称
    temp_file=$(mktemp)

    # 获取patches目录下所有的patch文件，提取唯一的仓库名称
    for patch_file in "$patches_dir"/*.patch; do
        if [[ -f $patch_file ]]; then
            # 提取仓库名称（patch文件名的前缀）
            repo_name=$(basename "$patch_file" | cut -d'-' -f1)
            # 将仓库名称添加到临时文件
            echo "$repo_name" >> "$temp_file"
        fi
    done

    # 对临时文件中的仓库名称进行去重
    sort -u "$temp_file" -o "$temp_file"

    # 读取临时文件，处理每个唯一的仓库
    while read -r repo_name; do
        # 直接使用仓库名称作为路径，不再从XML中获取
        local repo_path="$repo_name"

        if [[ -d "$PWD/$repo_path" ]]; then
            echo -e "\n${BLUE}正在处理仓库: $repo_path${NC}"

            # 进入仓库目录
            pushd "$PWD/$repo_path" > /dev/null

            # 检查是否有未提交的改动
            local has_uncommitted_changes=0
            if [[ -n $(git status --porcelain) ]]; then
                has_uncommitted_changes=1
                echo -e "${YELLOW}警告: 仓库 $repo_path 存在未提交的修改${NC}"
            fi

            # 获取当前commit-id
            local current_commit_id=$(git rev-parse HEAD)

            # 从txt文件中获取期望的commit-id
            local expected_commit_id=$(get_commit_id "$repo_name" "$gitver_txt_abs")
            echo -e "${BLUE}仓库 $repo_path 的期望commit-id: $expected_commit_id${NC}"

            # 检查commit-id是否匹配
            local commit_id_mismatch=0
            if [[ -n $expected_commit_id ]] && [[ "$current_commit_id" != "$expected_commit_id" ]]; then
                commit_id_mismatch=1
                echo -e "${YELLOW}警告: 仓库 $repo_path 的commit-id不匹配${NC}"
                echo -e "${YELLOW}  当前: $current_commit_id${NC}"
                echo -e "${YELLOW}  期望: $expected_commit_id${NC}"
            fi

            # 如果有未提交的改动或commit-id不匹配，提示用户
            if [[ $has_uncommitted_changes -eq 1 ]] || [[ $commit_id_mismatch -eq 1 ]]; then
                echo -e "${YELLOW}‼️是否要继续应用patch，继续将会丢弃本地改动? (y/n)${NC}"
                # 清空输入缓冲区并从终端读取输入
                read -r continue_apply </dev/tty

                if [[ "$continue_apply" != "y" ]] && [[ "$continue_apply" != "Y" ]]; then
                    echo -e "${BLUE}跳过仓库 $repo_path 的补丁应用${NC}"
                    popd > /dev/null
                    continue
                fi

                # 如果commit-id不匹配，重置到期望的commit-id
                if [[ $commit_id_mismatch -eq 1 ]] && [[ -n $expected_commit_id ]]; then
                    echo -e "${BLUE}正在将仓库 $repo_path 重置到提交: $expected_commit_id${NC}"
                    git reset --hard "$expected_commit_id" || {
                        echo -e "${RED}重置仓库 $repo_path 失败${NC}"
                        popd > /dev/null
                        continue
                    }
                fi
            fi

            # 应用所有与该仓库相关的patch
            echo -e "${BLUE}正在为仓库应用补丁: $repo_path${NC}"
            for repo_patch_file in "$patches_dir"/${repo_name}-*.patch; do
                if [[ -f "$repo_patch_file" ]]; then
                    echo -e "${GREEN}正在应用补丁: $(basename "$repo_patch_file")${NC}"
                    git am --keep --ignore-whitespace "$repo_patch_file" || {
                        echo -e "${RED}应用补丁失败: $(basename "$repo_patch_file")${NC}"
                        # 尝试使用git am --reject
                        echo -e "${YELLOW}尝试使用git am --reject...${NC}"
                        git am --abort
                        git am --reject --ignore-whitespace "$repo_patch_file" || {
                            echo -e "${RED}使用git am --reject应用补丁失败: $(basename "$repo_patch_file")${NC}"
                            git am --abort
                        }
                    }
                fi
            done

            # 返回初始目录
            popd > /dev/null
        else
            echo -e "${YELLOW}警告: 在SDK路径中未找到仓库 $repo_name${NC}"
            echo -e "${YELLOW}请在当前SDK路径中创建指向该仓库的软链接${NC}"
        fi
    done < "$temp_file"

    # 清理临时文件
    rm -f "$temp_file"

    echo -e "\n${GREEN}补丁应用过程已完成${NC}"
}

function main {
    # 如果启用了 git run 功能，只执行 git_run 函数
    if [ $RUN -eq 1 ]; then
        git_run
        return
    fi

    # 如果启用了 apply patch 功能，只执行 git_applypatch 函数
    if [ $APPLYPATCH -eq 1 ]; then
        git_applypatch
        return
    fi

    if [ $DOWNLOAD -eq 1 ]; then
        git_clone
    else
        git_pull
    fi

    # 复现git_version.txt中的所有仓库
    if [ $REPRODUCE -eq 1 ]; then
        reproduce_repo
    fi
}

main
