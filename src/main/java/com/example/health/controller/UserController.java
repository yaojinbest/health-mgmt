package com.example.health.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.example.health.common.AuthContext;
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

    @PostMapping("/save")
    public Result<SysUser> save(@RequestBody SysUser user) {
        AuthContext.requireAdmin();
        sysUserService.saveOrUpdate(user);
        return Result.ok(user);
    }
}
