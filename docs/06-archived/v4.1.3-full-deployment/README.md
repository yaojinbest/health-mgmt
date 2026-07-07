# 健康管理系统 (health-management)

> 学生实践项目 · Spring Boot 3 + Vue 3 + Kotlin Android · OPC_K 全套踩坑沉淀

---

## 📦 项目组成 (3 件套)

| 端 | 技术栈 | 仓库 | 端口 |
|---|---|---|---|
| **后端 API** | Spring Boot 3.3.5 + MyBatis-Plus 3.5.9 + JDK 17 | 本仓库 (`health-mgmt/`) | 8090 |
| **PC Web 后台** | Vue 3 + Vite 6 + Element Plus + ECharts 5 | 本仓库 (`frontend-pc/`) | 5174 |
| **Android 客户端** | Kotlin + ViewBinding + Material 3 + MPAndroidChart | [health-mgmt-app](https://github.com/yaojinbest/health-mgmt-app) | - |

> 🔔 **PC Web = admin 后台** (用户/医生/数据管理), **Android = 用户视角** (我的数据/我的预约/我的咨询)

---

## 🚀 快速开始

### 1. 部署后端 + PC Web
见 [deploy/windows/README.md](deploy/windows/README.md) (Windows + MariaDB 11.x + JDK 17, 5 分钟)

### 2. 安装 Android 客户端
- 下载: `/apps/bdpan/health-mgmt-app/health-mgmt-app-v1.0.7-quick-record.apk` (8.1 MB, md5 `f0c38f621f9db191ccd58be0a600a5f0`)
- 装到 Android 7.0+ (API 24+)
- 服务器配置: Mine tab → 服务器配置 → 填 `http://<你PC-IP>:8090`
- 登录: `user_wang / root` (患者) 或 `doctor_zhang / root` (医生) 或 `admin / root` (管理员)

---

## 🌟 功能总览

### PC Web (admin 后台)
- ✅ 用户管理 (CRUD + 角色)
- ✅ 医院 / 科室 / 医生 / 排班 管理
- ✅ 药品 / 健康文章 管理
- ✅ 仪表盘 (admin/doctor 视角, 4 维度统计)
- ✅ 数据导出 CSV

### Android 客户端 (用户视角)
- 🏠 **Home tab**: 11 宫格入口 (录入数据/用药/档案/图表/求救/文章/咨询/我的/统计/预约/我的预约)
- 📊 **Health tab**: 健康数据录入 + 图表 (血压/血糖/心率/体重 4 维度)
- 🛠 **Tools tab**: 紧急求救 (SOS) + 紧急联系人 + 在线咨询 + 健康文章 + 用药管理
- 💬 **Consult tab**: 咨询会话列表 + 新建咨询 + 聊天
- 👤 **Mine tab**: 用户卡片 + 4 入口 + 服务器配置 + 退出登录

### 后端 API (75+ 端点)
12 个 Controller: auth, dashboard, stats, users, health-data, medical, consultation, article, medicine, emergency, archive, admin

---

## 📂 仓库结构

```
health-mgmt/                         # 本仓库 (后端 + PC Web)
├── src/                              # Spring Boot 后端源码
├── frontend-pc/                      # Vue 3 PC Web
├── sql/init.sql                      # 15 张表 + 6 用户 seed (UTF-8 BOM)
├── target/health-management-1.0.0.jar # 编译产物 (29 MB)
└── deploy/windows/                   # PowerShell 5.1 部署脚本 (全部 UTF-8 BOM)
    ├── init-db.ps1                   #   MariaDB 一键初始化
    ├── start-backend.ps1             #   启动后端 (杀旧 java + 端口检测)
    ├── start-frontend-pc.ps1         #   启动 PC Web
    ├── install-services.ps1          #   注册 Windows 后台服务
    ├── uninstall-services.ps1        #   卸载服务
    ├── smoke-test.ps1                #   端到端冒烟测试
    └── README.md                     #   详细部署文档 (8 大真机坑沉淀)

health-mgmt-app/                      # Android 仓库 (独立)
└── app/src/main/
    ├── java/com/opck/health/
    │   ├── ui/main/                  #   5 tab Fragment
    │   ├── ui/medical/               #   预约就诊 (4 步引导)
    │   ├── ui/dashboard/             #   数据统计
    │   ├── ui/health/                #   健康数据图表
    │   └── ui/consultation/          #   在线咨询
    ├── res/layout/                   #   14 个 Activity + 5 Fragment
    └── AndroidManifest.xml           #   14 个 Activity 注册
```

---

## 🎯 演示账号

| 角色 | 用户名 | 密码 | ID |
|---|---|---|---|
| 管理员 | `admin` | `root` | 1 |
| 医生 | `doctor_zhang` | `root` | 2 |
| 医生 | `doctor_li` | `root` | 3 |
| 患者 | `user_wang` | `root` | 4 |
| 患者 | `user_chen` | `root` | 5 |
| 患者 | `user_zhao` | `root` | 6 |

> ⚠️ **生产环境必须改密码 + 走环境变量** (本项目仅课程演示用)

---

## 🏷️ 版本

- **当前后端**: v3.0.0 (tag `5ac263f`, jar md5 `aacee89cf36177dfaaf9ac48439df7ef`)
- **当前 Android**: v1.0.7 (commit `be449f7`, APK md5 `f0c38f621f9db191ccd58be0a600a5f0`)

---

## 📚 文档导航

- 🪟 **Windows 部署**: [deploy/windows/README.md](deploy/windows/README.md) ← **从这开始**
- 📱 **Android 端**: [health-mgmt-app 仓库](https://github.com/yaojinbest/health-mgmt-app)
- 🐛 **8 大真机坑**: 见 [deploy/windows/README.md §OPC_K 部署 SOP](deploy/windows/README.md#opck_powershell_51_部署_sop_永久)

---

## 🔗 远端

- GitHub: https://github.com/yaojinbest/health-mgmt
- Gitee: https://gitee.com/yaojinbest/health-mgmt
