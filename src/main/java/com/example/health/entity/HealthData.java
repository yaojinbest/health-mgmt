package com.example.health.entity;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@TableName("health_data")
public class HealthData {
    @TableId
    private Long id;
    private Long userId;
    private Integer systolic;
    private Integer diastolic;
    private BigDecimal bloodSugar;
    private Integer heartRate;
    private Integer steps;
    private BigDecimal sleepHours;
    private BigDecimal weight;
    private String warningLevel;
    private String warningMessage;
    private LocalDateTime recordTime;
}
