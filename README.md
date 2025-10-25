# Nana project

Chip: cv1842cp
Toolchain: musl_arm32
Board: sophcam

## 代码拉取

‼️不要尝试更改相对路径，按照步骤来！
‼️使用reproduce切换到特定版本的SDK，否则可能出现patch冲突！

```bash
mkdir v6.x.x && cd v6.x.x

# 拉取项目代码
git clone git@github.com:Yo-gurts/sophcam_bsp.git

# 拉取 SDK 代码
./sophcam_bsp/scripts/repos.sh --gitclone ./sophcam_bsp/scripts/sdk-cv184x.xml --reproduce ./sophcam_bsp/scripts/sdk-cv184x-2025-09-26.txt

# 同步板卡配置到 SDK （注意这个脚本的运行位置需要固定）
./sophcam_bsp/scripts/sync.sh
```

✨可以使用下面的命令在检查SDK的状态：

```bash
# 检查SDK本地提交和远端的差异
./sophcam_bsp/scripts/repos.sh --run ./sophcam_bsp/scripts/sdk-cv184x.xml st

# 在每个git仓库中执行命令
./sophcam_bsp/scripts/repos.sh --run ./sophcam_bsp/scripts/sdk-cv184x.xml git status
```

## SDK 编译

```bash
# TDL SDK 编译有报错
export TPU_REL=0; source build/envsetup_soc.sh
defconfig cv1842cp_sophcam_spinand

clean_all && build_all
```
