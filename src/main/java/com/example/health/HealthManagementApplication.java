package com.example.health;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@MapperScan("com.example.health.mapper")
@SpringBootApplication
public class HealthManagementApplication {
    public static void main(String[] args) {
        SpringApplication.run(HealthManagementApplication.class, args);
    }
}
