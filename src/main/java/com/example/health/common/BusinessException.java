package com.example.health.common;

/**
 * 业务异常.
 * code 默认 400 (客户端错误), 可在 AuthContext 等地方抛带具体 code (401/403) 的版本.
 */
public class BusinessException extends RuntimeException {

    private final int code;

    public BusinessException(String message) {
        super(message);
        this.code = 400;
    }

    public BusinessException(int code, String message) {
        super(message);
        this.code = code;
    }

    public int getCode() {
        return code;
    }
}