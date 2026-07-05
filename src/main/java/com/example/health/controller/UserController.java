package com.example.health.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.example.health.common.AuthContext;
import com.example.health.common.PageRequest;
import com.example.health.common.PageResult;
import com.example.health.common.Result;
import com.example.health.entity.SysUser;
import com.example.health.service.SysUserService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/users")
public class UserController {
    private final SysUserService sysUserService;

    /**
     * 用户列表 - 兼容老接口 (返回 List, 供 Android/H5 移动端使用)
     */
    @GetMapping
    public Result<List<SysUser>> list(@RequestParam(required = false) String role) {
        AuthContext.requireAdmin();
        LambdaQueryWrapper<SysUser> wrapper = new LambdaQueryWrapper<>();
        if (role != null && !role.isBlank()) {
            wrapper.eq(SysUser::getRole, role);
        }
        wrapper.orderByDesc(SysUser::getCreateTime);
        return Result.ok(sysUserService.list(wrapper).stream().peek(item -> item.setPassword(null)).toList());
    }

    /**
     * 用户列表 - 分页 (PC Web 桌面端专用, 2026-07-05 进哥拍板 Q4-B)
     *
     * 路径: GET /api/users/page?page=1&size=20&keyword=王&role=USER
     *
     * 关键词搜索: username / real_name / phone 三个字段 LIKE
     */
    @GetMapping("/page")
    public Result<PageResult<SysUser>> listPage(
            @ModelAttribute PageRequest pageRequest,
            @RequestParam(required = false) String role) {
        AuthContext.requireAdmin();
        pageRequest.sanitize();

        LambdaQueryWrapper<SysUser> wrapper = new LambdaQueryWrapper<>();
        if (role != null && !role.isBlank()) {
            wrapper.eq(SysUser::getRole, role);
        }
        if (pageRequest.getKeyword() != null && !pageRequest.getKeyword().isBlank()) {
            String kw = pageRequest.getKeyword();
            wrapper.and(w -> w.like(SysUser::getUsername, kw)
                    .or().like(SysUser::getRealName, kw)
                    .or().like(SysUser::getPhone, kw));
        }
        wrapper.orderByDesc(SysUser::getCreateTime);

        IPage<SysUser> pageResult = sysUserService.page(
                Page.of(pageRequest.getPage(), pageRequest.getSize()),
                wrapper);

        List<SysUser> records = pageResult.getRecords().stream()
                .peek(item -> item.setPassword(null))
                .toList();

        return Result.ok(PageResult.of(records, pageResult.getTotal(),
                pageRequest.getPage(), pageRequest.getSize()));
    }

    @PostMapping("/save")
    public Result<SysUser> save(@RequestBody SysUser user) {
        AuthContext.requireAdmin();
        sysUserService.saveOrUpdate(user);
        return Result.ok(user);
    }
}