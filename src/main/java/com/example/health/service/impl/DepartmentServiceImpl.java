package com.example.health.service.impl;

import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.example.health.entity.Department;
import com.example.health.mapper.DepartmentMapper;
import com.example.health.service.DepartmentService;
import org.springframework.stereotype.Service;

@Service
public class DepartmentServiceImpl extends ServiceImpl<DepartmentMapper, Department> implements DepartmentService {
}
