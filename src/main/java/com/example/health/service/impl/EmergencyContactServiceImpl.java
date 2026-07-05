package com.example.health.service.impl;

import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.example.health.entity.EmergencyContact;
import com.example.health.mapper.EmergencyContactMapper;
import com.example.health.service.EmergencyContactService;
import org.springframework.stereotype.Service;

@Service
public class EmergencyContactServiceImpl extends ServiceImpl<EmergencyContactMapper, EmergencyContact> implements EmergencyContactService {
}
