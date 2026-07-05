package com.example.health.service.impl;

import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.example.health.entity.ArchiveFile;
import com.example.health.mapper.ArchiveFileMapper;
import com.example.health.service.ArchiveFileService;
import org.springframework.stereotype.Service;

@Service
public class ArchiveFileServiceImpl extends ServiceImpl<ArchiveFileMapper, ArchiveFile> implements ArchiveFileService {
}
