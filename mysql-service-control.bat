@echo off
rem ==================================================================
rem  mysql-service-control.bat  v1.0.2
rem  Windows 上 MySQL / MariaDB 服务控制面板（单文件、零依赖）
rem  双击运行会自动申请管理员权限。
rem  License: MIT
rem ==================================================================
chcp 936 >nul 2>&1
setlocal EnableExtensions DisableDelayedExpansion

set "APP_VER=1.0.2"
set "BASE_DIR=%~dp0"
if "%BASE_DIR:~-1%"=="\" set "BASE_DIR=%BASE_DIR:~0,-1%"
set "CFG_FILE=%BASE_DIR%\mysql-svc.ini"
set "ALLARGS=%*"
set "SVC="
set "PORT=3306"
set "RCODE=0"
set "INTERACTIVE="

title MySQL 服务控制 v%APP_VER%

set "ARG_CMD=%~1"
set "ARG_SVC=%~2"

rem ---------------- 0. 帮助 ----------------
if /i "%ARG_CMD%"=="help"   goto :usage
if /i "%ARG_CMD%"=="-h"     goto :usage
if /i "%ARG_CMD%"=="/?"     goto :usage
if /i "%ARG_CMD%"=="--help" goto :usage

rem ---------------- 1. 无参数：进入交互菜单 ----------------
if "%ARG_CMD%"=="" (
    set "INTERACTIVE=1"
    call :resolve_service
    if errorlevel 1 exit /b 2
    call :ensure_admin
    if errorlevel 1 exit /b 1
    goto :menu
)

rem ---------------- 2. 校验命令，未知命令不触发提权 ----------------
set "KNOWN="
for %%C in (status list port start stop restart auto manual clean switch) do if /i "%ARG_CMD%"=="%%C" set "KNOWN=1"
if not defined KNOWN (
    echo.
    echo [错误] 未知命令: %ARG_CMD%
    call :usage
    exit /b 1
)

rem ---------------- 3. 确定要操作哪个服务 ----------------
call :resolve_service
if errorlevel 1 exit /b 2

rem ---------------- 4. 只读命令，不需要管理员权限 ----------------
if /i "%ARG_CMD%"=="status" goto :cmd_status
if /i "%ARG_CMD%"=="list"   goto :cmd_list
if /i "%ARG_CMD%"=="port"   goto :cmd_port

rem ---------------- 5. 其余命令都需要管理员权限 ----------------
call :ensure_admin
if errorlevel 1 exit /b 1

if /i "%ARG_CMD%"=="start"   goto :do_start
if /i "%ARG_CMD%"=="stop"    goto :do_stop
if /i "%ARG_CMD%"=="restart" goto :do_restart
if /i "%ARG_CMD%"=="auto"    goto :do_auto
if /i "%ARG_CMD%"=="manual"  goto :do_manual
if /i "%ARG_CMD%"=="clean"   goto :do_clean
if /i "%ARG_CMD%"=="switch"  goto :do_switch

echo.
echo [错误] 未知命令: %ARG_CMD%
echo.
goto :usage


rem ==================================================================
rem  菜单
rem ==================================================================
:menu
cls
call :getinfo
call :port_info
echo ================================================================
echo                     MySQL 服务控制  v%APP_VER%
echo ================================================================
echo    服务名   : %SVC%
echo    显示名   : %DISPLAYNAME%
echo    当前状态 : %STS%  (%ST%)
echo    启动类型 : %TYPES%  (%STYPE%)
echo    进程 PID : %PID%
echo    端口 %PORT%  : %PORT_STATUS%
echo ----------------------------------------------------------------
echo     [1] 启动服务
echo     [2] 停止服务
echo     [3] 重启服务
echo     [4] 刷新状态
echo     [5] 关闭开机自启（改为手动）
echo     [6] 开启开机自启（改为自动）
echo     [7] 查看端口占用（只读）
echo     [8] 切换服务
echo     [9] 清理非服务的 mysqld（危险）
echo     [0] 退出
echo ================================================================

set "CH="
set /p "CH=请输入编号后回车: "
if not defined CH goto :bye
set "CH=%CH: =%"
if "%CH%"=="1" goto :do_start
if "%CH%"=="2" goto :do_stop
if "%CH%"=="3" goto :do_restart
if "%CH%"=="4" goto :menu
if "%CH%"=="5" goto :do_manual
if "%CH%"=="6" goto :do_auto
if "%CH%"=="7" goto :do_port
if "%CH%"=="8" goto :do_switch
if "%CH%"=="9" goto :do_clean
if "%CH%"=="0" goto :bye
goto :menu


rem ==================================================================
rem  动作：启动
rem ==================================================================
:do_start
call :getinfo
if /i "%ST%"=="RUNNING" (
    echo.
    echo 服务已经在运行，无需启动。PID = %PID%
    set "RCODE=0"
    goto :finish
)
echo.
echo 正在启动 %SVC% ...
net start "%SVC%"
if errorlevel 1 (
    echo.
    echo [提示] 启动失败，常见原因:
    echo        1. 端口 %PORT% 被其他程序占用
    echo        2. my.ini / 数据目录配置有误
    echo        3. 数据目录权限不足
    echo.
    call :show_port_owner
    set "RCODE=1"
) else (
    echo 启动完成。
    set "RCODE=0"
)
goto :finish


rem ==================================================================
rem  动作：停止
rem ==================================================================
:do_stop
call :getinfo
if /i "%ST%"=="STOPPED" (
    echo.
    echo 服务已经停止，无需操作。
    set "RCODE=0"
    goto :finish
)
echo.
echo 正在停止 %SVC% ...
net stop "%SVC%" /y
if errorlevel 1 (
    echo.
    echo [提示] 停止失败，可能有程序正在连接数据库，稍后再试。
    set "RCODE=1"
) else (
    echo 已停止。
    set "RCODE=0"
)
goto :finish


rem ==================================================================
rem  动作：重启
rem ==================================================================
:do_restart
call :getinfo
if /i "%ST%"=="RUNNING" (
    echo.
    echo 正在停止 %SVC% ...
    net stop "%SVC%" /y
    if errorlevel 1 (
        echo.
        echo [错误] 停止失败，已中止重启（服务仍在运行）。
        set "RCODE=1"
        goto :finish
    )
)
echo.
echo 正在启动 %SVC% ...
net start "%SVC%"
if errorlevel 1 (
    echo.
    echo [提示] 启动失败，常见原因:
    echo        1. 端口 %PORT% 被其他程序占用
    echo        2. my.ini / 数据目录配置有误
    echo        3. 数据目录权限不足
    echo.
    call :show_port_owner
    set "RCODE=1"
) else (
    echo 重启完成。
    set "RCODE=0"
)
goto :finish


rem ==================================================================
rem  动作：改为手动
rem ==================================================================
:do_manual
call :getinfo
if /i "%STYPE%"=="DEMAND_START" (
    echo.
    echo 启动类型已经是“手动”，开机不会自启。
    set "RCODE=0"
    goto :finish
)
sc config "%SVC%" start= demand >nul
if errorlevel 1 (
    echo.
    echo [错误] 修改失败，请确认窗口有管理员权限。
    set "RCODE=1"
) else (
    echo.
    echo 已改为“手动”: 开机不再自动启动 %SVC%。
    set "RCODE=0"
)
goto :finish


rem ==================================================================
rem  动作：改为自动
rem ==================================================================
:do_auto
call :getinfo
if /i "%STYPE%"=="AUTO_START" (
    echo.
    echo 启动类型已经是“自动”。
    set "RCODE=0"
    goto :finish
)
sc config "%SVC%" start= auto >nul
if errorlevel 1 (
    echo.
    echo [错误] 修改失败，请确认窗口有管理员权限。
    set "RCODE=1"
) else (
    echo.
    echo 已改为“自动”: 开机会自动启动 %SVC%。
    set "RCODE=0"
)
goto :finish


rem ==================================================================
rem  动作：查看端口占用
rem ==================================================================
:do_port
call :port_info
echo.
echo 端口 %PORT% 状态: %PORT_STATUS%
if defined PORT_PID (
    call :pid_name %PORT_PID%
    echo 占用进程 PID : %PORT_PID%
    echo 占用进程名称 : %PNAME%
)
goto :finish


rem ==================================================================
rem  动作：切换服务
rem ==================================================================
:do_switch
call :scan_services
if "%CNT%"=="0" (
    echo.
    echo 未发现任何名称包含 mysql 或 mariadb 的服务。
    echo 请先用 services.msc 确认服务是否已安装。
    set "RCODE=1"
    goto :finish
)
call :pick
if errorlevel 1 (
    echo 已取消。
    set "RCODE=0"
    goto :finish
)
call :save_cfg
echo.
echo 已切换并记住服务: %SVC%
set "RCODE=0"
goto :finish


rem ==================================================================
rem  动作：清理非服务实例
rem ==================================================================
:do_clean
call :getinfo
if /i not "%ST%"=="RUNNING" (
    echo.
    echo 服务当前没有运行，无法确定该保留哪个实例，已跳过。
    echo 请先用 [1] 启动服务，再来清理。
    set "RCODE=1"
    goto :finish
)
set "SVCPID=%PID%"
if "%SVCPID%"=="0" set "SVCPID="
if not defined SVCPID (
    echo.
    echo 读不到服务实例 PID，已跳过。
    set "RCODE=1"
    goto :finish
)

echo.
echo 服务实例 PID = %SVCPID%
echo 正在检查其他 mysqld 进程 ...
set "OTHERS="
for /f "tokens=2 delims=," %%P in ('tasklist /fi "imagename eq mysqld.exe" /fo csv /nh 2^>nul') do call :check_other "%%~P"

if not defined OTHERS (
    echo.
    echo 没有发现多余的 mysqld，环境是干净的。
    set "RCODE=0"
    goto :finish
)

echo.
set "YN="
set /p "YN=以上进程会被强制结束，输入 YES 继续（其他任意键取消）: "
if /i not "%YN%"=="YES" (
    echo 已取消，未做任何修改。
    set "RCODE=0"
    goto :finish
)

echo.
for /f "tokens=2 delims=," %%P in ('tasklist /fi "imagename eq mysqld.exe" /fo csv /nh 2^>nul') do call :kill_other "%%~P"

echo.
echo 重启服务，让服务实例重新占住端口 %PORT% ...
net stop "%SVC%" /y >nul 2>&1
net start "%SVC%"
if errorlevel 1 (
    echo [提示] 服务重启失败，请检查端口 %PORT% 是否还被别的程序占用。
    set "RCODE=1"
) else (
    echo 清理完成。
    set "RCODE=0"
)
goto :finish


rem ==================================================================
rem  命令行模式
rem ==================================================================
:cmd_status
call :getinfo
call :port_info
call :print_status
exit /b 0

:cmd_port
call :port_info
echo 服务: %SVC%
echo 端口 %PORT%: %PORT_STATUS%
if defined PORT_PID (
    call :pid_name %PORT_PID%
    echo 占用进程 PID : %PORT_PID%
    echo 占用进程名称 : %PNAME%
)
exit /b 0

:cmd_list
call :scan_services
if "%CNT%"=="0" (
    echo 未发现名称包含 mysql / mariadb 的服务。
    exit /b 1
)
echo 已发现的服务（* 为当前使用）:
if defined C1 ( if /i "%C1%"=="%SVC%" (echo   * %C1%) else (echo     %C1%) )
if defined C2 ( if /i "%C2%"=="%SVC%" (echo   * %C2%) else (echo     %C2%) )
if defined C3 ( if /i "%C3%"=="%SVC%" (echo   * %C3%) else (echo     %C3%) )
if defined C4 ( if /i "%C4%"=="%SVC%" (echo   * %C4%) else (echo     %C4%) )
if defined C5 ( if /i "%C5%"=="%SVC%" (echo   * %C5%) else (echo     %C5%) )
if defined C6 ( if /i "%C6%"=="%SVC%" (echo   * %C6%) else (echo     %C6%) )
if defined C7 ( if /i "%C7%"=="%SVC%" (echo   * %C7%) else (echo     %C7%) )
if defined C8 ( if /i "%C8%"=="%SVC%" (echo   * %C8%) else (echo     %C8%) )
if defined C9 ( if /i "%C9%"=="%SVC%" (echo   * %C9%) else (echo     %C9%) )
if defined MORE echo   ... 候选超过 9 个，只显示前 9 个
exit /b 0


rem ==================================================================
rem  结束处理
rem ==================================================================
:finish
if defined INTERACTIVE (
    echo.
    pause
    goto :menu
)
exit /b %RCODE%

:bye
echo.
echo 再见。
exit /b 0


rem ==================================================================
rem  服务名解析
rem ==================================================================
:resolve_service
if not "%ARG_SVC%"=="" (
    set "SVC=%ARG_SVC%"
    goto :rs_verify
)
if not "%MYSQL_SVC%"=="" (
    set "SVC=%MYSQL_SVC%"
    goto :rs_verify
)
if exist "%CFG_FILE%" call :read_cfg
if not "%SVC%"=="" goto :rs_verify
call :discover
if errorlevel 1 exit /b 1
:rs_verify
sc query "%SVC%" >nul 2>&1
if errorlevel 1 (
    echo.
    echo [错误] 找不到服务: %SVC%
    echo        请确认 MySQL 已安装、服务已创建。
    echo        查服务名: Win+R 输入 services.msc
    echo        也可以直接指定: mysql-service-control.bat status 你的服务名
    exit /b 1
)
exit /b 0


:read_cfg
for /f "usebackq tokens=1,* delims==" %%A in ("%CFG_FILE%") do (
    if /i "%%A"=="SVC"  set "SVC=%%B"
    if /i "%%A"=="PORT" set "PORT=%%B"
)
exit /b


:discover
call :scan_services
if "%CNT%"=="0" goto :disc_none
if "%CNT%"=="1" (
    set "SVC=%C1%"
    call :save_cfg
    exit /b 0
)
call :pick
exit /b

:disc_none
echo.
echo [错误] 没有发现 MySQL 或 MariaDB 服务。
echo        请确认服务已安装，或手动指定服务名。
exit /b 1


:scan_services
set "C1="
set "C2="
set "C3="
set "C4="
set "C5="
set "C6="
set "C7="
set "C8="
set "C9="
set "MORE="
set "CNT=0"
set "SCAN_TMP=%TEMP%\msc_scan_%RANDOM%%RANDOM%.tmp"
sc query state= all > "%SCAN_TMP%" 2>nul
if not exist "%SCAN_TMP%" exit /b 1
for /f "usebackq tokens=1,* delims=:" %%A in ("%SCAN_TMP%") do call :maybe_cand "%%A" "%%B"
del "%SCAN_TMP%" >nul 2>&1
set "SCAN_TMP="
exit /b 0


:maybe_cand
if /i not "%~1"=="SERVICE_NAME" exit /b
set "T=%~2"
if not "%T%"=="" for /f "tokens=* delims= " %%X in ("%T%") do set "T=%%X"
echo %T%| findstr /i /c:"mysql" /c:"mariadb" >nul
if errorlevel 1 exit /b
if not defined C1 (set "C1=%T%" & set /a CNT+=1 & exit /b)
if not defined C2 (set "C2=%T%" & set /a CNT+=1 & exit /b)
if not defined C3 (set "C3=%T%" & set /a CNT+=1 & exit /b)
if not defined C4 (set "C4=%T%" & set /a CNT+=1 & exit /b)
if not defined C5 (set "C5=%T%" & set /a CNT+=1 & exit /b)
if not defined C6 (set "C6=%T%" & set /a CNT+=1 & exit /b)
if not defined C7 (set "C7=%T%" & set /a CNT+=1 & exit /b)
if not defined C8 (set "C8=%T%" & set /a CNT+=1 & exit /b)
if not defined C9 (set "C9=%T%" & set /a CNT+=1 & exit /b)
set "MORE=1"
exit /b


:pick
echo.
echo 发现多个候选服务:
if defined C1 echo   1) %C1%
if defined C2 echo   2) %C2%
if defined C3 echo   3) %C3%
if defined C4 echo   4) %C4%
if defined C5 echo   5) %C5%
if defined C6 echo   6) %C6%
if defined C7 echo   7) %C7%
if defined C8 echo   8) %C8%
if defined C9 echo   9) %C9%
if defined MORE echo   ... 候选超过 9 个，只显示前 9 个；可用参数直接指定服务名
echo   0) 取消
echo.
if not defined INTERACTIVE (
    echo 非交互模式，请用参数指定服务名，例如:
    echo   mysql-service-control.bat start MySQL80
    exit /b 1
)
set "PICK="
set /p "PICK=请输入编号: "
set "PICK=%PICK: =%"
if "%PICK%"=="0" exit /b 1
if "%PICK%"=="1" if defined C1 (set "SVC=%C1%" & exit /b 0)
if "%PICK%"=="2" if defined C2 (set "SVC=%C2%" & exit /b 0)
if "%PICK%"=="3" if defined C3 (set "SVC=%C3%" & exit /b 0)
if "%PICK%"=="4" if defined C4 (set "SVC=%C4%" & exit /b 0)
if "%PICK%"=="5" if defined C5 (set "SVC=%C5%" & exit /b 0)
if "%PICK%"=="6" if defined C6 (set "SVC=%C6%" & exit /b 0)
if "%PICK%"=="7" if defined C7 (set "SVC=%C7%" & exit /b 0)
if "%PICK%"=="8" if defined C8 (set "SVC=%C8%" & exit /b 0)
if "%PICK%"=="9" if defined C9 (set "SVC=%C9%" & exit /b 0)
exit /b 1


:save_cfg
> "%CFG_FILE%" echo SVC=%SVC%
>> "%CFG_FILE%" echo PORT=%PORT%
exit /b


rem ==================================================================
rem  权限
rem ==================================================================
:ensure_admin
fsutil dirty query %SystemDrive% >nul 2>&1
if not errorlevel 1 exit /b 0
if defined MSC_ELEVATED (
    echo.
    echo [错误] 当前窗口没有管理员权限，自动提权也没有生效。
    echo        请右键本文件，选择“以管理员身份运行”。
    echo.
    pause
    exit /b 1
)
echo.
echo 需要管理员权限，正在申请提权，请在弹窗里点“是”...
set "MSC_ELEVATED=1"
set "PS_ARGS="
if not "%ALLARGS%"=="" set "PS_ARGS=-ArgumentList '%ALLARGS%' "
powershell -NoProfile -Command "Start-Process -FilePath '%~f0' %PS_ARGS%-WorkingDirectory '%~dp0' -Verb RunAs" >nul 2>&1
if errorlevel 1 (
    echo.
    echo [错误] 提权失败或被取消。
    echo        请右键本文件，选择“以管理员身份运行”。
    echo.
    pause
    exit /b 1
)
exit /b 1


rem ==================================================================
rem  信息采集
rem ==================================================================
:getinfo
set "ST=UNKNOWN"
set "STS=未知"
for /f "tokens=2 delims=:" %%A in ('sc query "%SVC%" 2^>nul ^| findstr /c:"STATE"') do (
    for /f "tokens=2" %%B in ("%%A") do set "ST=%%B"
)
if /i "%ST%"=="RUNNING"       set "STS=运行中"
if /i "%ST%"=="STOPPED"       set "STS=已停止"
if /i "%ST%"=="START_PENDING" set "STS=正在启动"
if /i "%ST%"=="STOP_PENDING"  set "STS=正在停止"
if /i "%ST%"=="PAUSED"        set "STS=已暂停"

set "STYPE=UNKNOWN"
set "TYPES=未知"
for /f "tokens=2 delims=:" %%A in ('sc qc "%SVC%" 2^>nul ^| findstr /c:"START_TYPE"') do (
    for /f "tokens=2" %%B in ("%%A") do set "STYPE=%%B"
)
if /i "%STYPE%"=="AUTO_START"   set "TYPES=自动（开机自启）"
if /i "%STYPE%"=="DEMAND_START" set "TYPES=手动"
if /i "%STYPE%"=="DISABLED"     set "TYPES=已禁用"

set "DISPLAYNAME="
for /f "tokens=2 delims=:" %%A in ('sc qc "%SVC%" 2^>nul ^| findstr /c:"DISPLAY_NAME"') do set "DISPLAYNAME=%%A"
if defined DISPLAYNAME set "DISPLAYNAME=%DISPLAYNAME:~1%"
if not defined DISPLAYNAME set "DISPLAYNAME=未知"

set "PID=0"
if /i "%ST%"=="RUNNING" (
    for /f "tokens=2 delims=:" %%A in ('sc queryex "%SVC%" 2^>nul ^| findstr /i /c:"PID"') do (
        for /f "tokens=1" %%B in ("%%A") do set "PID=%%B"
    )
)
if not defined PID set "PID=0"
exit /b


:port_info
set "PORT_STATUS=未被监听"
set "PORT_PID="
if not "%~1"=="force" (
    if /i not "%ST%"=="RUNNING" exit /b
    if "%PID%"=="0" exit /b
)
for /f "tokens=5" %%A in ('netstat -ano 2^>nul ^| findstr /c:":%PORT% " ^| findstr /c:"LISTENING"') do if not defined PORT_PID set "PORT_PID=%%A"
if defined PORT_PID set "PORT_STATUS=监听中"
exit /b


:pid_name
set "PNAME=未知"
for /f "tokens=1 delims=," %%A in ('tasklist /fi "pid eq %~1" /fo csv /nh 2^>nul') do set "PNAME=%%~A"
exit /b


:show_port_owner
call :port_info force
if defined PORT_PID (
    call :pid_name %PORT_PID%
    echo 端口 %PORT% 当前被 PID %PORT_PID% 占用，进程名: %PNAME%
) else (
    echo 端口 %PORT% 当前没有被监听。
)
exit /b


:check_other
if "%~1"=="%SVCPID%" exit /b
if not defined OTHERS (
    echo   额外的 mysqld 进程:
)
set "OTHERS=1"
echo   PID %~1
exit /b


:kill_other
if "%~1"=="%SVCPID%" exit /b
taskkill /pid %~1 /f >nul 2>&1
if errorlevel 1 (
    echo   PID %~1 : 结束失败
) else (
    echo   PID %~1 : 已结束
)
exit /b


:print_status
echo.
echo ================================================================
echo    服务名   : %SVC%
echo    显示名   : %DISPLAYNAME%
echo    当前状态 : %STS%  (%ST%)
echo    启动类型 : %TYPES%  (%STYPE%)
echo    进程 PID : %PID%
echo    端口 %PORT%  : %PORT_STATUS%
echo ================================================================
exit /b


:usage
echo.
echo   MySQL 服务控制 v%APP_VER%
echo.
echo   用法:
echo     mysql-service-control.bat                    打开菜单（推荐，会自动提权）
echo     mysql-service-control.bat status  [服务名]   查看状态（不需要管理员）
echo     mysql-service-control.bat list               列出所有 MySQL / MariaDB 服务
echo     mysql-service-control.bat port    [服务名]   查看端口占用
echo     mysql-service-control.bat start   [服务名]   启动服务
echo     mysql-service-control.bat stop    [服务名]   停止服务
echo     mysql-service-control.bat restart [服务名]   重启服务
echo     mysql-service-control.bat auto    [服务名]   设为开机自启
echo     mysql-service-control.bat manual  [服务名]   取消开机自启
echo     mysql-service-control.bat clean   [服务名]   清理非服务 mysqld（危险）
echo.
echo   服务名解析顺序:
echo     命令行参数  ^>  环境变量 MYSQL_SVC  ^>  mysql-svc.ini  ^>  自动扫描
echo.
echo   示例:
echo     mysql-service-control.bat start MySQL97
echo     set MYSQL_SVC=MySQL80 ^&^& mysql-service-control.bat restart
echo.
exit /b 0
