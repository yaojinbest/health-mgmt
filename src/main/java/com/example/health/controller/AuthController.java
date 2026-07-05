package com.example.health.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.example.health.common.BusinessException;
import com.example.health.common.Result;
import com.example.health.config.JwtUtil;
import com.example.health.dto.LoginRequest;
import com.example.health.dto.RegisterRequest;
import com.example.health.entity.Doctor;
import com.example.health.entity.SysUser;
import com.example.health.service.DoctorService;
import com.example.health.service.SysUserService;
import com.example.health.vo.LoginVO;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/auth")
public class AuthController {
    private final SysUserService sysUserService;
    private final DoctorService doctorService;
    private final JwtUtil jwtUtil;

    @PostMapping("/register")
    public Result<LoginVO> register(@Valid @RequestBody RegisterRequest request) {
        long exists = sysUserService.count(new LambdaQueryWrapper<SysUser>()
                .eq(SysUser::getUsername, request.getUsername()));
        if (exists > 0) {
            throw new BusinessException("用户名已存在");
        }
        SysUser user = new SysUser();
        user.setUsername(request.getUsername());
        user.setPassword(request.getPassword());
        user.setRealName(request.getRealName());
        user.setPhone(request.getPhone());
        user.setGender(request.getGender());
        user.setAge(request.getAge());
        user.setRole(request.getRole() == null ? "USER" : request.getRole());
        user.setStatus("ACTIVE");
        user.setCreateTime(LocalDateTime.now());
        sysUserService.save(user);
        LoginVO loginVO = buildLoginVO(user);
        return Result.ok(loginVO);
    }

    @PostMapping("/login")
    public Result<LoginVO> login(@Valid @RequestBody LoginRequest request) {
        SysUser user = sysUserService.getOne(new LambdaQueryWrapper<SysUser>()
                .eq(SysUser::getUsername, request.getUsername())
                .eq(SysUser::getPassword, request.getPassword())
                .last("limit 1"));
        if (user == null) {
            throw new BusinessException("用户名或密码错误");
        }
        if (request.getRole() != null && !request.getRole().isBlank() && !request.getRole().equals(user.getRole())) {
            throw new BusinessException("账号角色不匹配");
        }
        return Result.ok(buildLoginVO(user));
    }

    private LoginVO buildLoginVO(SysUser user) {
        Doctor doctor = null;
        if ("DOCTOR".equals(user.getRole())) {
            doctor = doctorService.getOne(new LambdaQueryWrapper<Doctor>().eq(Doctor::getUserId, user.getId()).last("limit 1"));
        }
        String token = jwtUtil.generate(user.getId(), user.getUsername(), user.getRole());
        LoginVO loginVO = new LoginVO(user, doctor, token);
        user.setPassword(null);
        return loginVO;
    }
}
