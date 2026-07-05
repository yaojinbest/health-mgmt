package com.example.health.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.example.health.common.AccessService;
import com.example.health.common.AuthContext;
import com.example.health.common.AuthUser;
import com.example.health.common.BusinessException;
import com.example.health.common.Result;
import com.example.health.dto.BatchScheduleRequest;
import com.example.health.entity.*;
import com.example.health.service.*;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/medical")
public class MedicalController {
    private final HospitalService hospitalService;
    private final DepartmentService departmentService;
    private final DoctorService doctorService;
    private final DoctorScheduleService scheduleService;
    private final AppointmentService appointmentService;
    private final SysUserService sysUserService;
    private final ConsultationService consultationService;
    private final AccessService accessService;

    @GetMapping("/hospitals")
    public Result<List<Hospital>> hospitals() {
        return Result.ok(hospitalService.list());
    }

    @PostMapping("/hospital/save")
    public Result<Hospital> saveHospital(@RequestBody Hospital hospital) {
        AuthContext.requireAdmin();
        if (hospital.getName() == null || hospital.getName().isBlank()) {
            throw new BusinessException("请填写医院名称");
        }
        hospitalService.saveOrUpdate(hospital);
        return Result.ok(hospital);
    }

    @GetMapping("/hospital/delete-check/{id}")
    public Result<Map<String, Object>> hospitalDeleteCheck(@PathVariable Long id) {
        AuthContext.requireAdmin();
        return Result.ok(buildHospitalDeleteInfo(id));
    }

    @PostMapping("/hospital/delete/{id}")
    public Result<Void> deleteHospital(@PathVariable Long id) {
        AuthContext.requireAdmin();
        ensureHospitalDeletable(id);
        hospitalService.removeById(id);
        return Result.ok();
    }

    @GetMapping("/departments")
    public Result<List<Department>> departments(@RequestParam(required = false) Long hospitalId) {
        LambdaQueryWrapper<Department> wrapper = new LambdaQueryWrapper<>();
        if (hospitalId != null) {
            wrapper.eq(Department::getHospitalId, hospitalId);
        }
        return Result.ok(departmentService.list(wrapper));
    }

    @PostMapping("/department/save")
    public Result<Department> saveDepartment(@RequestBody Department department) {
        AuthContext.requireAdmin();
        if (department.getHospitalId() == null || department.getName() == null || department.getName().isBlank()) {
            throw new BusinessException("请选择医院并填写科室名称");
        }
        departmentService.saveOrUpdate(department);
        return Result.ok(department);
    }

    @GetMapping("/department/delete-check/{id}")
    public Result<Map<String, Object>> departmentDeleteCheck(@PathVariable Long id) {
        AuthContext.requireAdmin();
        return Result.ok(buildDepartmentDeleteInfo(id));
    }

    @PostMapping("/department/delete/{id}")
    public Result<Void> deleteDepartment(@PathVariable Long id) {
        AuthContext.requireAdmin();
        ensureDepartmentDeletable(id);
        departmentService.removeById(id);
        return Result.ok();
    }

    @GetMapping("/doctors")
    public Result<List<Map<String, Object>>> doctors(@RequestParam(required = false) Long hospitalId,
                                                     @RequestParam(required = false) Long departmentId,
                                                     @RequestParam(required = false) Boolean all) {
        LambdaQueryWrapper<Doctor> wrapper = new LambdaQueryWrapper<>();
        if (hospitalId != null) {
            wrapper.eq(Doctor::getHospitalId, hospitalId);
        }
        if (departmentId != null) {
            wrapper.eq(Doctor::getDepartmentId, departmentId);
        }
        if (!Boolean.TRUE.equals(all)) {
            wrapper.eq(Doctor::getStatus, "ACTIVE");
        }
        Map<Long, String> userNames = sysUserService.list().stream()
                .collect(Collectors.toMap(SysUser::getId, u -> u.getRealName() != null ? u.getRealName() : u.getUsername(), (a, b) -> a));
        Map<Long, String> hospitalNames = hospitalService.list().stream()
                .collect(Collectors.toMap(Hospital::getId, Hospital::getName, (a, b) -> a));
        Map<Long, String> departmentNames = departmentService.list().stream()
                .collect(Collectors.toMap(Department::getId, Department::getName, (a, b) -> a));
        List<Map<String, Object>> rows = new ArrayList<>();
        for (Doctor doctor : doctorService.list(wrapper)) {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("id", doctor.getId());
            row.put("userId", doctor.getUserId());
            row.put("hospitalId", doctor.getHospitalId());
            row.put("departmentId", doctor.getDepartmentId());
            row.put("title", doctor.getTitle());
            row.put("specialty", doctor.getSpecialty());
            row.put("profile", doctor.getProfile());
            row.put("status", doctor.getStatus());
            row.put("doctorName", userNames.getOrDefault(doctor.getUserId(), "医生#" + doctor.getId()));
            row.put("hospitalName", hospitalNames.getOrDefault(doctor.getHospitalId(), "未知医院"));
            row.put("departmentName", departmentNames.getOrDefault(doctor.getDepartmentId(), "未知科室"));
            rows.add(row);
        }
        return Result.ok(rows);
    }

    @PostMapping("/doctor/save")
    public Result<Doctor> saveDoctor(@RequestBody Doctor doctor) {
        AuthContext.requireAdmin();
        if (doctor.getHospitalId() == null || doctor.getDepartmentId() == null || doctor.getUserId() == null) {
            throw new BusinessException("请完善医生所属医院、科室和账号");
        }
        if (doctor.getStatus() == null || doctor.getStatus().isBlank()) {
            doctor.setStatus("ACTIVE");
        }
        doctorService.saveOrUpdate(doctor);
        return Result.ok(doctor);
    }

    @GetMapping("/doctor/delete-check/{id}")
    public Result<Map<String, Object>> doctorDeleteCheck(@PathVariable Long id) {
        AuthContext.requireAdmin();
        return Result.ok(buildDoctorDeleteInfo(id));
    }

    @PostMapping("/doctor/delete/{id}")
    public Result<Void> deleteDoctor(@PathVariable Long id) {
        AuthContext.requireAdmin();
        ensureDoctorDeletable(id);
        doctorService.removeById(id);
        return Result.ok();
    }

    @GetMapping("/schedules")
    public Result<List<DoctorSchedule>> schedules(@RequestParam Long doctorId) {
        return Result.ok(scheduleService.list(new LambdaQueryWrapper<DoctorSchedule>()
                .eq(DoctorSchedule::getDoctorId, doctorId)
                .gt(DoctorSchedule::getRemainQuota, 0)
                .orderByAsc(DoctorSchedule::getScheduleDate)));
    }

    @PostMapping("/schedule/save")
    public Result<DoctorSchedule> saveSchedule(@RequestBody DoctorSchedule schedule) {
        AuthContext.requireAdmin();
        if (schedule.getDoctorId() == null || schedule.getScheduleDate() == null
                || schedule.getTimeSlot() == null || schedule.getTimeSlot().isBlank()) {
            throw new BusinessException("请完善医生、日期和时段");
        }
        if (schedule.getTotalQuota() == null || schedule.getTotalQuota() <= 0) {
            throw new BusinessException("号源数量必须大于0");
        }
        if (schedule.getId() == null) {
            long duplicate = scheduleService.count(new LambdaQueryWrapper<DoctorSchedule>()
                    .eq(DoctorSchedule::getDoctorId, schedule.getDoctorId())
                    .eq(DoctorSchedule::getScheduleDate, schedule.getScheduleDate())
                    .eq(DoctorSchedule::getTimeSlot, schedule.getTimeSlot()));
            if (duplicate > 0) {
                throw new BusinessException("该医生在该日期时段已有排班");
            }
            schedule.setRemainQuota(schedule.getTotalQuota());
        } else {
            DoctorSchedule exists = scheduleService.getById(schedule.getId());
            if (exists == null) {
                throw new BusinessException("排班不存在");
            }
            int booked = exists.getTotalQuota() - exists.getRemainQuota();
            if (schedule.getTotalQuota() < booked) {
                throw new BusinessException("总号源不能小于已预约数量");
            }
            schedule.setRemainQuota(schedule.getTotalQuota() - booked);
        }
        scheduleService.saveOrUpdate(schedule);
        return Result.ok(schedule);
    }

    @GetMapping("/schedules/manage")
    public Result<List<Map<String, Object>>> manageSchedules(@RequestParam Long doctorId,
                                                              @RequestParam(required = false) String startDate,
                                                              @RequestParam(required = false) String endDate) {
        AuthContext.requireAdmin();
        return Result.ok(buildScheduleRows(doctorId, startDate, endDate));
    }

    @GetMapping("/schedules/mine")
    public Result<List<Map<String, Object>>> mySchedules(@RequestParam(required = false) String startDate,
                                                        @RequestParam(required = false) String endDate) {
        AuthUser authUser = AuthContext.get();
        if (authUser == null || !"DOCTOR".equals(authUser.getRole())) {
            throw new BusinessException("仅医生可查看本人排班");
        }
        Doctor doctor = doctorService.getOne(new LambdaQueryWrapper<Doctor>()
                .eq(Doctor::getUserId, authUser.getUserId()).last("limit 1"));
        if (doctor == null) {
            throw new BusinessException("未找到医生档案，请联系管理员");
        }
        return Result.ok(buildScheduleRows(doctor.getId(), startDate, endDate));
    }

    @PostMapping("/schedule/batch")
    public Result<Map<String, Object>> batchSchedule(@RequestBody BatchScheduleRequest request) {
        AuthContext.requireAdmin();
        if (request.getDoctorId() == null || request.getStartDate() == null || request.getEndDate() == null) {
            throw new BusinessException("请选择医生和排班日期范围");
        }
        if (request.getWeekdays() == null || request.getWeekdays().isEmpty()) {
            throw new BusinessException("请至少选择一个工作日");
        }
        if (request.getTimeSlots() == null || request.getTimeSlots().isEmpty()) {
            throw new BusinessException("请至少选择一个时段");
        }
        if (request.getTotalQuota() == null || request.getTotalQuota() <= 0) {
            throw new BusinessException("号源数量必须大于0");
        }
        if (request.getEndDate().isBefore(request.getStartDate())) {
            throw new BusinessException("结束日期不能早于开始日期");
        }
        Set<Integer> weekdaySet = new HashSet<>(request.getWeekdays());
        int created = 0;
        int skipped = 0;
        for (LocalDate date = request.getStartDate(); !date.isAfter(request.getEndDate()); date = date.plusDays(1)) {
            if (!weekdaySet.contains(date.getDayOfWeek().getValue())) {
                continue;
            }
            for (String timeSlot : request.getTimeSlots()) {
                long duplicate = scheduleService.count(new LambdaQueryWrapper<DoctorSchedule>()
                        .eq(DoctorSchedule::getDoctorId, request.getDoctorId())
                        .eq(DoctorSchedule::getScheduleDate, date)
                        .eq(DoctorSchedule::getTimeSlot, timeSlot));
                if (duplicate > 0) {
                    skipped++;
                    continue;
                }
                DoctorSchedule schedule = new DoctorSchedule();
                schedule.setDoctorId(request.getDoctorId());
                schedule.setScheduleDate(date);
                schedule.setTimeSlot(timeSlot);
                schedule.setTotalQuota(request.getTotalQuota());
                schedule.setRemainQuota(request.getTotalQuota());
                scheduleService.save(schedule);
                created++;
            }
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("created", created);
        result.put("skipped", skipped);
        return Result.ok(result);
    }

    @GetMapping("/schedule/delete-check/{id}")
    public Result<Map<String, Object>> scheduleDeleteCheck(@PathVariable Long id) {
        AuthContext.requireAdmin();
        return Result.ok(buildScheduleDeleteInfo(id));
    }

    @PostMapping("/schedule/delete/{id}")
    public Result<Void> deleteSchedule(@PathVariable Long id) {
        AuthContext.requireAdmin();
        ensureScheduleDeletable(id);
        scheduleService.removeById(id);
        return Result.ok();
    }

    @PostMapping("/appointment/create")
    public Result<Appointment> createAppointment(@RequestBody Appointment appointment) {
        if (appointment.getUserId() == null || appointment.getScheduleId() == null) {
            throw new BusinessException("请选择用户和预约排班");
        }
        accessService.assertOwnUserId(appointment.getUserId());
        DoctorSchedule schedule = scheduleService.getById(appointment.getScheduleId());
        if (schedule == null || schedule.getRemainQuota() == null || schedule.getRemainQuota() <= 0) {
            throw new BusinessException("当前排班无可预约号源");
        }
        Doctor doctor = doctorService.getById(schedule.getDoctorId());
        if (doctor == null) {
            throw new BusinessException("医生信息不存在");
        }
        long duplicate = appointmentService.count(new LambdaQueryWrapper<Appointment>()
                .eq(Appointment::getUserId, appointment.getUserId())
                .eq(Appointment::getScheduleId, appointment.getScheduleId())
                .eq(Appointment::getStatus, "CONFIRMED"));
        if (duplicate > 0) {
            throw new BusinessException("你已预约该时段，请勿重复预约");
        }
        appointment.setHospitalId(doctor.getHospitalId());
        appointment.setDepartmentId(doctor.getDepartmentId());
        appointment.setDoctorId(schedule.getDoctorId());
        appointment.setAppointmentDate(schedule.getScheduleDate());
        appointment.setTimeSlot(schedule.getTimeSlot());
        appointment.setStatus("CONFIRMED");
        appointment.setCreateTime(LocalDateTime.now());
        appointment.setRemindTime(schedule.getScheduleDate().minusDays(1).atTime(9, 0));
        appointmentService.save(appointment);

        schedule.setRemainQuota(schedule.getRemainQuota() - 1);
        scheduleService.updateById(schedule);
        return Result.ok(appointment);
    }

    @PostMapping("/appointment/cancel/{id}")
    public Result<Appointment> cancel(@PathVariable Long id) {
        Appointment appointment = appointmentService.getById(id);
        if (appointment == null) {
            throw new BusinessException("预约不存在");
        }
        accessService.assertAppointmentAccess(appointment);
        if ("FINISHED".equals(appointment.getStatus())) {
            throw new BusinessException("已完成就诊的预约不能取消");
        }
        if ("CONFIRMED".equals(appointment.getStatus())) {
            appointment.setStatus("CANCELLED");
            appointmentService.updateById(appointment);
            DoctorSchedule schedule = scheduleService.getById(appointment.getScheduleId());
            if (schedule != null) {
                schedule.setRemainQuota(schedule.getRemainQuota() + 1);
                scheduleService.updateById(schedule);
            }
        }
        return Result.ok(appointment);
    }

    @PostMapping("/appointment/finish/{id}")
    public Result<Appointment> finish(@PathVariable Long id) {
        Appointment appointment = appointmentService.getById(id);
        if (appointment == null) {
            throw new BusinessException("预约不存在");
        }
        AuthUser user = accessService.requireLogin();
        if (!"ADMIN".equals(user.getRole()) && !"DOCTOR".equals(user.getRole())) {
            throw new BusinessException("无权完成就诊");
        }
        accessService.assertAppointmentAccess(appointment);
        if (!"CONFIRMED".equals(appointment.getStatus())) {
            throw new BusinessException("只有已确认预约可以完成就诊");
        }
        appointment.setStatus("FINISHED");
        appointmentService.updateById(appointment);
        return Result.ok(appointment);
    }

    @GetMapping("/appointments")
    public Result<List<Map<String, Object>>> appointments(@RequestParam(required = false) Long userId,
                                                           @RequestParam(required = false) Long doctorId) {
        AuthUser user = accessService.requireLogin();
        LambdaQueryWrapper<Appointment> wrapper = new LambdaQueryWrapper<>();
        if (accessService.isAdmin(user)) {
            if (userId != null) {
                wrapper.eq(Appointment::getUserId, userId);
            }
            if (doctorId != null) {
                wrapper.eq(Appointment::getDoctorId, doctorId);
            }
        } else if (accessService.isUser(user)) {
            wrapper.eq(Appointment::getUserId, user.getUserId());
        } else if (accessService.isDoctor(user)) {
            Long currentDoctorId = accessService.currentDoctorId(user);
            if (currentDoctorId == null) {
                throw new BusinessException("未找到医生档案");
            }
            wrapper.eq(Appointment::getDoctorId, currentDoctorId);
        } else {
            throw new BusinessException("无权查看预约");
        }
        wrapper.orderByDesc(Appointment::getAppointmentDate).orderByDesc(Appointment::getCreateTime);
        List<Appointment> list = appointmentService.list(wrapper);
        Map<Long, String> hospitalNames = hospitalService.list().stream()
                .collect(Collectors.toMap(Hospital::getId, Hospital::getName, (a, b) -> a));
        Map<Long, String> departmentNames = departmentService.list().stream()
                .collect(Collectors.toMap(Department::getId, Department::getName, (a, b) -> a));
        Map<Long, Doctor> doctorMap = doctorService.list().stream()
                .collect(Collectors.toMap(Doctor::getId, item -> item, (a, b) -> a));
        Map<Long, String> userNames = sysUserService.list().stream()
                .collect(Collectors.toMap(SysUser::getId, u -> u.getRealName() != null ? u.getRealName() : u.getUsername(), (a, b) -> a));
        List<Map<String, Object>> rows = new ArrayList<>();
        for (Appointment item : list) {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("id", item.getId());
            row.put("userId", item.getUserId());
            row.put("userName", userNames.getOrDefault(item.getUserId(), "未知用户"));
            row.put("hospitalId", item.getHospitalId());
            row.put("departmentId", item.getDepartmentId());
            row.put("doctorId", item.getDoctorId());
            row.put("scheduleId", item.getScheduleId());
            row.put("appointmentDate", item.getAppointmentDate());
            row.put("timeSlot", item.getTimeSlot());
            row.put("status", item.getStatus());
            row.put("symptom", item.getSymptom());
            row.put("hospitalName", hospitalNames.getOrDefault(item.getHospitalId(), "未知医院"));
            row.put("departmentName", departmentNames.getOrDefault(item.getDepartmentId(), "未知科室"));
            Doctor doctor = doctorMap.get(item.getDoctorId());
            row.put("doctorName", doctor == null ? "未知医生" : doctor.getTitle() + " · " + doctor.getSpecialty());
            rows.add(row);
        }
        return Result.ok(rows);
    }

    private List<Map<String, Object>> buildScheduleRows(Long doctorId, String startDate, String endDate) {
        LambdaQueryWrapper<DoctorSchedule> wrapper = new LambdaQueryWrapper<DoctorSchedule>()
                .eq(DoctorSchedule::getDoctorId, doctorId)
                .orderByAsc(DoctorSchedule::getScheduleDate)
                .orderByAsc(DoctorSchedule::getTimeSlot);
        if (startDate != null && !startDate.isBlank()) {
            wrapper.ge(DoctorSchedule::getScheduleDate, LocalDate.parse(startDate));
        }
        if (endDate != null && !endDate.isBlank()) {
            wrapper.le(DoctorSchedule::getScheduleDate, LocalDate.parse(endDate));
        }
        Doctor doctor = doctorService.getById(doctorId);
        SysUser doctorUser = doctor == null ? null : sysUserService.getById(doctor.getUserId());
        String doctorLabel = doctor == null ? "未知医生" : doctor.getTitle() + " · " + doctor.getSpecialty();
        if (doctorUser != null && doctorUser.getRealName() != null) {
            doctorLabel = doctorUser.getRealName() + " / " + doctorLabel;
        }
        List<Map<String, Object>> rows = new ArrayList<>();
        for (DoctorSchedule item : scheduleService.list(wrapper)) {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("id", item.getId());
            row.put("doctorId", item.getDoctorId());
            row.put("doctorName", doctorLabel);
            row.put("scheduleDate", item.getScheduleDate());
            row.put("timeSlot", item.getTimeSlot());
            row.put("totalQuota", item.getTotalQuota());
            row.put("remainQuota", item.getRemainQuota());
            row.put("bookedQuota", item.getTotalQuota() - item.getRemainQuota());
            rows.add(row);
        }
        return rows;
    }

    private Map<String, Object> buildHospitalDeleteInfo(Long id) {
        Hospital hospital = hospitalService.getById(id);
        if (hospital == null) {
            throw new BusinessException("医院不存在");
        }
        long departmentCount = departmentService.count(new LambdaQueryWrapper<Department>().eq(Department::getHospitalId, id));
        long doctorCount = doctorService.count(new LambdaQueryWrapper<Doctor>().eq(Doctor::getHospitalId, id));
        long appointmentCount = appointmentService.count(new LambdaQueryWrapper<Appointment>().eq(Appointment::getHospitalId, id));
        return buildDeleteInfo("医院", departmentCount, doctorCount, appointmentCount, 0, 0, 0);
    }

    private Map<String, Object> buildDepartmentDeleteInfo(Long id) {
        Department department = departmentService.getById(id);
        if (department == null) {
            throw new BusinessException("科室不存在");
        }
        long doctorCount = doctorService.count(new LambdaQueryWrapper<Doctor>().eq(Doctor::getDepartmentId, id));
        long appointmentCount = appointmentService.count(new LambdaQueryWrapper<Appointment>().eq(Appointment::getDepartmentId, id));
        return buildDeleteInfo("科室", 0, doctorCount, appointmentCount, 0, 0, 0);
    }

    private Map<String, Object> buildDoctorDeleteInfo(Long id) {
        Doctor doctor = doctorService.getById(id);
        if (doctor == null) {
            throw new BusinessException("医生不存在");
        }
        long scheduleCount = scheduleService.count(new LambdaQueryWrapper<DoctorSchedule>().eq(DoctorSchedule::getDoctorId, id));
        long appointmentCount = appointmentService.count(new LambdaQueryWrapper<Appointment>().eq(Appointment::getDoctorId, id));
        long consultationCount = consultationService.count(new LambdaQueryWrapper<Consultation>().eq(Consultation::getDoctorId, id));
        return buildDeleteInfo("医生", 0, 0, appointmentCount, scheduleCount, consultationCount, 0);
    }

    private Map<String, Object> buildScheduleDeleteInfo(Long id) {
        DoctorSchedule schedule = scheduleService.getById(id);
        if (schedule == null) {
            throw new BusinessException("排班不存在");
        }
        long confirmedAppointments = appointmentService.count(new LambdaQueryWrapper<Appointment>()
                .eq(Appointment::getScheduleId, id)
                .eq(Appointment::getStatus, "CONFIRMED"));
        return buildDeleteInfo("排班", 0, 0, confirmedAppointments, 0, 0, 0);
    }

    private Map<String, Object> buildDeleteInfo(String entityLabel, long departmentCount, long doctorCount,
                                                long appointmentCount, long scheduleCount,
                                                long consultationCount, long bookedCount) {
        List<String> parts = new ArrayList<>();
        if (departmentCount > 0) {
            parts.add(departmentCount + " 个科室");
        }
        if (doctorCount > 0) {
            parts.add(doctorCount + " 名医生");
        }
        if (scheduleCount > 0) {
            parts.add(scheduleCount + " 条排班");
        }
        if (consultationCount > 0) {
            parts.add(consultationCount + " 条咨询");
        }
        if (appointmentCount > 0) {
            parts.add(appointmentCount + " 条预约");
        }
        if (bookedCount > 0) {
            parts.add(bookedCount + " 个已预约号源");
        }
        Map<String, Object> info = new LinkedHashMap<>();
        info.put("departmentCount", departmentCount);
        info.put("doctorCount", doctorCount);
        info.put("scheduleCount", scheduleCount);
        info.put("consultationCount", consultationCount);
        info.put("appointmentCount", appointmentCount);
        info.put("bookedCount", bookedCount);
        info.put("canDelete", parts.isEmpty());
        info.put("message", parts.isEmpty() ? "可以删除" : "无法删除：该" + entityLabel + "仍有关联 " + String.join("、", parts));
        return info;
    }

    private void ensureHospitalDeletable(Long id) {
        Map<String, Object> info = buildHospitalDeleteInfo(id);
        if (!Boolean.TRUE.equals(info.get("canDelete"))) {
            throw new BusinessException(String.valueOf(info.get("message")));
        }
    }

    private void ensureDepartmentDeletable(Long id) {
        Map<String, Object> info = buildDepartmentDeleteInfo(id);
        if (!Boolean.TRUE.equals(info.get("canDelete"))) {
            throw new BusinessException(String.valueOf(info.get("message")));
        }
    }

    private void ensureDoctorDeletable(Long id) {
        Map<String, Object> info = buildDoctorDeleteInfo(id);
        if (!Boolean.TRUE.equals(info.get("canDelete"))) {
            throw new BusinessException(String.valueOf(info.get("message")));
        }
    }

    private void ensureScheduleDeletable(Long id) {
        Map<String, Object> info = buildScheduleDeleteInfo(id);
        if (!Boolean.TRUE.equals(info.get("canDelete"))) {
            throw new BusinessException(String.valueOf(info.get("message")));
        }
    }
}
