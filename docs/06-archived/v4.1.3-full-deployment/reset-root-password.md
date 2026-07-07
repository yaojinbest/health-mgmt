# MariaDB Root 密码重置 (5 步法)

## 适用场景
- root 密码忘了 / install.ps1 报 1045
- 想重新设 root 密码

## Step 1: 停 service + 杀进程

```powershell
net stop MariaDB
Start-Sleep -Seconds 3
Get-Process -Name mariadbd,mysqld -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3
Get-NetTCPConnection -LocalPort 3306 -State Listen -ErrorAction SilentlyContinue
# 预期: 无输出 (port 空闲)
```

## Step 2: 准备 reset.sql (避免命令行 here-string 误识别)

```powershell
@'
USE mysql;
DELETE FROM mysql.global_priv WHERE User='root';
INSERT INTO mysql.global_priv (Host, User, Priv) VALUES
 ('localhost', 'root', JSON_OBJECT('access', 1099511627775, 'plugin', 'mysql_native_password', 'authentication_string', '*C9677062716458A38A41FA101A14725A3CE8F1FE', 'is_role', 'N', 'default_role', '', 'max_connections', 0, 'max_user_connections', 0, 'max_statement_time', 0.0, 'version_id', 110803, 'password_last_changed', UNIX_TIMESTAMP(NOW()))),
 ('127.0.0.1', 'root', JSON_OBJECT('access', 1099511627775, 'plugin', 'mysql_native_password', 'authentication_string', '*C9677062716458A38A41FA101A14725A3CE8F1FE', 'is_role', 'N', 'default_role', '', 'max_connections', 0, 'max_user_connections', 0, 'max_statement_time', 0.0, 'version_id', 110803, 'password_last_changed', UNIX_TIMESTAMP(NOW()))),
 ('::1', 'root', JSON_OBJECT('access', 1099511627775, 'plugin', 'mysql_native_password', 'authentication_string', '*C9677062716458A38A41FA101A14725A3CE8F1FE', 'is_role', 'N', 'default_role', '', 'max_connections', 0, 'max_user_connections', 0, 'max_statement_time', 0.0, 'version_id', 110803, 'password_last_changed', UNIX_TIMESTAMP(NOW())));
FLUSH PRIVILEGES;
'@ | Out-File -Encoding utf8 $env:TEMP\reset-root.sql
```

> 关键: 用 `@'...'@` 单引号 here-string (不被插值 + 不含双引号, 安全)

## Step 3: 启 mariadbd --skip-grant-tables (前台)

**管理员 PowerShell**:
```powershell
& "C:\Program Files\MariaDB 11.8\bin\mariadbd.exe" --datadir="C:\Program Files\MariaDB 11.8\data" --port=3306 --skip-grant-tables --character-set-server=utf8mb4 --character-set-filesystem=utf8mb4 --console
```

⚠️ 前台跑, 看到 `ready for connections` 就 OK。**新开 PowerShell** 跑 Step 4。

## Step 4: 跑 reset.sql (新开 PowerShell)

```powershell
& "C:\Program Files\MariaDB 11.8\bin\mysql.exe" -uroot -h "127.0.0.1" --default-character-set=utf8mb4 < $env:TEMP\reset-root.sql
```

> 关键: `-h "127.0.0.1"` 加空格 + 双引号 (避免 PowerShell 5.1 截断为 '127')

## Step 5: 关前台 + 重启 service + 验证

回到 Step 3 的 PowerShell, 按 `Ctrl+C`

```powershell
Get-Process -Name mariadbd -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3
net start MariaDB
Start-Sleep -Seconds 3
& "C:\Program Files\MariaDB 11.8\bin\mysql.exe" -uroot -h "127.0.0.1" -popck2026 --default-character-set=utf8mb4 -e "SELECT VERSION(), CURRENT_USER();"
```

**预期**:
```
VERSION(): 11.8.8-MariaDB
CURRENT_USER(): root@127.0.0.1
```

🎉 完成！然后跑 `.\install.ps1` 重新部署。

---

## 故障排查

| 错误 | 含义 | 修法 |
|---|---|---|
| `ERROR 1290 ... --skip-grant-tables option` | skip-grant 模式禁 ALTER USER/SET PASSWORD | 用 DELETE+INSERT (Step 2 上面), 不能用 ALTER USER |
| `ERROR 2005 (HY000) Unknown server host '127'` | PowerShell 截断 `-h127.0.0.1` | 用 `-h "127.0.0.1"` 加空格 + 双引号 |
| `ERROR 2002 (HY000) ... 10061` | service 没启动 | 重新跑 Step 1 + Step 5 |
| `ERROR 1142 ... mysql.global_priv` (UPDATE) | skip-grant 禁 UPDATE protected table | 改 DELETE+INSERT |
| `ibdata1 must be writable` | mariadbd 进程没退干净 | Get-Process 强杀 + 等 3 秒 |

---

## 关键 opck2026 哈希

```
*C9677062716458A38A41FA101A14725A3CE8F1FE
```

这等于 `PASSWORD('opck2026')` 在 MariaDB 11.x 里。