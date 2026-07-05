package com.example.health.common;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class Result<T> {
    private Integer code;
    private String message;
    private T data;

    public static <T> Result<T> ok(T data) {
        return new Result<>(200, "操作成功", data);
    }

    public static Result<Void> ok() {
        return new Result<>(200, "操作成功", null);
    }

    public static <T> Result<T> fail(String message) {
        return new Result<>(500, message, null);
    }

    /**
     * 业务异常专用, 带 HTTP 语义 code (400 / 401 / 403 / 404 / 409).
     * 区别于 fail(): 区分业务异常 vs 系统异常.
     * 前端 axios 拦截器根据 code 判断 (401=跳登录, 403=toast 权限不足).
     */
    public static <T> Result<T> error(int code, String message) {
        return new Result<>(code, message, null);
    }
}
