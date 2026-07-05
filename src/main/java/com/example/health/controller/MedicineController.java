package com.example.health.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.example.health.common.AccessService;
import com.example.health.common.AuthUser;
import com.example.health.common.BusinessException;
import com.example.health.common.PageRequest;
import com.example.health.common.PageResult;
import com.example.health.common.Result;
import com.example.health.entity.MedicineRecord;
import com.example.health.service.MedicineRecordService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/medicine")
public class MedicineController {
    private final MedicineRecordService medicineRecordService;
    private final AccessService accessService;

    @PostMapping("/save")
    public Result<MedicineRecord> save(@RequestBody MedicineRecord record) {
        if (record.getUserId() == null || record.getMedicineName() == null || record.getMedicineName().isBlank()) {
            throw new BusinessException("请填写用户和药品名称");
        }
        accessService.assertOwnUserId(record.getUserId());
        record.setWarning(buildWarning(record));
        if (record.getStatus() == null) {
            record.setStatus("ACTIVE");
        }
        if (record.getCreateTime() == null) {
            record.setCreateTime(LocalDateTime.now());
        }
        medicineRecordService.saveOrUpdate(record);
        return Result.ok(record);
    }

    @GetMapping("/list")
    public Result<List<MedicineRecord>> list(@RequestParam(required = false) Long userId) {
        AuthUser user = accessService.requireLogin();
        LambdaQueryWrapper<MedicineRecord> wrapper = new LambdaQueryWrapper<>();
        List<Long> scopedIds = accessService.scopedPatientIdsForList(user, userId);
        if (scopedIds != null) {
            if (scopedIds.isEmpty()) {
                return Result.ok(List.of());
            }
            wrapper.in(MedicineRecord::getUserId, scopedIds);
        }
        wrapper.orderByDesc(MedicineRecord::getCreateTime);
        return Result.ok(medicineRecordService.list(wrapper));
    }

    /**
     * 用药记录 - 分页 (PC Web 桌面端专用, 2026-07-05 进哥拍板 Q4-B)
     *
     * 路径: GET /api/medicine/list/page?page=1&size=20&userId=4&keyword=阿司&status=ACTIVE
     */
    @GetMapping("/list/page")
    public Result<PageResult<MedicineRecord>> listPage(
            @ModelAttribute PageRequest pageRequest,
            @RequestParam(required = false) Long userId,
            @RequestParam(required = false) String status) {
        AuthUser user = accessService.requireLogin();
        pageRequest.sanitize();

        LambdaQueryWrapper<MedicineRecord> wrapper = new LambdaQueryWrapper<>();
        List<Long> scopedIds = accessService.scopedPatientIdsForList(user, userId);
        if (scopedIds != null) {
            if (scopedIds.isEmpty()) {
                return Result.ok(PageResult.empty(pageRequest.getPage(), pageRequest.getSize()));
            }
            wrapper.in(MedicineRecord::getUserId, scopedIds);
        }
        if (status != null && !status.isBlank()) {
            wrapper.eq(MedicineRecord::getStatus, status);
        }
        if (pageRequest.getKeyword() != null && !pageRequest.getKeyword().isBlank()) {
            String kw = pageRequest.getKeyword();
            wrapper.and(w -> w.like(MedicineRecord::getMedicineName, kw)
                    .or().like(MedicineRecord::getDosage, kw));
        }
        wrapper.orderByDesc(MedicineRecord::getCreateTime);

        IPage<MedicineRecord> pageResult = medicineRecordService.page(
                Page.of(pageRequest.getPage(), pageRequest.getSize()),
                wrapper);

        return Result.ok(PageResult.of(pageResult.getRecords(), pageResult.getTotal(),
                pageRequest.getPage(), pageRequest.getSize()));
    }

    @PostMapping("/finish/{id}")
    public Result<MedicineRecord> finish(@PathVariable Long id) {
        MedicineRecord record = medicineRecordService.getById(id);
        if (record == null) {
            throw new BusinessException("用药记录不存在");
        }
        accessService.assertOwnUserId(record.getUserId());
        if ("FINISHED".equals(record.getStatus())) {
            return Result.ok(record);
        }
        record.setStatus("FINISHED");
        medicineRecordService.updateById(record);
        return Result.ok(record);
    }

    private String buildWarning(MedicineRecord record) {
        String name = record.getMedicineName() == null ? "" : record.getMedicineName();
        if (name.contains("华法林") || name.contains("阿司匹林")) {
            return "抗凝/抗血小板药物请遵医嘱，避免自行叠加服用";
        }
        if (name.contains("布洛芬") && name.contains("降压")) {
            return "布洛芬可能影响部分降压药效果，请咨询医生";
        }
        return "暂无冲突风险";
    }
}
