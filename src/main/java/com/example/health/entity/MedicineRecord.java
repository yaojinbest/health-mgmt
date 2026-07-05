package com.example.health.entity;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Data
@TableName("medicine_record")
public class MedicineRecord {
    @TableId
    private Long id;
    private Long userId;
    private String medicineName;
    private String usageMethod;
    private String dosage;
    private String reminderTimes;
    private LocalDate startDate;
    private LocalDate endDate;
    private String status;
    private String warning;
    private LocalDateTime createTime;
}
