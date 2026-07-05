package com.example.health.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.example.health.common.AuthContext;
import com.example.health.common.Result;
import com.example.health.entity.Consultation;
import com.example.health.entity.HealthData;
import com.example.health.entity.MedicineRecord;
import com.example.health.entity.SysUser;
import com.example.health.service.ConsultationService;
import com.example.health.service.HealthDataService;
import com.example.health.service.MedicineRecordService;
import com.example.health.service.SysUserService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 统计接口 (PC Web 桌面端专用, 2026-07-05 进哥拍板 Q4-B / P3)
 *
 * 5 个 Dashboard 卡片 + 趋势图数据
 * 权限: admin only
 */
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/admin/stats")
public class StatsController {

    private final SysUserService sysUserService;
    private final HealthDataService healthDataService;
    private final MedicineRecordService medicineRecordService;
    private final ConsultationService consultationService;

    /**
     * Dashboard 概览 - 5 个数字卡片
     *
     * 路径: GET /api/admin/stats/overview
     *
     * 返回: { totalUsers, totalPatients, totalDoctors, totalHealthRecords,
     *        totalMedicines, totalConsultations, activeConsultations, warnHealthRecords }
     */
    @GetMapping("/overview")
    public Result<Map<String, Object>> overview() {
        AuthContext.requireAdmin();

        Map<String, Object> data = new LinkedHashMap<>();

        // 用户统计
        long totalUsers = sysUserService.count();
        long totalPatients = sysUserService.count(new LambdaQueryWrapper<SysUser>().eq(SysUser::getRole, "USER"));
        long totalDoctors = sysUserService.count(new LambdaQueryWrapper<SysUser>().eq(SysUser::getRole, "DOCTOR"));
        data.put("totalUsers", totalUsers);
        data.put("totalPatients", totalPatients);
        data.put("totalDoctors", totalDoctors);

        // 健康数据统计
        long totalHealth = healthDataService.count();
        long warnHealth = healthDataService.count(new LambdaQueryWrapper<HealthData>().eq(HealthData::getWarningLevel, "WARN"));
        data.put("totalHealthRecords", totalHealth);
        data.put("warnHealthRecords", warnHealth);

        // 用药统计
        long totalMedicines = medicineRecordService.count();
        long activeMedicines = medicineRecordService.count(new LambdaQueryWrapper<MedicineRecord>().eq(MedicineRecord::getStatus, "ACTIVE"));
        data.put("totalMedicines", totalMedicines);
        data.put("activeMedicines", activeMedicines);

        // 咨询统计
        long totalConsultations = consultationService.count();
        long openConsultations = consultationService.count(new LambdaQueryWrapper<Consultation>().eq(Consultation::getStatus, "OPEN"));
        data.put("totalConsultations", totalConsultations);
        data.put("activeConsultations", openConsultations);

        return Result.ok(data);
    }

    /**
     * 健康数据趋势 - 最近 N 天 (用于 ECharts 折线图)
     *
     * 路径: GET /api/admin/stats/health-trends?days=7
     *
     * 返回: {
     *   dates: ["2026-06-29", "2026-06-30", ...],
     *   systolic: [125, 130, ...],   // 平均收缩压
     *   diastolic: [80, 82, ...],    // 平均舒张压
     *   bloodSugar: [6.5, 6.8, ...], // 平均血糖
     *   heartRate: [75, 78, ...],    // 平均心率
     *   warnCount: [1, 2, ...]       // 警告数据条数
     * }
     */
    @GetMapping("/health-trends")
    public Result<Map<String, Object>> healthTrends(
            @RequestParam(defaultValue = "7") int days) {
        AuthContext.requireAdmin();
        if (days < 1 || days > 90) days = 7;

        // 计算日期范围
        LocalDate today = LocalDate.now();
        LocalDate startDate = today.minusDays(days - 1L);

        List<HealthData> all = healthDataService.list(new LambdaQueryWrapper<HealthData>()
                .ge(HealthData::getRecordTime, startDate.atStartOfDay())
                .orderByAsc(HealthData::getRecordTime));

        // 按日期分组求平均
        Map<LocalDate, List<HealthData>> byDate = new HashMap<>();
        for (HealthData h : all) {
            LocalDate d = h.getRecordTime().toLocalDate();
            byDate.computeIfAbsent(d, k -> new ArrayList<>()).add(h);
        }

        List<String> dates = new ArrayList<>();
        List<Double> systolicAvg = new ArrayList<>();
        List<Double> diastolicAvg = new ArrayList<>();
        List<Double> bloodSugarAvg = new ArrayList<>();
        List<Double> heartRateAvg = new ArrayList<>();
        List<Integer> warnCount = new ArrayList<>();
        DateTimeFormatter fmt = DateTimeFormatter.ofPattern("yyyy-MM-dd");

        for (int i = 0; i < days; i++) {
            LocalDate d = startDate.plusDays(i);
            dates.add(d.format(fmt));
            List<HealthData> rows = byDate.getOrDefault(d, List.of());
            if (rows.isEmpty()) {
                systolicAvg.add(null);
                diastolicAvg.add(null);
                bloodSugarAvg.add(null);
                heartRateAvg.add(null);
                warnCount.add(0);
            } else {
                systolicAvg.add(avg(rows.stream().map(HealthData::getSystolic).toList()));
                diastolicAvg.add(avg(rows.stream().map(HealthData::getDiastolic).toList()));
                bloodSugarAvg.add(avgDecimal(rows.stream().map(HealthData::getBloodSugar).toList()));
                heartRateAvg.add(avg(rows.stream().map(HealthData::getHeartRate).toList()));
                warnCount.add((int) rows.stream().filter(r -> "WARN".equals(r.getWarningLevel())).count());
            }
        }

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("dates", dates);
        data.put("systolic", systolicAvg);
        data.put("diastolic", diastolicAvg);
        data.put("bloodSugar", bloodSugarAvg);
        data.put("heartRate", heartRateAvg);
        data.put("warnCount", warnCount);

        return Result.ok(data);
    }

    /**
     * 咨询趋势 - 最近 N 天
     *
     * 路径: GET /api/admin/stats/consultation-trends?days=7
     *
     * 返回: { dates, created, closed }
     */
    @GetMapping("/consultation-trends")
    public Result<Map<String, Object>> consultationTrends(
            @RequestParam(defaultValue = "7") int days) {
        AuthContext.requireAdmin();
        if (days < 1 || days > 90) days = 7;

        LocalDate today = LocalDate.now();
        LocalDate startDate = today.minusDays(days - 1L);

        List<Consultation> all = consultationService.list(new LambdaQueryWrapper<Consultation>()
                .ge(Consultation::getCreateTime, startDate.atStartOfDay()));

        Map<LocalDate, Integer> createdByDate = new HashMap<>();
        Map<LocalDate, Integer> closedByDate = new HashMap<>();
        for (Consultation c : all) {
            LocalDate d = c.getCreateTime().toLocalDate();
            createdByDate.merge(d, 1, Integer::sum);
            if ("CLOSED".equals(c.getStatus())) {
                closedByDate.merge(d, 1, Integer::sum);
            }
        }

        List<String> dates = new ArrayList<>();
        List<Integer> created = new ArrayList<>();
        List<Integer> closed = new ArrayList<>();
        DateTimeFormatter fmt = DateTimeFormatter.ofPattern("yyyy-MM-dd");

        for (int i = 0; i < days; i++) {
            LocalDate d = startDate.plusDays(i);
            dates.add(d.format(fmt));
            created.add(createdByDate.getOrDefault(d, 0));
            closed.add(closedByDate.getOrDefault(d, 0));
        }

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("dates", dates);
        data.put("created", created);
        data.put("closed", closed);

        return Result.ok(data);
    }

    /**
     * 用户角色分布 - 用于饼图
     *
     * 路径: GET /api/admin/stats/user-distribution
     *
     * 返回: [{ role: "USER", count: 6 }, { role: "DOCTOR", count: 2 }, { role: "ADMIN", count: 1 }]
     */
    @GetMapping("/user-distribution")
    public Result<List<Map<String, Object>>> userDistribution() {
        AuthContext.requireAdmin();
        List<Map<String, Object>> rows = new ArrayList<>();
        for (String role : new String[]{"USER", "DOCTOR", "ADMIN"}) {
            long count = sysUserService.count(new LambdaQueryWrapper<SysUser>().eq(SysUser::getRole, role));
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("role", role);
            item.put("count", count);
            item.put("label", switch (role) {
                case "USER" -> "患者";
                case "DOCTOR" -> "医生";
                case "ADMIN" -> "管理员";
                default -> role;
            });
            rows.add(item);
        }
        return Result.ok(rows);
    }

    /**
     * 健康警告 Top N 患者 - 用于排名表
     *
     * 路径: GET /api/admin/stats/warn-top?limit=10
     */
    @GetMapping("/warn-top")
    public Result<List<Map<String, Object>>> warnTop(
            @RequestParam(defaultValue = "10") int limit) {
        AuthContext.requireAdmin();
        if (limit < 1 || limit > 50) limit = 10;

        // 按 userId 分组, 统计 WARN 数量
        List<HealthData> warns = healthDataService.list(new LambdaQueryWrapper<HealthData>()
                .eq(HealthData::getWarningLevel, "WARN"));
        Map<Long, Integer> byUser = new HashMap<>();
        for (HealthData h : warns) {
            byUser.merge(h.getUserId(), 1, Integer::sum);
        }

        // 按数量排序
        List<Map.Entry<Long, Integer>> sorted = byUser.entrySet().stream()
                .sorted((a, b) -> b.getValue().compareTo(a.getValue()))
                .limit(limit)
                .toList();

        Map<Long, String> userNames = new HashMap<>();
        List<SysUser> users = sysUserService.list();
        for (SysUser u : users) {
            userNames.put(u.getId(), u.getRealName() != null ? u.getRealName() : u.getUsername());
        }

        List<Map<String, Object>> rows = new ArrayList<>();
        int rank = 1;
        for (Map.Entry<Long, Integer> e : sorted) {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("rank", rank++);
            row.put("userId", e.getKey());
            row.put("userName", userNames.getOrDefault(e.getKey(), "用户#" + e.getKey()));
            row.put("warnCount", e.getValue());
            rows.add(row);
        }
        return Result.ok(rows);
    }

    private Double avg(List<Integer> values) {
        List<Integer> nonNull = values.stream().filter(v -> v != null).toList();
        if (nonNull.isEmpty()) return null;
        return nonNull.stream().mapToInt(Integer::intValue).average().orElse(0);
    }

    private Double avgDecimal(List<BigDecimal> values) {
        List<BigDecimal> nonNull = values.stream().filter(v -> v != null).toList();
        if (nonNull.isEmpty()) return null;
        return nonNull.stream().reduce(BigDecimal.ZERO, BigDecimal::add)
                .divide(BigDecimal.valueOf(nonNull.size()), 2, RoundingMode.HALF_UP)
                .doubleValue();
    }
}