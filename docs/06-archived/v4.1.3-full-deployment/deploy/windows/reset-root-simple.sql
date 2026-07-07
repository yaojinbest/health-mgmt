-- MariaDB root 密码重置 (v1.2 - 简化版, 避免 PowerShell here-string 坑)
-- 适用: 5 步手动 reset 流程的 Step 4

USE mysql;
DELETE FROM mysql.global_priv WHERE User='root' AND Host IN ('localhost', '127.0.0.1', '::1');
INSERT INTO mysql.global_priv (Host, User, Priv) VALUES
('localhost', 'root', JSON_OBJECT('access', 1099511627775, 'plugin', 'mysql_native_password', 'authentication_string', '*C9677062716458A38A41FA101A14725A3CE8F1FE', 'is_role', 'N', 'default_role', '', 'max_connections', 0, 'max_user_connections', 0, 'max_statement_time', 0.0, 'version_id', 110803, 'password_last_changed', UNIX_TIMESTAMP(NOW()))),
('127.0.0.1', 'root', JSON_OBJECT('access', 1099511627775, 'plugin', 'mysql_native_password', 'authentication_string', '*C9677062716458A38A41FA101A14725A3CE8F1FE', 'is_role', 'N', 'default_role', '', 'max_connections', 0, 'max_user_connections', 0, 'max_statement_time', 0.0, 'version_id', 110803, 'password_last_changed', UNIX_TIMESTAMP(NOW()))),
('::1', 'root', JSON_OBJECT('access', 1099511627775, 'plugin', 'mysql_native_password', 'authentication_string', '*C9677062716458A38A41FA101A14725A3CE8F1FE', 'is_role', 'N', 'default_role', '', 'max_connections', 0, 'max_user_connections', 0, 'max_statement_time', 0.0, 'version_id', 110803, 'password_last_changed', UNIX_TIMESTAMP(NOW())));
FLUSH PRIVILEGES;