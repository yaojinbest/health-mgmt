package com.example.health.entity;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

@Data
@TableName("doctor")
public class Doctor {
    @TableId
    private Long id;
    private Long userId;
    private Long hospitalId;
    private Long departmentId;
    private String title;
    private String specialty;
    private String profile;
    private String status;
}
