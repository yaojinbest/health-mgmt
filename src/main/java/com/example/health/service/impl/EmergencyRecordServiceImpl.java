package com.example.health.service.impl;

import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.example.health.entity.EmergencyRecord;
import com.example.health.mapper.EmergencyRecordMapper;
import com.example.health.service.EmergencyRecordService;
import org.springframework.stereotype.Service;

@Service
public class EmergencyRecordServiceImpl extends ServiceImpl<EmergencyRecordMapper, EmergencyRecord> implements EmergencyRecordService {
}
