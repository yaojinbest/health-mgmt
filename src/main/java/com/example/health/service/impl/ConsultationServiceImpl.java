package com.example.health.service.impl;

import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.example.health.entity.Consultation;
import com.example.health.mapper.ConsultationMapper;
import com.example.health.service.ConsultationService;
import org.springframework.stereotype.Service;

@Service
public class ConsultationServiceImpl extends ServiceImpl<ConsultationMapper, Consultation> implements ConsultationService {
}
