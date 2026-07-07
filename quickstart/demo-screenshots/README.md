# 健康管理系统 demo 截图 (7/8 答辩备料)

> **生成方式**: playwright 自动登录 3 角色 + 跳转 6 页面
> **截图时间**: 2026-07-07 08:35
> **脚本**: `quickstart/demo-shot.py`
> **数量**: 14 张

## 角色覆盖
- admin         / root     # 管理员 (含 Users 用户管理)
- doctor_zhang  / root     # 医生 (Medical 医疗资源)
- user_wang     / root     # 用户 (Health 健康数据)

## 页面覆盖
- login        # 登录页
- dashboard    # 概览 + 统计图表
- medical      # 医疗资源 (医院 / 科室 / 医生)
- health       # 健康数据 (用户每日记录)
- users        # 用户管理 (admin only)

## 浏览方式
```bash
cd quickstart/demo-screenshots
python3 -m http.server 8080
# 浏览器开 http://localhost:8080 看全部截图
```

或者直接打开 `index.html` 在文件浏览器。
