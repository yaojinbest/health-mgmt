package com.example.health.service.impl;

import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.example.health.entity.DoctorSchedule;
import com.example.health.mapper.DoctorScheduleMapper;
import com.example.health.service.DoctorScheduleService;
import org.springframework.stereotype.Service;

@Service
public class DoctorScheduleServiceImpl extends ServiceImpl<DoctorScheduleMapper, DoctorSchedule> implements DoctorScheduleService {
}
