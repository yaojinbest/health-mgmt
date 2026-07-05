package com.example.health.common;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.BindException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class GlobalExceptionHandler {
    @ExceptionHandler(UnauthorizedException.class)
    public ResponseEntity<Result<Void>> handleUnauthorized(UnauthorizedException exception) {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(new Result<>(401, exception.getMessage(), null));
    }

    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<Result<Void>> handleBusiness(BusinessException exception) {
        int code = exception.getCode();
        // 业务异常代码 400-499 映射到对应 HTTP 状态, 500+ 走 Result.fail.
        HttpStatus status = (code >= 400 && code < 500) ? HttpStatus.valueOf(code) : HttpStatus.INTERNAL_SERVER_ERROR;
        return ResponseEntity.status(status).body(new Result<>(code, exception.getMessage(), null));
    }

    @ExceptionHandler({MethodArgumentNotValidException.class, BindException.class})
    public Result<Void> handleValid(Exception exception) {
        return Result.fail("参数校验失败：" + exception.getMessage());
    }

    @ExceptionHandler(Exception.class)
    public Result<Void> handle(Exception exception) {
        exception.printStackTrace();
        return Result.fail("系统异常：" + exception.getMessage());
    }
}
