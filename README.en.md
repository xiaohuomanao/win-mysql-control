# MySQL Service Control (Windows)

A single-file, zero-dependency Windows batch tool to start/stop MySQL or MariaDB services, toggle auto-start, and check port usage — no `services.msc`, no need to remember the service name.

## Features

- Single `.bat` file, no runtime dependencies.
- Self-elevates via UAC, with clear failure messages (no retry loop).
- Auto-detects services whose name contains `mysql` or `mariadb`; asks you to pick if there are several, and remembers the choice.
- Shows status, start type, PID, and whether the port is listening.
- On start failure, tells you which PID is holding the port.
- Menu mode for daily use, subcommands for scripting.
- Destructive cleanup requires typing `YES`.

## Requirements

- Windows 10 1809+ / Windows 11
- MySQL 5.7 / 8.0 / 9.x, or MariaDB (service must already be installed)
- PowerShell 5.1 (built in) is used only for elevation

## Usage

```bat
mysql-service-control.bat                  :: menu (recommended)
mysql-service-control.bat status  [svc]    :: show status (no admin needed)
mysql-service-control.bat list             :: list MySQL / MariaDB services
mysql-service-control.bat port    [svc]    :: show port owner
mysql-service-control.bat start   [svc]
mysql-service-control.bat stop    [svc]
mysql-service-control.bat restart [svc]
mysql-service-control.bat auto    [svc]    :: enable auto-start
mysql-service-control.bat manual  [svc]    :: disable auto-start
mysql-service-control.bat clean   [svc]    :: kill non-service mysqld (dangerous)
```

Service name resolution order: CLI argument → `MYSQL_SVC` env var → `mysql-svc.ini` → auto-detect.

## Notes

- The script only touches the service layer (`net start/stop`, `sc config`, `taskkill`). It never edits MySQL config or data files.
- `clean` force-kills `mysqld.exe` processes that are not the service instance. Use with care.
- Exit codes: `0` ok, `1` failed, `2` service not found.

## License

[MIT](LICENSE)
