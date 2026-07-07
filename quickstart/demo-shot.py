#!/usr/bin/env python3
"""
demo-shot.py - 健康管理系统答辩 demo 自动截图
进哥 7/7 8:04 拍板放弃 PowerShell 部署后, 准备 7/8 答辩备料
用法:
  1. 启 backend + frontend: cd quickstart && ./start.sh
  2. python3 demo-shot.py
输出: quickstart/demo-screenshots/*.png + README.md
"""

import asyncio
from playwright.async_api import async_playwright
from pathlib import Path
import json
import time

FRONTEND_URL = "http://localhost:5173"
OUTPUT_DIR = Path(__file__).parent / "demo-screenshots"
OUTPUT_DIR.mkdir(exist_ok=True)

ACCOUNTS = [
    ("admin", "root", "管理员 (admin)"),
    ("doctor_zhang", "root", "医生 (doctor_zhang)"),
    ("user_wang", "root", "用户 (user_wang)"),
]

PAGES = [
    ("login", "/login"),
    ("dashboard", "/dashboard"),
    ("medical", "/medical"),
    ("health", "/health"),
]

ADMIN_ONLY_PAGES = [
    ("users", "/users"),
]


async def login(page, username, password):
    """登录然后等 dashboard"""
    await page.goto(f"{FRONTEND_URL}/login")
    await page.wait_for_load_state("networkidle")
    # 输入账号
    inputs = await page.query_selector_all("input")
    if len(inputs) >= 2:
        await inputs[0].fill(username)
        await inputs[1].fill(password)
    # 点登录
    btn = await page.query_selector("button:has-text('登录')")
    if btn:
        await btn.click()
    # 等跳转
    await page.wait_for_load_state("networkidle", timeout=15000)
    await asyncio.sleep(1.5)  # 等动画 + 数据加载


async def logout(page):
    """模拟登出 + 清 localStorage"""
    await page.evaluate("() => { localStorage.clear(); }")
    await page.context.clear_cookies()


async def shot(page, name, account_role=""):
    """截当前页面 + 标签"""
    out = OUTPUT_DIR / f"{name}.png"
    await page.screenshot(path=str(out), full_page=False)
    print(f"    📸 {out.name} ({account_role})")
    return out


async def main():
    print("🥟 健康管理系统答辩 demo 自动截图")
    print(f"   Frontend: {FRONTEND_URL}")
    print(f"   Output:   {OUTPUT_DIR}\n")

    results = []

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(
            viewport={"width": 1440, "height": 900},
            locale="zh-CN",
        )
        page = await context.new_page()

        # 1. Login 页面 (未登录)
        await page.goto(f"{FRONTEND_URL}/login")
        await page.wait_for_load_state("networkidle")
        await asyncio.sleep(1)
        await shot(page, "01-login", "未登录")
        results.append(("01-login", "登录页", "未登录"))

        # 2-4. 每个角色截 dashboard
        idx = 2
        for username, password, role_label in ACCOUNTS:
            print(f"\n  👤 {role_label}")

            await logout(page)
            await login(page, username, password)

            # 仪表盘
            dash_name = f"{idx:02d}-dashboard-{username}"
            await shot(page, dash_name, role_label)
            results.append((dash_name, "概览 Dashboard", role_label))

            # 公共页
            for page_name, path in PAGES[1:]:  # skip login
                idx_page = idx + PAGES.index((page_name, path))
                full_name = f"{idx_page:02d}-{page_name}-{username}"
                await page.goto(f"{FRONTEND_URL}{path}")
                await page.wait_for_load_state("networkidle")
                await asyncio.sleep(1.5)  # 等数据 + 图表
                await shot(page, full_name, role_label)
                results.append((full_name, page_name, role_label))

            # admin 专属页
            if username == "admin":
                for page_name, path in ADMIN_ONLY_PAGES:
                    full_name = f"{idx + 10:02d}-{page_name}-{username}"
                    await page.goto(f"{FRONTEND_URL}{path}")
                    await page.wait_for_load_state("networkidle")
                    await asyncio.sleep(1.5)
                    await shot(page, full_name, role_label)
                    results.append((full_name, page_name, role_label))
                idx += 1

            idx += 1

        await browser.close()

    # 生成 index.html 让进哥能浏览所有截图
    html_lines = ['<!DOCTYPE html><html><head><meta charset="UTF-8"><title>健康管理系统 demo 截图</title>',
                  '<style>body{font-family:system-ui;padding:20px;background:#f5f5f5;} ',
                  '.item{display:inline-block;margin:8px;padding:8px;background:white;border-radius:8px;box-shadow:0 2px 4px rgba(0,0,0,0.1);} ',
                  '.item img{display:block;width:480px;height:auto;border-radius:4px;} ',
                  '.item p{margin:8px 0 0;font-size:13px;color:#333;} ',
                  '.item small{color:#888;font-size:11px;}',
                  '</style></head><body><h1>健康管理系统 demo 截图</h1>']
    for filename, label, role in results:
        html_lines.append(f'<div class="item"><img src="{filename}.png"><p><b>{label}</b><br><small>{role}</small></p></div>')
    html_lines.append('</body></html>')

    (OUTPUT_DIR / "index.html").write_text("\n".join(html_lines), encoding="utf-8")
    (OUTPUT_DIR / "README.md").write_text(
        f"""# 健康管理系统 demo 截图 (7/8 答辩备料)

> **生成方式**: playwright 自动登录 3 角色 + 跳转 6 页面
> **截图时间**: {time.strftime("%Y-%m-%d %H:%M")}
> **脚本**: `quickstart/demo-shot.py`
> **数量**: {len(results)} 张

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
""", encoding="utf-8")
    print(f"\n✅ 完成 — {len(results)} 张截图")
    print(f"   📁 {OUTPUT_DIR}")
    print(f"   🌐 打开 {OUTPUT_DIR}/index.html 在浏览器看全部")


if __name__ == "__main__":
    asyncio.run(main())
