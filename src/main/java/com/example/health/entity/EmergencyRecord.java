package com.example.health.entity;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("emergency_record")
public class EmergencyRecord {
    @TableId
    private Long id;
    private Long userId;
    private String locationText;
    private String latitude;
    private String longitude;
    private String contactSnapshot;
    private String status;
    private LocalDateTime helpTime;
    private String result;
}
