package com.example.health.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.example.health.common.AuthContext;
import com.example.health.common.BusinessException;
import com.example.health.common.Result;
import com.example.health.entity.*;
import com.example.health.service.*;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/dashboard")
public class DashboardController {
    private final SysUserService userService;
    private final DoctorService doctorService;
    private final AppointmentService appointmentService;
    private final HealthDataService healthDataService;
    private final EmergencyRecordService emergencyRecordService;
    private final HealthArticleService articleService;
    private final ConsultationService consultationService;
    private final MedicineRecordService medicineRecordService;

    @GetMapping("/admin")
    public Result<Map<String, Object>> admin() {
        AuthContext.requireAdmin();
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("cards", Map.of(
                "users", userService.count(new LambdaQueryWrapper<SysUser>().eq(SysUser::getRole, "USER")),
                "doctors", doctorService.count(),
                "appointments", appointmentService.count(),
                "warnings", healthDataService.count(new LambdaQueryWrapper<HealthData>().eq(HealthData::getWarningLevel, "WARN"))
        ));
        data.put("rolePie", countBy(userService.list(), SysUser::getRole));
        data.put("appointmentTrend", appointmentService.list().stream()
                .collect(Collectors.groupingBy(item -> item.getAppointmentDate().toString(), TreeMap::new, Collectors.counting())));
        data.put("appointmentStatus", countBy(appointmentService.list(), Appointment::getStatus));
        data.put("warningTrend", healthDataService.list().stream()
                .filter(item -> "WARN".equals(item.getWarningLevel()))
                .collect(Collectors.groupingBy(item -> item.getRecordTime().toLocalDate().toString(), TreeMap::new, Collectors.counting())));
        data.put("emergencyStatus", countBy(emergencyRecordService.list(), EmergencyRecord::getStatus));
        data.put("articleCategory", countBy(articleService.list(), HealthArticle::getCategory));
        return Result.ok(data);
    }

    @GetMapping("/doctor/{doctorId}")
    public Result<Map<String, Object>> doctor(@PathVariable Long doctorId) {
        Map<String, Object> data = new LinkedHashMap<>();
        List<Appointment> appointments = appointmentService.list(new LambdaQueryWrapper<Appointment>()
                .eq(Appointment::getDoctorId, doctorId));
        List<Consultation> consultations = consultationService.list(new LambdaQueryWrapper<Consultation>()
                .eq(Consultation::getDoctorId, doctorId));
        Set<Long> patientIds = new HashSet<>();
        appointments.forEach(item -> patientIds.add(item.getUserId()));
        consultations.forEach(item -> patientIds.add(item.getUserId()));

        long medicineCount = patientIds.isEmpty() ? 0 : medicineRecordService.count(new LambdaQueryWrapper<MedicineRecord>()
                .in(MedicineRecord::getUserId, patientIds));
        data.put("cards", Map.of(
                "patients", patientIds.size(),
                "appointments", appointments.size(),
                "openConsultations", consultations.stream().filter(item -> "OPEN".equals(item.getStatus())).count(),
                "medicineRecords", medicineCount
        ));
        data.put("appointmentTrend", appointments.stream()
                .collect(Collectors.groupingBy(item -> item.getAppointmentDate().toString(), TreeMap::new, Collectors.counting())));
        data.put("appointmentStatus", countBy(appointments, Appointment::getStatus));
        data.put("consultationStatus", countBy(consultations, Consultation::getStatus));
        data.put("patientWarnings", healthDataService.list().stream()
                .filter(item -> patientIds.contains(item.getUserId()))
                .filter(item -> "WARN".equals(item.getWarningLevel()))
                .collect(Collectors.groupingBy(item -> item.getRecordTime().format(DateTimeFormatter.ofPattern("MM-dd")), TreeMap::new, Collectors.counting())));
        return Result.ok(data);
    }

    private <T> Map<String, Long> countBy(List<T> list, Function<T, String> function) {
        return list.stream().collect(Collectors.groupingBy(item -> {
            String key = function.apply(item);
            return key == null || key.isBlank() ? "未分类" : key;
        }, LinkedHashMap::new, Collectors.counting()));
    }
}
