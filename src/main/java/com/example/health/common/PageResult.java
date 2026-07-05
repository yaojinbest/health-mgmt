package com.example.health.common;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * 分页结果通用类 - PC Web 桌面端专用 (2026-07-05 进哥拍板 Q4-B)
 *
 * 用途: 替代直接返 List, 让前端 el-table + el-pagination 联动
 *
 * 调用方 (Controller):
 *   return Result.ok(PageResult.of(records, total, page, size));
 *
 * 前端对应:
 *   {
 *     code: 200,
 *     data: {
 *       records: [...],
 *       total: 100,
 *       page: 1,
 *       size: 20
 *     }
 *   }
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class PageResult<T> {
    /** 数据列表 */
    private List<T> records;
    /** 总记录数 */
    private long total;
    /** 当前页 (1-based) */
    private int page;
    /** 每页大小 */
    private int size;

    /** 便捷工厂方法 */
    public static <T> PageResult<T> of(List<T> records, long total, int page, int size) {
        return new PageResult<>(records, total, page, size);
    }

    /** 空结果 */
    public static <T> PageResult<T> empty(int page, int size) {
        return new PageResult<>(List.of(), 0L, page, size);
    }

    /** 总页数 */
    public long getTotalPages() {
        return size == 0 ? 0 : (total + size - 1) / size;
    }
}
