
## Todo List

- [x] 2025-11-7: 已更新。2025-10-25: 目前使用的SDK版本是2025-09-26，待golden版本发布后更新。
- [x] 2025-11-7: 已更新。2025-10-25: alios 内部存在文件名变动，目前仍然用cv181x，待golden版本发布后切换为cv184x。
- [x] 2025-11-7: 已修复。 2025-10-25: ::bug:: alios 的驱动日志，是使用宏来定义日志走printf还是dmesg，由于驱动未释放源码，且目前是通过头文件中宏来定义日志，但在release的编译过程中宏被固定为`LOG_TO_DMESG`了，release版本无法通过配置将驱动日志以printf的方式输出。**需要改为函数，以便通过配置来控制输出方式**。为什么需要用printf呢？因为目前大核无法直接获取alios的dmesg日志，而这些日志中包含错误信息，对于一个项目来说，这些驱动日志也应该被记录到日志文件中，以便分析异常。目前我们的项目中，对于alios的日志处理是通过 `alios_cli -m 1 -c 0 2>&1 | logger -t alios -p local7.info &` 将alios的日志输出到 syslogd 并保存为文件，只有让驱动也走printf才能记录驱动的错误日志。如果有其他更好的办法也可以说明一下。
- [x] 2025-11-7: 已更新。2025-10-25: release 版本的busybox syslogd不支持吃`/etc/syslog.conf`，目前是在ramdisk中添加了一个busybox覆盖掉原版，待主线切换到golden版本后，再移除。
