package com.example.health.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.example.health.common.AccessService;
import com.example.health.common.AuthUser;
import com.example.health.common.BusinessException;
import com.example.health.common.Result;
import com.example.health.entity.HealthData;
import com.example.health.service.HealthDataService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/health-data")
public class HealthDataController {
    private final HealthDataService healthDataService;
    private final AccessService accessService;

    @PostMapping("/save")
    public Result<HealthData> save(@RequestBody HealthData data) {
        if (data.getUserId() == null) {
            throw new BusinessException("用户ID不能为空");
        }
        accessService.assertOwnUserId(data.getUserId());
        if (data.getSystolic() == null && data.getBloodSugar() == null && data.getHeartRate() == null
                && data.getSteps() == null && data.getSleepHours() == null && data.getWeight() == null) {
            throw new BusinessException("请至少填写一项健康数据");
        }
        fillWarning(data);
        if (data.getRecordTime() == null) {
            data.setRecordTime(LocalDateTime.now());
        }
        healthDataService.saveOrUpdate(data);
        return Result.ok(data);
    }

    @GetMapping("/list")
    public Result<List<HealthData>> list(@RequestParam(required = false) Long userId) {
        AuthUser user = accessService.requireLogin();
        LambdaQueryWrapper<HealthData> wrapper = new LambdaQueryWrapper<>();
        List<Long> scopedIds = accessService.scopedPatientIdsForList(user, userId);
        if (scopedIds != null) {
            if (scopedIds.isEmpty()) {
                return Result.ok(List.of());
            }
            wrapper.in(HealthData::getUserId, scopedIds);
        }
        wrapper.orderByDesc(HealthData::getRecordTime);
        return Result.ok(healthDataService.list(wrapper));
    }

    @GetMapping("/chart")
    public Result<List<HealthData>> chart(@RequestParam Long userId) {
        accessService.assertSelfOrStaff(userId);
        return Result.ok(healthDataService.list(new LambdaQueryWrapper<HealthData>()
                .eq(HealthData::getUserId, userId)
                .orderByAsc(HealthData::getRecordTime)));
    }

    private void fillWarning(HealthData data) {
        StringBuilder message = new StringBuilder();
        boolean danger = false;
        if (data.getSystolic() != null && data.getDiastolic() != null
                && (data.getSystolic() >= 140 || data.getDiastolic() >= 90)) {
            danger = true;
            message.append("血压超过140/90mmHg；");
        }
        BigDecimal sugar = data.getBloodSugar();
        if (sugar != null && sugar.compareTo(new BigDecimal("7.0")) > 0) {
            danger = true;
            message.append("血糖偏高；");
        }
        if (data.getHeartRate() != null && (data.getHeartRate() > 100 || data.getHeartRate() < 50)) {
            danger = true;
            message.append("心率异常；");
        }
        data.setWarningLevel(danger ? "WARN" : "NORMAL");
        data.setWarningMessage(danger ? message.toString() : "指标正常");
    }
}
