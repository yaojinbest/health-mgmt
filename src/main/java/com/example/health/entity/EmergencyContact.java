package com.example.health.entity;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

@Data
@TableName("emergency_contact")
public class EmergencyContact {
    @TableId
    private Long id;
    private Long userId;
    private String name;
    private String relation;
    private String phone;
    private Integer sortNo;
}
