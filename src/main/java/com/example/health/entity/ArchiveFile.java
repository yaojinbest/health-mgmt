package com.example.health.entity;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("archive_file")
public class ArchiveFile {
    @TableId
    private Long id;
    private Long archiveId;
    private String fileName;
    private String fileUrl;
    private LocalDateTime uploadTime;
}
