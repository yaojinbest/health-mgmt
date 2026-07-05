package com.example.health.entity;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@TableName("health_archive")
public class HealthArchive {
    @TableId
    private Long id;
    private Long userId;
    private String name;
    private Integer age;
    private String gender;
    private BigDecimal height;
    private BigDecimal weight;
    private String bloodType;
    private String diseaseHistory;
    private String allergyHistory;
    private String commonMedicine;
    private String privacyLevel;
    private LocalDateTime updateTime;
}
