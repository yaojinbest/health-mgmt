package com.example.health.common;

import lombok.Data;

/**
 * 分页请求基类 - PC Web 桌面端专用
 *
 * 默认: page=1, size=20, max size=100 (防止恶意请求)
 *
 * Controller 用法:
 *   public Result<PageResult<User>> list(@ModelAttribute PageRequest pageRequest, ...) {
 *     pageRequest.sanitize();  // 兜底
 *     ...
 *   }
 */
@Data
public class PageRequest {
    /** 当前页 (1-based, 默认 1) */
    private Integer page = 1;
    /** 每页大小 (默认 20, 最大 100) */
    private Integer size = 20;
    /** 关键词搜索 (可选) */
    private String keyword;

    /** 兜底: 修正非法参数 */
    public PageRequest sanitize() {
        if (page == null || page < 1) page = 1;
        if (size == null || size < 1) size = 20;
        if (size > 100) size = 100;
        if (keyword != null) keyword = keyword.trim();
        return this;
    }

    /** MyBatis-Plus offset (for IPage.toOffset) */
    public long offset() {
        return (long)(page - 1) * size;
    }
}
