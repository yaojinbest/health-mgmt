package com.example.health.service.impl;

import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.example.health.entity.ConsultationMessage;
import com.example.health.mapper.ConsultationMessageMapper;
import com.example.health.service.ConsultationMessageService;
import org.springframework.stereotype.Service;

@Service
public class ConsultationMessageServiceImpl extends ServiceImpl<ConsultationMessageMapper, ConsultationMessage> implements ConsultationMessageService {
}
