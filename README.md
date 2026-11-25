# MySQL 服务控制（Windows）

<p align="center"><img src="icon.png" width="96" alt="icon"></p>

一个**单文件、零依赖**的 Windows 批处理小工具：双击就能启停 MySQL / MariaDB 服务、切换开机自启、查看端口占用，不用再开 `services.msc`，也不用记服务名。

> 适合本机开发、学习环境里把 MySQL 当“用的时候再开”的人：平时手动启动，不占开机时间；需要时一键拉起。

```
================================================================
                    MySQL 服务控制  v1.0.1
================================================================
   服务名   : MySQL97
   显示名   : MySQL97
   当前状态 : 已停止  (STOPPED)
   启动类型 : 手动  (DEMAND_START)
   进程 PID : 0
   端口 3306  : 未被监听
----------------------------------------------------------------
    [1] 启动服务
    [2] 停止服务
    [3] 重启服务
    [4] 刷新状态
    [5] 关闭开机自启（改为手动）
    [6] 开启开机自启（改为自动）
    [7] 查看端口占用（只读）
    [8] 切换服务
    [9] 清理非服务的 mysqld（危险）
    [0] 退出
================================================================
```

## 特性

- **单文件、零依赖**：就是一个 `.bat`，拷到哪都能跑，不需要 Node / Python / .NET。
- **自动提权**：双击运行会自己弹 UAC 申请管理员权限，失败有明确提示，不会无限重试。
- **自动识别服务**：服务名不用写死。名字里带 `mysql` / `mariadb` 的服务会被自动找到；有多个时列出来让你选，并记住选择。
- **状态可视化**：服务状态、启动类型、进程 PID、端口是否被监听，一屏看完。
- **启动失败说人话**：启动失败时自动检查端口，直接告诉你被哪个 PID 占着。
- **菜单 + 命令行双模式**：日常用菜单；写脚本、做计划任务用子命令。
- **危险操作有二次确认**：清理非服务 `mysqld` 进程需要输入 `YES` 才会执行。

## 环境要求

| 项目 | 要求 |
| --- | --- |
| 系统 | Windows 10 1809+ / Windows 11 |
| 脚本依赖 | 无（仅使用系统自带 `sc`、`net`、`tasklist`、`netstat`、`powershell`） |
| MySQL | 5.7 / 8.0 / 9.x，MariaDB 亦可（服务需已安装） |
| 文件编码 | GBK / 936（脚本内 `chcp 936`），请勿另存为 UTF-8，详见 FAQ |

## 快速开始

1. 下载或克隆本仓库。
2. 双击 `mysql-service-control.bat`。
3. UAC 弹窗点“是”。
4. 按提示输入编号。

首次运行会自动扫描服务；如果机器上有多个 MySQL 服务，会让你选一个。

## 菜单说明

| 编号 | 功能 | 说明 |
| --- | --- | --- |
| 1 | 启动服务 | 已在运行会直接提示，不会报错 |
| 2 | 停止服务 | 已在停止会直接提示 |
| 3 | 重启服务 | 停止失败会中止，不会出现“假重启” |
| 4 | 刷新状态 | 重新读取状态、PID、端口 |
| 5 | 关闭开机自启 | 等价于 `sc config <服务> start= demand` |
| 6 | 开启开机自启 | 等价于 `sc config <服务> start= auto` |
| 7 | 查看端口占用 | 只读，显示占用 3306 的进程 PID 和名称 |
| 8 | 切换服务 | 重新扫描并选择服务，选择结果会保存 |
| 9 | 清理非服务的 mysqld | 危险：强制结束不属于服务实例的 `mysqld.exe` |

## 命令行用法

```bat
mysql-service-control.bat                  :: 打开菜单（推荐）
mysql-service-control.bat status  [服务名]  :: 查看状态（不需要管理员）
mysql-service-control.bat list              :: 列出所有 MySQL / MariaDB 服务
mysql-service-control.bat port    [服务名]  :: 查看端口占用
mysql-service-control.bat start   [服务名]  :: 启动
mysql-service-control.bat stop    [服务名]  :: 停止
mysql-service-control.bat restart [服务名]  :: 重启
mysql-service-control.bat auto    [服务名]  :: 设为开机自启
mysql-service-control.bat manual  [服务名]  :: 取消开机自启
mysql-service-control.bat clean   [服务名]  :: 清理非服务 mysqld（危险）
```

示例：

```bat
mysql-service-control.bat start MySQL97
set MYSQL_SVC=MySQL80 && mysql-service-control.bat restart
```

退出码：`0` 成功，`1` 失败，`2` 找不到服务。

## 服务名是怎么确定的

按优先级依次尝试：

1. 命令行第二个参数：`... start MySQL80`
2. 环境变量：`MYSQL_SVC=MySQL80`
3. 同目录下的 `mysql-svc.ini`（菜单里选择后自动写入）
4. 自动扫描名称包含 `mysql` / `mariadb` 的服务：唯一则直接用，多个则让你选

`mysql-svc.ini` 长这样，可以手动改：

```ini
SVC=MySQL97
PORT=3306
```

`PORT` 只用于端口占用显示和启动失败诊断，不改变 MySQL 配置。

## 常见问题

**双击没反应 / 一闪而过**
文件属性里可能被标记为“来自网络”，右键 → 属性 → 勾选“解除锁定”；或者被 SmartScreen 拦截，点“更多信息”→“仍要运行”。

**提示“找不到服务”**
先 `Win+R` → `services.msc` 确认服务名，然后用参数指定，例如：
`mysql-service-control.bat status MySQL80`。

**启动失败，提示端口被占用**
先用菜单 `[7]` 看是谁占着端口。常见是上次异常退出残留的 `mysqld.exe`，确认后可以用 `[9]` 清理（会二次确认）。

**UAC 弹窗点了“否”**
脚本会提示提权失败并退出，重新双击重来即可。

**公司电脑禁用了 PowerShell**
提权依赖系统自带的 PowerShell 5.1。被禁用时会提示失败，此时请右键 →“以管理员身份运行”。

**GitHub 上源码显示乱码？**
这是正常现象。脚本以 GBK(936) 编码保存，cmd 才能稳定读取中文——若改成 UTF-8 并用 `chcp 65001`，cmd 读取含中文的批处理行时会发生字节错位，表现为菜单某几行被切碎、半行被当成命令执行（`'...' is not recognized`）。GitHub 按 UTF-8 渲染源码所以显示乱码，**下载到本地运行不受影响**。

**中文显示成方块**
说明控制台字体不支持中文，在窗口标题栏右键 → 属性 → 字体，换成“新宋体”等中文字体即可。

## 安全与边界

- 脚本只做服务层面的操作（`net start/stop`、`sc config`、`taskkill`），**不修改 MySQL 配置、不碰数据目录**。
- `[9]` 会强制结束进程，可能影响你手动起的第二个 MySQL 实例。请确认后再执行；数据安全建议先正常停止。
- 提权后会以管理员身份运行，请只在可信环境下使用；不在仓库中分发任何可执行文件。

## 卸载

删除 `mysql-service-control.bat`（和可选的 `mysql-svc.ini`）即可。对服务做的改动（自启类型等）可在菜单 `[5]` / `[6]` 改回，或直接 `services.msc` 调整。

## License

[MIT](LICENSE)
