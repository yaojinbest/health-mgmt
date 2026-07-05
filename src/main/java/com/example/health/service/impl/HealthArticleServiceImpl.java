package com.example.health.service.impl;

import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.example.health.entity.HealthArticle;
import com.example.health.mapper.HealthArticleMapper;
import com.example.health.service.HealthArticleService;
import org.springframework.stereotype.Service;

@Service
public class HealthArticleServiceImpl extends ServiceImpl<HealthArticleMapper, HealthArticle> implements HealthArticleService {
}
