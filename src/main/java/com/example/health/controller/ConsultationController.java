package com.example.health.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.example.health.common.AccessService;
import com.example.health.common.AuthContext;
import com.example.health.common.AuthUser;
import com.example.health.common.BusinessException;
import com.example.health.common.PageRequest;
import com.example.health.common.PageResult;
import com.example.health.common.Result;
import com.example.health.entity.Consultation;
import com.example.health.entity.ConsultationMessage;
import com.example.health.entity.Doctor;
import com.example.health.entity.SysUser;
import com.example.health.service.ConsultationMessageService;
import com.example.health.service.ConsultationService;
import com.example.health.service.DoctorService;
import com.example.health.service.SysUserService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/consultations")
public class ConsultationController {
    private final ConsultationService consultationService;
    private final ConsultationMessageService messageService;
    private final SysUserService sysUserService;
    private final DoctorService doctorService;
    private final AccessService accessService;

    @PostMapping("/create")
    public Result<Consultation> create(@RequestBody Consultation consultation) {
        if (consultation.getUserId() == null || consultation.getDoctorId() == null) {
            throw new BusinessException("请选择咨询医生");
        }
        accessService.assertOwnUserId(consultation.getUserId());
        if (consultation.getTitle() == null || consultation.getTitle().isBlank()) {
            consultation.setTitle("健康咨询");
        }
        consultation.setStatus("OPEN");
        consultation.setCreateTime(LocalDateTime.now());
        consultationService.save(consultation);
        return Result.ok(consultation);
    }

    @GetMapping
    public Result<List<Map<String, Object>>> list(@RequestParam(required = false) Long userId,
                                                  @RequestParam(required = false) Long doctorId) {
        AuthUser user = accessService.requireLogin();
        LambdaQueryWrapper<Consultation> wrapper = new LambdaQueryWrapper<>();
        if (accessService.isAdmin(user)) {
            if (userId != null) {
                wrapper.eq(Consultation::getUserId, userId);
            }
            if (doctorId != null) {
                wrapper.eq(Consultation::getDoctorId, doctorId);
            }
        } else if (accessService.isUser(user)) {
            wrapper.eq(Consultation::getUserId, user.getUserId());
        } else if (accessService.isDoctor(user)) {
            Long currentDoctorId = accessService.currentDoctorId(user);
            if (currentDoctorId == null) {
                throw new BusinessException("未找到医生档案");
            }
            wrapper.eq(Consultation::getDoctorId, currentDoctorId);
        } else {
            throw new BusinessException("无权查看咨询");
        }
        wrapper.orderByDesc(Consultation::getCreateTime);
        Map<Long, String> userNames = sysUserService.list().stream()
                .collect(Collectors.toMap(SysUser::getId, u -> u.getRealName() != null ? u.getRealName() : u.getUsername(), (a, b) -> a));
        Map<Long, Doctor> doctorMap = doctorService.list().stream()
                .collect(Collectors.toMap(Doctor::getId, item -> item, (a, b) -> a));
        List<Map<String, Object>> rows = new ArrayList<>();
        for (Consultation item : consultationService.list(wrapper)) {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("id", item.getId());
            row.put("userId", item.getUserId());
            row.put("doctorId", item.getDoctorId());
            row.put("userName", userNames.getOrDefault(item.getUserId(), "未知用户"));
            Doctor doctor = doctorMap.get(item.getDoctorId());
            row.put("doctorName", doctor == null ? "未知医生" : doctor.getTitle() + " · " + doctor.getSpecialty());
            row.put("title", item.getTitle());
            row.put("status", item.getStatus());
            row.put("createTime", item.getCreateTime());
            row.put("followUpTime", item.getFollowUpTime());
            long messageCount = messageService.count(new LambdaQueryWrapper<ConsultationMessage>()
                    .eq(ConsultationMessage::getConsultationId, item.getId()));
            row.put("messageCount", messageCount);
            rows.add(row);
        }
        return Result.ok(rows);
    }

    /**
     * 咨询会话列表 - 分页 (PC Web 桌面端专用, 2026-07-05 进哥拍板 Q4-B)
     *
     * 路径: GET /api/consultations/page?page=1&size=20&userId=X&doctorId=Y&status=OPEN
     *
     * 权限: admin 看全部; user 看自己; doctor 看分配给自己的
     * 搜索: keyword 按 title 模糊查询 (简易版, PC Web 一般用下拉过滤)
     */
    @GetMapping("/page")
    public Result<PageResult<Map<String, Object>>> listPage(
            @ModelAttribute PageRequest pageRequest,
            @RequestParam(required = false) Long userId,
            @RequestParam(required = false) Long doctorId,
            @RequestParam(required = false) String status) {
        AuthUser user = accessService.requireLogin();
        pageRequest.sanitize();

        LambdaQueryWrapper<Consultation> wrapper = new LambdaQueryWrapper<>();
        if (accessService.isAdmin(user)) {
            if (userId != null) wrapper.eq(Consultation::getUserId, userId);
            if (doctorId != null) wrapper.eq(Consultation::getDoctorId, doctorId);
        } else if (accessService.isUser(user)) {
            wrapper.eq(Consultation::getUserId, user.getUserId());
        } else if (accessService.isDoctor(user)) {
            Long currentDoctorId = accessService.currentDoctorId(user);
            if (currentDoctorId == null) {
                throw new BusinessException("未找到医生档案");
            }
            wrapper.eq(Consultation::getDoctorId, currentDoctorId);
        } else {
            throw new BusinessException("无权查看咨询");
        }
        if (status != null && !status.isBlank()) {
            wrapper.eq(Consultation::getStatus, status);
        }
        if (pageRequest.getKeyword() != null && !pageRequest.getKeyword().isBlank()) {
            wrapper.like(Consultation::getTitle, pageRequest.getKeyword());
        }
        wrapper.orderByDesc(Consultation::getCreateTime);

        // 先 count, 再 list (避免分页 + 关联查询的复杂性, PC Web 桌面对实时性不敏感)
        long total = consultationService.count(wrapper);
        IPage<Consultation> pageResult = consultationService.page(
                Page.of(pageRequest.getPage(), pageRequest.getSize()),
                wrapper);

        Map<Long, String> userNames = sysUserService.list().stream()
                .collect(Collectors.toMap(SysUser::getId, u -> u.getRealName() != null ? u.getRealName() : u.getUsername(), (a, b) -> a));
        Map<Long, Doctor> doctorMap = doctorService.list().stream()
                .collect(Collectors.toMap(Doctor::getId, item -> item, (a, b) -> a));

        List<Map<String, Object>> rows = new ArrayList<>();
        for (Consultation item : pageResult.getRecords()) {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("id", item.getId());
            row.put("userId", item.getUserId());
            row.put("doctorId", item.getDoctorId());
            row.put("userName", userNames.getOrDefault(item.getUserId(), "未知用户"));
            Doctor doctor = doctorMap.get(item.getDoctorId());
            row.put("doctorName", doctor == null ? "未知医生" : doctor.getTitle() + " · " + doctor.getSpecialty());
            row.put("title", item.getTitle());
            row.put("status", item.getStatus());
            row.put("createTime", item.getCreateTime());
            row.put("followUpTime", item.getFollowUpTime());
            long messageCount = messageService.count(new LambdaQueryWrapper<ConsultationMessage>()
                    .eq(ConsultationMessage::getConsultationId, item.getId()));
            row.put("messageCount", messageCount);
            rows.add(row);
        }

        return Result.ok(PageResult.of(rows, total, pageRequest.getPage(), pageRequest.getSize()));
    }

    @PostMapping("/message/send")
    public Result<ConsultationMessage> send(@RequestBody ConsultationMessage message) {
        Consultation consultation = consultationService.getById(message.getConsultationId());
        if (consultation == null) {
            throw new BusinessException("咨询会话不存在");
        }
        accessService.assertConsultationAccess(consultation);
        AuthUser user = accessService.requireLogin();
        if (message.getSenderId() == null || !user.getUserId().equals(message.getSenderId())) {
            throw new BusinessException("发送者身份不匹配");
        }
        if (message.getSenderRole() == null || !user.getRole().equals(message.getSenderRole())) {
            throw new BusinessException("发送者角色不匹配");
        }
        if ("CLOSED".equals(consultation.getStatus())) {
            throw new BusinessException("咨询已关闭，不能继续发送消息");
        }
        if (message.getContent() == null || message.getContent().isBlank()) {
            throw new BusinessException("消息内容不能为空");
        }
        message.setSendTime(LocalDateTime.now());
        if (message.getMessageType() == null) {
            message.setMessageType("TEXT");
        }
        messageService.save(message);
        return Result.ok(message);
    }

    @GetMapping("/{consultationId}/messages")
    public Result<List<ConsultationMessage>> messages(@PathVariable Long consultationId) {
        Consultation consultation = consultationService.getById(consultationId);
        if (consultation == null) {
            throw new BusinessException("咨询会话不存在");
        }
        accessService.assertConsultationAccess(consultation);
        return Result.ok(messageService.list(new LambdaQueryWrapper<ConsultationMessage>()
                .eq(ConsultationMessage::getConsultationId, consultationId)
                .orderByAsc(ConsultationMessage::getSendTime)));
    }

    @PostMapping("/close/{id}")
    public Result<Consultation> close(@PathVariable Long id) {
        Consultation consultation = consultationService.getById(id);
        if (consultation == null) {
            throw new BusinessException("咨询会话不存在");
        }
        accessService.assertConsultationAccess(consultation);
        consultation.setStatus("CLOSED");
        consultationService.updateById(consultation);
        return Result.ok(consultation);
    }

    @PostMapping("/follow-up/{id}")
    public Result<Consultation> followUp(@PathVariable Long id, @RequestParam String followUpTime) {
        Consultation consultation = consultationService.getById(id);
        if (consultation == null) {
            throw new BusinessException("咨询会话不存在");
        }
        AuthUser user = accessService.requireLogin();
        if (!accessService.isDoctor(user) && !accessService.isAdmin(user)) {
            throw new BusinessException("仅医生可设置复诊时间");
        }
        accessService.assertConsultationAccess(consultation);
        consultation.setFollowUpTime(LocalDateTime.parse(followUpTime.replace(" ", "T")));
        consultationService.updateById(consultation);
        return Result.ok(consultation);
    }

    @GetMapping("/delete-check/{id}")
    public Result<Map<String, Object>> deleteCheck(@PathVariable Long id) {
        Consultation consultation = requireConsultation(id);
        ensureConsultationAccess(consultation);
        return Result.ok(buildConsultationDeleteInfo(consultation));
    }

    @PostMapping("/delete/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        Consultation consultation = requireConsultation(id);
        ensureConsultationAccess(consultation);
        ensureConsultationDeletable(consultation);
        messageService.remove(new LambdaQueryWrapper<ConsultationMessage>()
                .eq(ConsultationMessage::getConsultationId, id));
        consultationService.removeById(id);
        return Result.ok();
    }

    private Consultation requireConsultation(Long id) {
        Consultation consultation = consultationService.getById(id);
        if (consultation == null) {
            throw new BusinessException("咨询会话不存在");
        }
        return consultation;
    }

    private void ensureConsultationAccess(Consultation consultation) {
        accessService.assertConsultationAccess(consultation);
    }

    private Map<String, Object> buildConsultationDeleteInfo(Consultation consultation) {
        long messageCount = messageService.count(new LambdaQueryWrapper<ConsultationMessage>()
                .eq(ConsultationMessage::getConsultationId, consultation.getId()));
        Map<String, Object> info = new LinkedHashMap<>();
        info.put("messageCount", messageCount);
        if ("OPEN".equals(consultation.getStatus())) {
            info.put("canDelete", false);
            info.put("message", "无法删除：请先关闭该咨询会话");
            return info;
        }
        info.put("canDelete", true);
        if (messageCount > 0) {
            info.put("message", "将同时删除 " + messageCount + " 条聊天记录");
        } else {
            info.put("message", "可以删除");
        }
        return info;
    }

    private void ensureConsultationDeletable(Consultation consultation) {
        Map<String, Object> info = buildConsultationDeleteInfo(consultation);
        if (!Boolean.TRUE.equals(info.get("canDelete"))) {
            throw new BusinessException(String.valueOf(info.get("message")));
        }
    }
}
