# 健康管理系统 Quickstart (无 PowerShell 部署方案 v1.0)

> **进哥 7/7 08:04 拍板** - 健康管理系统放弃 PowerShell 部署链路，改用 docker-compose 或 quickstart 脚本作为答辩补救方案。
> **目的**: 替代 v4.1.3 install.ps1 那 9 个 ps1 + Windows 真机依赖，避免 PS 5.1 + BOM + 路径转义等 28 个坑。

## 🚀 两种启动方式

### 方式 A: docker-compose (推荐, 跨平台)

需要:
- Docker + Docker Compose v2

```bash
cd /home/yaojin/projects/health-mgmt/quickstart
docker compose up -d           # 拉起 mariadb + backend + frontend
docker compose logs -f         # 看日志
curl http://localhost:8090/api/auth/login -X POST \
     -H "Content-Type: application/json" \
     -d '{"username":"admin","password":"root"}'
docker compose down            # 停 (保留数据)
docker compose down -v         # 停 + 删数据
```

访问:
- Frontend: http://localhost:5173
- Backend: http://localhost:8090/api
- MariaDB: localhost:3306 (root/opck2026)

### 方式 B: start.sh (sandbox / 无 docker)

需要:
- MariaDB binary (`mariadbd` 在 PATH)
- Java 17+ (`java` 在 PATH)
- Python 3 (`python3` 在 PATH)

```bash
cd /home/yaojin/projects/health-mgmt/quickstart
chmod +x start.sh stop.sh
./start.sh                     # 启 mariadb + backend + frontend
./stop.sh                      # 停全部
```

访问:
- Frontend: http://localhost:5173
- Backend: http://localhost:8090/api

## 🔑 6 角色账号 (密码统一 `root`)

| 账号 | 角色 | 权限 |
|---|---|---|
| admin | 管理员 | 全权管理 |
| doctor_zhang | 医生 | 看诊 + 处方 |
| doctor_li | 医生 | 看诊 + 处方 |
| user_wang | 用户 | 患者视角 |
| user_chen | 用户 | 患者视角 |
| user_zhao | 用户 | 患者视角 |

## 📦 项目结构

```
health-mgmt/
├── src/                         # 后端 Spring Boot 3.3.5 源码
├── frontend-pc/                 # Vue 3 前端源码 + dist/
│   ├── src/                     # Vue 源码
│   └── dist/                    # 已构建 (nginx 静态文件)
├── health-mgmt-app/             # Android Kotlin 源码
├── sql/init.sql                 # 15 表 + 种子数据
├── target/health-management-1.0.0.jar    # 已构建 jar (29 MB)
├── docs/06-archived/            # 历史归档 (旧 v4.x 部署)
└── quickstart/                  # ⭐ 本目录
    ├── docker-compose.yml       # 3 service: mariadb + backend + frontend
    ├── nginx.conf               # Vue 3 SPA + /api/ 反代
    ├── start.sh                 # sandbox fallback
    ├── stop.sh
    ├── bin/                      # (预留扩展)
    ├── logs/                     # 日志目录 (启动后生成)
    └── README.md
```

## 🐛 故障排查

### Backend 起不来 (curl 8090 没响应)

```bash
tail -f quickstart/logs/backend.log
# 看 Caused by: ... 真实原因
```

常见:
- `Communications link failure` → mariadb 没启 / 端口不对
- `Access denied for user 'root'@'127.0.0.1'` → 密码不对
- `Unknown database 'health_management'` → init.sql 没跑

### Frontend "Cannot GET /api/auth/login"

nginx.conf 反代没生效。docker-compose 重拉:
```bash
docker compose restart frontend
```

### Init SQL 报错 (字符乱码)

`sql/init.sql` 必须 UTF-8 + **带 BOM**。验证:
```bash
file sql/init.sql
# 应显示 "UTF-8 Unicode (with BOM) text"
```

无 BOM 加:
```bash
printf '\xef\xbb\xbf' | cat - sql/init.sql > init-bom.sql && mv init-bom.sql sql/init.sql
```

## 📜 历史 / 归档

- **旧 PowerShell 部署脚本**: `docs/06-archived/v4.1.3-full-deployment/deploy/`
- **完整 v4.1.3 zip** (33 MB): `docs/06-archived/v4.1.3-full-deployment/health-mgmt-deploy-v4.1.3-full.zip`
- **60h 失败复盘**: 见 pm_jiaozi MEMORY.md "2026-07-07 health-mgmt 项目放弃 postmortem" 段

## 🎓 答辩演示建议

1. 先跑 `./start.sh` (sandbox 模式) 或 `docker compose up -d`
2. 浏览器开 http://localhost:5173, admin/root 登录
3. 演示路径 (3-5 张截图为宜):
   - Login → Dashboard (管理员视角)
   - Users → 用户列表 (admin only)
   - Medical → 健康档案 / Medical
   - 切 doctor_zhang → 医生视角 (咨询 + 处方)
   - 切 user_wang → 患者视角 (健康数据录入 + 健康文章)
4. 演示视频录屏 5-10 分钟 (用 OBS 或 playwright)
