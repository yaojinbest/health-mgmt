package com.example.health.service.impl;

import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.example.health.entity.HealthArchive;
import com.example.health.mapper.HealthArchiveMapper;
import com.example.health.service.HealthArchiveService;
import org.springframework.stereotype.Service;

@Service
public class HealthArchiveServiceImpl extends ServiceImpl<HealthArchiveMapper, HealthArchive> implements HealthArchiveService {
}
