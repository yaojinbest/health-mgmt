package com.example.health.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.example.health.common.AccessService;
import com.example.health.common.AuthUser;
import com.example.health.common.BusinessException;
import com.example.health.common.CsvExporter;
import com.example.health.common.PageRequest;
import com.example.health.common.PageResult;
import com.example.health.common.Result;
import com.example.health.entity.HealthData;
import com.example.health.service.HealthDataService;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.io.IOException;
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

    /**
     * 健康数据列表 - 分页 (PC Web 桌面端专用, 2026-07-05 进哥拍板 Q4-B)
     *
     * 路径: GET /api/health-data/list/page?page=1&size=20&userId=4
     */
    @GetMapping("/list/page")
    public Result<PageResult<HealthData>> listPage(
            @ModelAttribute PageRequest pageRequest,
            @RequestParam(required = false) Long userId) {
        AuthUser user = accessService.requireLogin();
        pageRequest.sanitize();

        LambdaQueryWrapper<HealthData> wrapper = new LambdaQueryWrapper<>();
        List<Long> scopedIds = accessService.scopedPatientIdsForList(user, userId);
        if (scopedIds != null) {
            if (scopedIds.isEmpty()) {
                return Result.ok(PageResult.empty(pageRequest.getPage(), pageRequest.getSize()));
            }
            wrapper.in(HealthData::getUserId, scopedIds);
        }
        wrapper.orderByDesc(HealthData::getRecordTime);

        IPage<HealthData> pageResult = healthDataService.page(
                Page.of(pageRequest.getPage(), pageRequest.getSize()),
                wrapper);

        return Result.ok(PageResult.of(pageResult.getRecords(), pageResult.getTotal(),
                pageRequest.getPage(), pageRequest.getSize()));
    }

    @GetMapping("/chart")
    public Result<List<HealthData>> chart(@RequestParam Long userId) {
        accessService.assertSelfOrStaff(userId);
        return Result.ok(healthDataService.list(new LambdaQueryWrapper<HealthData>()
                .eq(HealthData::getUserId, userId)
                .orderByAsc(HealthData::getRecordTime)));
    }

    /**
     * 健康数据导出 CSV (PC Web 桌面端专用, 2026-07-05 进哥拍板 Q4-B / P2)
     *
     * 路径: GET /api/health-data/export?userId=4
     *
     * 权限: admin 看全部; doctor/user 遵循 list 同样的 scopedPatientIdsForList
     * 注意: 不分页, 一次性导出 (如果数据量大, 可改成分批流式)
     */
    @GetMapping("/export")
    public void exportCsv(@RequestParam(required = false) Long userId,
                          HttpServletResponse response) throws IOException {
        AuthUser user = accessService.requireLogin();
        LambdaQueryWrapper<HealthData> wrapper = new LambdaQueryWrapper<>();
        List<Long> scopedIds = accessService.scopedPatientIdsForList(user, userId);
        if (scopedIds != null) {
            if (scopedIds.isEmpty()) {
                CsvExporter.export(response, "健康数据_空", new String[]{"提示"}, List.of(),
                        r -> new Object[]{});
                return;
            }
            wrapper.in(HealthData::getUserId, scopedIds);
        }
        wrapper.orderByDesc(HealthData::getRecordTime);

        List<HealthData> rows = healthDataService.list(wrapper);
        CsvExporter.export(response, "健康数据_" + LocalDateTime.now(),
                new String[]{"ID", "用户ID", "收缩压(mmHg)", "舒张压(mmHg)", "血糖(mmol/L)",
                        "心率(bpm)", "步数", "睡眠(小时)", "体重(kg)", "警告级别", "警告信息", "记录时间"},
                rows,
                r -> new Object[]{
                        r.getId(),
                        r.getUserId(),
                        r.getSystolic(),
                        r.getDiastolic(),
                        r.getBloodSugar(),
                        r.getHeartRate(),
                        r.getSteps(),
                        r.getSleepHours(),
                        r.getWeight(),
                        r.getWarningLevel(),
                        r.getWarningMessage(),
                        r.getRecordTime()
                });
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
