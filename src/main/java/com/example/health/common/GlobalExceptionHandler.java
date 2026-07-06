package com.example.health.common;

import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.BindException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * 全局异常处理.
 *
 * 修复 (2026-07-06): 改用 log.error() 而不是 exception.printStackTrace()
 *   - printStackTrace() 走 System.err, logback 没接管 System.err, stack trace 丢失
 *   - log.error("msg", exception) 通过 SLF4J, logback 会写到日志文件
 *   - 这样真正的 SQLException/Caused by 链能在 backend.log 看到
 */
@Slf4j
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
        // 改用 SLF4J + logback, stack trace 写进 backend.log
        log.error("系统异常: {}", exception.getMessage(), exception);
        return Result.fail("系统异常：" + exception.getMessage());
    }
}
