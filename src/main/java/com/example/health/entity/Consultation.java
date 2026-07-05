package com.example.health.entity;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("consultation")
public class Consultation {
    @TableId
    private Long id;
    private Long userId;
    private Long doctorId;
    private String title;
    private String status;
    private LocalDateTime createTime;
    private LocalDateTime followUpTime;
}
