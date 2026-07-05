package com.example.health.entity;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Data
@TableName("appointment")
public class Appointment {
    @TableId
    private Long id;
    private Long userId;
    private Long hospitalId;
    private Long departmentId;
    private Long doctorId;
    private Long scheduleId;
    private LocalDate appointmentDate;
    private String timeSlot;
    private String status;
    private String symptom;
    private LocalDateTime createTime;
    private LocalDateTime remindTime;
}
