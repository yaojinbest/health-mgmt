package com.example.health.vo;

import com.example.health.entity.Doctor;
import com.example.health.entity.SysUser;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class LoginVO {
    private SysUser user;
    private Doctor doctor;
    private String token;
}
