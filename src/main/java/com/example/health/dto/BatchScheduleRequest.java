package com.example.health.dto;

import lombok.Data;

import java.time.LocalDate;
import java.util.List;

@Data
public class BatchScheduleRequest {
    private Long doctorId;
    private LocalDate startDate;
    private LocalDate endDate;
    private List<Integer> weekdays;
    private List<String> timeSlots;
    private Integer totalQuota;
}
