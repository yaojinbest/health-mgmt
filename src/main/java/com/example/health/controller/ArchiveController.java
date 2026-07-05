package com.example.health.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.example.health.common.AccessService;
import com.example.health.common.AuthUser;
import com.example.health.common.BusinessException;
import com.example.health.common.Result;
import com.example.health.entity.ArchiveFile;
import com.example.health.entity.HealthArchive;
import com.example.health.service.ArchiveFileService;
import com.example.health.service.HealthArchiveService;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/archive")
public class ArchiveController {
    private final HealthArchiveService archiveService;
    private final ArchiveFileService fileService;
    private final AccessService accessService;

    @Value("${app.upload-dir:uploads}")
    private String uploadDir;

    @GetMapping("/{userId}")
    public Result<Map<String, Object>> get(@PathVariable Long userId) {
        accessService.assertSelfOrStaff(userId);
        HealthArchive archive = archiveService.getOne(new LambdaQueryWrapper<HealthArchive>()
                .eq(HealthArchive::getUserId, userId).last("limit 1"));
        List<ArchiveFile> files = archive == null ? List.of() : fileService.list(new LambdaQueryWrapper<ArchiveFile>()
                .eq(ArchiveFile::getArchiveId, archive.getId()).orderByDesc(ArchiveFile::getUploadTime));
        Map<String, Object> data = new HashMap<>();
        data.put("archive", archive);
        data.put("files", files);
        return Result.ok(data);
    }

    @PostMapping("/save")
    public Result<HealthArchive> save(@RequestBody HealthArchive archive) {
        if (archive.getUserId() == null) {
            throw new BusinessException("用户ID不能为空");
        }
        accessService.assertOwnUserId(archive.getUserId());
        HealthArchive exists = archiveService.getOne(new LambdaQueryWrapper<HealthArchive>()
                .eq(HealthArchive::getUserId, archive.getUserId()).last("limit 1"));
        archive.setUpdateTime(LocalDateTime.now());
        if (exists != null) {
            archive.setId(exists.getId());
        }
        if (archive.getPrivacyLevel() == null || archive.getPrivacyLevel().isBlank()) {
            archive.setPrivacyLevel("AUTHORIZED_DOCTOR");
        }
        archiveService.saveOrUpdate(archive);
        return Result.ok(archive);
    }

    @PostMapping("/{archiveId}/upload")
    public Result<ArchiveFile> upload(@PathVariable Long archiveId, @RequestParam("file") MultipartFile file) throws Exception {
        HealthArchive archive = archiveService.getById(archiveId);
        if (archive == null) {
            throw new BusinessException("健康档案不存在");
        }
        accessService.assertOwnUserId(archive.getUserId());
        if (file.isEmpty()) {
            throw new BusinessException("请选择文件");
        }
        File dir = new File(uploadDir);
        if (!dir.exists() && !dir.mkdirs()) {
            throw new BusinessException("上传目录创建失败");
        }
        String original = file.getOriginalFilename() == null ? "archive.pdf" : file.getOriginalFilename();
        String saved = System.currentTimeMillis() + "_" + original.replaceAll("\\s+", "_");
        file.transferTo(new File(dir, saved));

        ArchiveFile archiveFile = new ArchiveFile();
        archiveFile.setArchiveId(archiveId);
        archiveFile.setFileName(original);
        archiveFile.setFileUrl("/uploads/" + saved);
        archiveFile.setUploadTime(LocalDateTime.now());
        fileService.save(archiveFile);
        return Result.ok(archiveFile);
    }

    @GetMapping("/list")
    public Result<List<HealthArchive>> list() {
        AuthUser user = accessService.requireLogin();
        LambdaQueryWrapper<HealthArchive> wrapper = new LambdaQueryWrapper<HealthArchive>()
                .orderByDesc(HealthArchive::getUpdateTime);
        if (accessService.isAdmin(user)) {
            return Result.ok(archiveService.list(wrapper));
        }
        if (accessService.isDoctor(user)) {
            Long doctorId = accessService.currentDoctorId(user);
            if (doctorId == null) {
                throw new BusinessException("未找到医生档案");
            }
            List<Long> patientIds = accessService.doctorPatientIds(doctorId).stream().toList();
            if (patientIds.isEmpty()) {
                return Result.ok(List.of());
            }
            wrapper.in(HealthArchive::getUserId, patientIds);
            return Result.ok(archiveService.list(wrapper));
        }
        throw new BusinessException("无权查看档案列表");
    }
}
