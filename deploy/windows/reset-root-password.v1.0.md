# MariaDB Root 密码重置指南 (5 步法, 健康管理系统专用)

## 适用场景
- 早上跑过, 下午 root 密码忘了 / 10061 后变 1045
- 我之前 17 个版本爆破 (v3.1.x → v3.2.x) 全部跑偏
- **正确答案就是这条 5 步法, 不需要复杂 ps1**

## 前置条件
- 管理员 PowerShell 5.1
- MariaDB 11.8 已装 (zip 或 installer 都行)
- 知道 MariaDB 安装路径 (默认 `C:\Program Files\MariaDB 11.8\`)

---

## Step 1: 停 service + 确认 port 空闲

```powershell
net stop MariaDB
Start-Sleep -Seconds 3
Get-NetTCPConnection -LocalPort 3306 -State Listen -ErrorAction SilentlyContinue
# 预期: 无输出 (port 空闲)
```

如果 `net stop MariaDB` 失败 (service 不存在), 手动 kill:
```powershell
Get-Process -Name mariadbd -ErrorAction SilentlyContinue | Stop-Process -Force
```

---

## Step 2: 启 mariadbd 进 skip-grant-tables (前台)

**管理员 PowerShell**:
```powershell
& "C:\Program Files\MariaDB 11.8\bin\mariadbd.exe" `
    --datadir="C:\Program Files\MariaDB 11.8\data" `
    --port=3306 `
    --skip-grant-tables `
    --character-set-server=utf8mb4 `
    --character-set-filesystem=utf8mb4 `
    --console
```

⚠️ **这条命令会一直前台跑**，看到 `ready for connections` 就 OK。**新开 PowerShell** 跑 Step 3。

---

## Step 3: 连 mariadb + 改密 (新开 PowerShell)

```powershell
# 1. 空密码连
& "C:\Program Files\MariaDB 11.8\bin\mysql.exe" -uroot -h127.0.0.1 --default-character-set=utf8mb4
```

进入 mysql 提示符后跑:
```sql
USE mysql;

-- 删除所有空密码 root
DELETE FROM mysql.global_priv WHERE User='root';

-- 重建 3 个 host (localhost / 127.0.0.1 / ::1) 都用 opck2026
INSERT INTO mysql.global_priv (Host, User, Priv) VALUES
 ('localhost', 'root', JSON_OBJECT('access', 1099511627775, 'plugin', 'mysql_native_password', 'authentication_string', '*C9677062716458A38A41FA101A14725A3CE8F1FE', 'is_role', 'N', 'default_role', '', 'max_connections', 0, 'max_user_connections', 0, 'max_statement_time', 0.0, 'version_id', 110803, 'password_last_changed', UNIX_TIMESTAMP(NOW()))),
 ('127.0.0.1', 'root', JSON_OBJECT('access', 1099511627775, 'plugin', 'mysql_native_password', 'authentication_string', '*C9677062716458A38A41FA101A14725A3CE8F1FE', 'is_role', 'N', 'default_role', '', 'max_connections', 0, 'max_user_connections', 0, 'max_statement_time', 0.0, 'version_id', 110803, 'password_last_changed', UNIX_TIMESTAMP(NOW()))),
 ('::1', 'root', JSON_OBJECT('access', 1099511627775, 'plugin', 'mysql_native_password', 'authentication_string', '*C9677062716458A38A41FA101A14725A3CE8F1FE', 'is_role', 'N', 'default_role', '', 'max_connections', 0, 'max_user_connections', 0, 'max_statement_time', 0.0, 'version_id', 110803, 'password_last_changed', UNIX_TIMESTAMP(NOW())));

FLUSH PRIVILEGES;
EXIT;
```

---

## Step 4: 关前台 mariadbd (回到跑前台那个 PowerShell)

按 `Ctrl + C` 终止前台 mariadbd。

或新开 PowerShell:
```powershell
Get-Process -Name mariadbd -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3
```

---

## Step 5: 重启 service + 验证

```powershell
net start MariaDB
Start-Sleep -Seconds 3
& "C:\Program Files\MariaDB 11.8\bin\mysql.exe" -uroot -h127.0.0.1 -popck2026 --default-character-set=utf8mb4 -e "SELECT VERSION(), CURRENT_USER();"
```

**预期**:
```
VERSION():  11.8.8-MariaDB
CURRENT_USER(): root@127.0.0.1
```

🎉 完成！然后跑:
```powershell
cd C:\Users\84918\Desktop\health-mgmt\deploy\windows
.\init-db.ps1 -DbPassword opck2026
```

---

## 故障排查

| 错误 | 含义 | 修法 |
|---|---|---|
| `ERROR 1290 ... --skip-grant-tables option` | skip-grant 模式禁 ALTER USER/SET PASSWORD | **用 DELETE+INSERT** (Step 3 上面), 不能用 ALTER USER |
| `ERROR 1045 (28000)` | 密码错 | 重新跑 Step 3 |
| `ERROR 2002 (HY000) ... 10061` | service 没启动 | Step 1 重新确认 / Step 5 重启 service |
| `ERROR 1142 ... mysql.global_priv` | 试图在 skip-grant 模式 UPDATE/DELETE | DELETE 是允许的, 跳过 UPDATE |

---

## 关键 opck2026 哈希值 (避免输错)

```
*C9677062716458A38A41FA101A14725A3CE8F1FE
```

这等于 `PASSWORD('opck2026')` 在 MariaDB 11.x 里。

---

## 沉淀

`reset-root-password.md` v1.0 (2026-07-06 21:11)
- 作者: pm_jiaozi
- 教训: 17 个版本爆破都是过度设计, 5 步法才是正解
- 下次 root 密码忘了直接跑这条