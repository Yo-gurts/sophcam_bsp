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
    echo ""
    echo "Example:"
    echo "  $0 --gitclone cvi_manifest/golden/cv181x_cv180x_v4.1.0.xml"
    echo "  $0 --gitpull cvi_manifest/golden/cv181x_cv180x_v4.1.0.xml"
    echo "  $0 --gitclone cvi_manifest/golden/cv181x_cv180x_v4.1.0.xml --hostslave"
    echo "  $0 --gitclone cvi_manifest/golden/cv181x_cv180x_v4.1.0.xml --hostslave --normal"
    echo "  $0 --gitclone cvi_manifest/golden/cv181x_cv180x_v4.1.0.xml --hostslave --reproduce git_version_2023-08-18.txt"
    echo "  $0 --run cvi_manifest/golden/cv181x_cv180x_v4.1.0.xml git status"
    echo "  $0 --run cvi_manifest/golden/cv181x_cv180x_v4.1.0.xml st"
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
        cp $SCRIPT_DIR/commit-msg $PWD/$path/.git/hooks/commit-msg

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

function main {
    # 如果启用了 git run 功能，只执行 git_run 函数
    if [ $RUN -eq 1 ]; then
        git_run
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
