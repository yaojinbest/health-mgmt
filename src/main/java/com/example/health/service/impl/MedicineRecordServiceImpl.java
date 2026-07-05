package com.example.health.service.impl;

import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.example.health.entity.MedicineRecord;
import com.example.health.mapper.MedicineRecordMapper;
import com.example.health.service.MedicineRecordService;
import org.springframework.stereotype.Service;

@Service
public class MedicineRecordServiceImpl extends ServiceImpl<MedicineRecordMapper, MedicineRecord> implements MedicineRecordService {
}
