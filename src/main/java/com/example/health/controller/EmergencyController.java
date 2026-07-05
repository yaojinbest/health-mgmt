package com.example.health.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.example.health.common.AccessService;
import com.example.health.common.BusinessException;
import com.example.health.common.Result;
import com.example.health.entity.*;
import com.example.health.service.EmergencyContactService;
import com.example.health.service.EmergencyRecordService;
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
@RequestMapping("/api/emergency")
public class EmergencyController {
    private final EmergencyContactService contactService;
    private final EmergencyRecordService recordService;
    private final SysUserService sysUserService;
    private final AccessService accessService;

    @PostMapping("/contact/save")
    public Result<EmergencyContact> saveContact(@RequestBody EmergencyContact contact) {
        if (contact.getUserId() == null || contact.getName() == null || contact.getName().isBlank()
                || contact.getPhone() == null || contact.getPhone().isBlank()) {
            throw new BusinessException("请填写联系人姓名和电话");
        }
        accessService.assertOwnUserId(contact.getUserId());
        contactService.saveOrUpdate(contact);
        return Result.ok(contact);
    }

    @PostMapping("/contact/delete/{id}")
    public Result<Void> deleteContact(@PathVariable Long id) {
        EmergencyContact contact = contactService.getById(id);
        if (contact == null) {
            throw new BusinessException("联系人不存在");
        }
        accessService.assertOwnUserId(contact.getUserId());
        contactService.removeById(id);
        return Result.ok();
    }

    @GetMapping("/contacts")
    public Result<List<EmergencyContact>> contacts(@RequestParam Long userId) {
        accessService.assertOwnUserId(userId);
        return Result.ok(contactService.list(new LambdaQueryWrapper<EmergencyContact>()
                .eq(EmergencyContact::getUserId, userId).orderByAsc(EmergencyContact::getSortNo)));
    }

    @PostMapping("/help")
    public Result<EmergencyRecord> help(@RequestBody EmergencyRecord record) {
        if (record.getUserId() == null) {
            throw new BusinessException("用户ID不能为空");
        }
        accessService.assertOwnUserId(record.getUserId());
        if (record.getLocationText() == null || record.getLocationText().isBlank()) {
            throw new BusinessException("请填写当前位置");
        }
        List<EmergencyContact> contacts = contactService.list(new LambdaQueryWrapper<EmergencyContact>()
                .eq(EmergencyContact::getUserId, record.getUserId()).orderByAsc(EmergencyContact::getSortNo));
        if (contacts.isEmpty()) {
            throw new BusinessException("请先设置至少一个紧急联系人");
        }
        record.setContactSnapshot(contacts.stream()
                .map(item -> item.getName() + "(" + item.getRelation() + ") " + item.getPhone())
                .collect(Collectors.joining("；")));
        record.setStatus("PROCESSING");
        record.setHelpTime(LocalDateTime.now());
        recordService.save(record);
        return Result.ok(record);
    }

    @PostMapping("/record/finish/{id}")
    public Result<EmergencyRecord> finish(@PathVariable Long id, @RequestParam(defaultValue = "已联系紧急联系人") String result) {
        accessService.requireStaff();
        EmergencyRecord record = recordService.getById(id);
        if (record == null) {
            throw new BusinessException("求救记录不存在");
        }
        record.setStatus("FINISHED");
        record.setResult(result);
        recordService.updateById(record);
        return Result.ok(record);
    }

    @GetMapping("/records")
    public Result<List<Map<String, Object>>> records(@RequestParam(required = false) Long userId) {
        var user = accessService.requireLogin();
        LambdaQueryWrapper<EmergencyRecord> wrapper = new LambdaQueryWrapper<>();
        if (accessService.isAdmin(user) || accessService.isDoctor(user)) {
            if (userId != null) {
                wrapper.eq(EmergencyRecord::getUserId, userId);
            }
        } else if (accessService.isUser(user)) {
            wrapper.eq(EmergencyRecord::getUserId, user.getUserId());
        } else {
            throw new BusinessException("无权查看救援记录");
        }
        wrapper.orderByDesc(EmergencyRecord::getHelpTime);
        Map<Long, String> userNames = sysUserService.list().stream()
                .collect(Collectors.toMap(SysUser::getId, u -> u.getRealName() != null ? u.getRealName() : u.getUsername(), (a, b) -> a));
        List<Map<String, Object>> rows = new ArrayList<>();
        for (EmergencyRecord item : recordService.list(wrapper)) {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("id", item.getId());
            row.put("userId", item.getUserId());
            row.put("userName", userNames.getOrDefault(item.getUserId(), "未知用户"));
            row.put("locationText", item.getLocationText());
            row.put("status", item.getStatus());
            row.put("helpTime", item.getHelpTime());
            row.put("result", item.getResult());
            row.put("contactSnapshot", item.getContactSnapshot());
            rows.add(row);
        }
        return Result.ok(rows);
    }
}
