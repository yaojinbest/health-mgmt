package com.example.health.entity;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("health_article")
public class HealthArticle {
    @TableId
    private Long id;
    private String title;
    private String category;
    private String diseaseTag;
    private String summary;
    private String content;
    private Long authorId;
    private Integer viewCount;
    private LocalDateTime publishTime;
}
