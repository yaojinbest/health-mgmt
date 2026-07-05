package com.example.health.entity;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

@Data
@TableName("hospital")
public class Hospital {
    @TableId
    private Long id;
    private String name;
    private String level;
    private String address;
    private String phone;
}
