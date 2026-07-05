package com.example.health.entity;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("consultation_message")
public class ConsultationMessage {
    @TableId
    private Long id;
    private Long consultationId;
    private Long senderId;
    private String senderRole;
    private String messageType;
    private String content;
    private LocalDateTime sendTime;
}
