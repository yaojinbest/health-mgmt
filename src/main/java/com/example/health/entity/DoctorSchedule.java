package com.example.health.entity;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDate;

@Data
@TableName("doctor_schedule")
public class DoctorSchedule {
    @TableId
    private Long id;
    private Long doctorId;
    private LocalDate scheduleDate;
    private String timeSlot;
    private Integer totalQuota;
    private Integer remainQuota;
}
