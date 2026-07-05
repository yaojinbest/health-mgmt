package com.example.health.common;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.example.health.entity.Appointment;
import com.example.health.entity.Consultation;
import com.example.health.entity.Doctor;
import com.example.health.service.AppointmentService;
import com.example.health.service.ConsultationService;
import com.example.health.service.DoctorService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Component
@RequiredArgsConstructor
public class AccessService {
    private final DoctorService doctorService;
    private final AppointmentService appointmentService;
    private final ConsultationService consultationService;

    public AuthUser requireLogin() {
        AuthUser user = AuthContext.get();
        if (user == null) {
            throw new BusinessException("请先登录");
        }
        return user;
    }

    public void requireAdmin() {
        AuthContext.requireAdmin();
    }

    public void requireStaff() {
        AuthUser user = requireLogin();
        if (!"ADMIN".equals(user.getRole()) && !"DOCTOR".equals(user.getRole())) {
            throw new BusinessException("无权操作");
        }
    }

    public boolean isAdmin(AuthUser user) {
        return user != null && "ADMIN".equals(user.getRole());
    }

    public boolean isDoctor(AuthUser user) {
        return user != null && "DOCTOR".equals(user.getRole());
    }

    public boolean isUser(AuthUser user) {
        return user != null && "USER".equals(user.getRole());
    }

    public Long currentDoctorId(AuthUser user) {
        if (!isDoctor(user)) {
            return null;
        }
        Doctor doctor = doctorService.getOne(new LambdaQueryWrapper<Doctor>()
                .eq(Doctor::getUserId, user.getUserId())
                .last("limit 1"));
        return doctor == null ? null : doctor.getId();
    }

    public Set<Long> doctorPatientIds(Long doctorId) {
        Set<Long> ids = new HashSet<>();
        if (doctorId == null) {
            return ids;
        }
        appointmentService.list(new LambdaQueryWrapper<Appointment>().eq(Appointment::getDoctorId, doctorId))
                .forEach(item -> ids.add(item.getUserId()));
        consultationService.list(new LambdaQueryWrapper<Consultation>().eq(Consultation::getDoctorId, doctorId))
                .forEach(item -> ids.add(item.getUserId()));
        return ids;
    }

    public void assertSelfOrStaff(Long targetUserId) {
        AuthUser user = requireLogin();
        if (isAdmin(user)) {
            return;
        }
        if (isUser(user)) {
            if (!user.getUserId().equals(targetUserId)) {
                throw new BusinessException("无权访问该用户数据");
            }
            return;
        }
        if (isDoctor(user)) {
            Long doctorId = currentDoctorId(user);
            if (doctorId == null || !doctorPatientIds(doctorId).contains(targetUserId)) {
                throw new BusinessException("无权访问该患者数据");
            }
            return;
        }
        throw new BusinessException("无权访问");
    }

    public void assertOwnUserId(Long userId) {
        AuthUser user = requireLogin();
        if (!isUser(user) || !user.getUserId().equals(userId)) {
            throw new BusinessException("只能操作本人数据");
        }
    }

    public void assertAppointmentAccess(Appointment appointment) {
        AuthUser user = requireLogin();
        if (isAdmin(user)) {
            return;
        }
        if (isUser(user) && user.getUserId().equals(appointment.getUserId())) {
            return;
        }
        if (isDoctor(user)) {
            Long doctorId = currentDoctorId(user);
            if (doctorId != null && doctorId.equals(appointment.getDoctorId())) {
                return;
            }
        }
        throw new BusinessException("无权操作该预约");
    }

    public void assertConsultationAccess(Consultation consultation) {
        AuthUser user = requireLogin();
        if (isAdmin(user)) {
            return;
        }
        if (isUser(user) && user.getUserId().equals(consultation.getUserId())) {
            return;
        }
        if (isDoctor(user)) {
            Long doctorId = currentDoctorId(user);
            if (doctorId != null && doctorId.equals(consultation.getDoctorId())) {
                return;
            }
        }
        throw new BusinessException("无权操作该咨询会话");
    }

    public List<Long> scopedPatientIdsForList(AuthUser user, Long requestedUserId) {
        if (isAdmin(user)) {
            return requestedUserId == null ? null : List.of(requestedUserId);
        }
        if (isUser(user)) {
            return List.of(user.getUserId());
        }
        if (isDoctor(user)) {
            Long doctorId = currentDoctorId(user);
            if (doctorId == null) {
                throw new BusinessException("未找到医生档案");
            }
            Set<Long> patientIds = doctorPatientIds(doctorId);
            if (requestedUserId != null) {
                if (!patientIds.contains(requestedUserId)) {
                    throw new BusinessException("无权访问该患者数据");
                }
                return List.of(requestedUserId);
            }
            return List.copyOf(patientIds);
        }
        throw new BusinessException("无权访问");
    }
}
