# health-mgmt 项目归档说明 (2026-07-07)

> **进哥拍板**: 2026-07-07 08:04 飞书 "放弃 health-management 项目"
> **决定**: 代码 + 文档完整保留，但部署链路废弃，7/7-7/8 答辩不再依赖此项目

## 📦 归档内容

```
docs/06-archived/v4.1.3-full-deployment/
├── README.md                                # 项目根 README
├── reset-root-password.md                  # 重置 root 密码文档 (从 deploy/windows/)
├── deploy/                                  # install.ps1 v4.1.3 (最新版, 13 步骤部署脚本)
│   └── windows/
│       ├── install.ps1                      # v4.1.3 (含 4 个 fallback: jar 上层/顶层, dist 变体)
│       ├── reset-root-auto.ps1
│       ├── reset-root-password.md
│       ├── reset-root-simple.sql
│       ├── restart-all.ps1
│       ├── status.ps1
│       ├── stop-all.ps1
│       └── uninstall.ps1
└── health-mgmt-deploy-v4.1.3-full.zip       # 26.3 MB 全量包 (md5 d3fa11ca042be87894c9ebc2ae70d602)
                                              #   195 文件, jar 在 target/, dist 在 frontend-pc/dist/
```

## ❌ 为什么归档

1. **部署链路脆**: PowerShell 5.1 + Windows 真机 + 9 ps1 + 路径含空格 + UTF-8 BOM = 4-5 种致命组合
2. **60h 投入 95% 在部署踩坑**: 真不值得 (7/6 init-db.ps1 18 个版本爆破, 7/7 凌晨 5:46 又因 zip 拓扑问题崩)
3. **零测试覆盖**: 部署链路没有任何自动化验证, 每次都得真机逐项确认

## ✅ 仍然有效

- `src/` — 后端 Spring Boot 3.3.5 完整 91 Java 类
- `frontend-pc/src/` — Vue 3 完整源码 (Login/Dashboard/Medical/Health/Medicine 等)
- `health-mgmt-app/` — Android Kotlin 完整源码
- `sql/init.sql` — 15 张表种子数据
- `target/health-management-1.0.0.jar` — 已构建的 jar (29 MB)
- `frontend-pc/dist/` — 已构建的前端 (2.7 MB)

## 🆘 仍可补救 (答辩 demo 用)

| 方案 | 时间 | 依赖 |
|---|---|---|
| **docker-compose** 拉起完整服务 | 2h | sandbox Linux + docker |
| **截图 / 录屏** 替代真机演示 | 1h | playwright + 浏览器 |
| **现有 sandbox 数据** 演示 3 角色 login | 30min | 7/6 沙箱跑通的 admin/root, doctor_zhang/root, user_wang/root |

## 📚 后续访问

- 主代码仍在 `/home/yaojin/projects/health-mgmt/` (git 仓 `yaojinbest/health-mgmt`)
- GitHub: https://github.com/yaojinbest/health-mgmt (66 commits)
- 部署参考本文档 `deploy/` 子目录
- 完整 postmortem: 见 OPC_K MEMORY.md "2026-07-07 health-mgmt 项目放弃 postmortem" 段
