package com.example.health.service.impl;

import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.example.health.entity.HealthData;
import com.example.health.mapper.HealthDataMapper;
import com.example.health.service.HealthDataService;
import org.springframework.stereotype.Service;

@Service
public class HealthDataServiceImpl extends ServiceImpl<HealthDataMapper, HealthData> implements HealthDataService {
}
