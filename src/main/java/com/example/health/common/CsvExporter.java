package com.example.health.common;

import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.List;

/**
 * CSV 导出工具 (PC Web 桌面端专用, 2026-07-05 进哥拍板 Q4-B / P2)
 *
 * 用法:
 * <pre>{@code
 *   List<HealthData> rows = healthDataService.list(wrapper);
 *   CsvExporter.export(response, "健康数据", new String[]{"ID", "用户ID", "收缩压"}, rows,
 *       (HealthData r) -> new Object[]{r.getId(), r.getUserId(), r.getSystolic()});
 * }</pre>
 *
 * 特性:
 * - UTF-8 BOM 头 (Excel 直接打开不乱码)
 * - 自动 URL encode 文件名 (中文不乱码)
 * - 流式写入 (大数据量不爆内存)
 * - 自动转义 CSV 特殊字符 (逗号/引号/换行)
 */
public final class CsvExporter {

    private CsvExporter() {}

    /**
     * 导出 CSV 到 HTTP Response
     *
     * @param response Spring 注入的 HttpServletResponse
     * @param fileName 文件名 (不带扩展名, 自动加 .csv + UTF-8 BOM)
     * @param headers  CSV 表头
     * @param rows     数据行
     * @param mapper   行转换器: T -> Object[]
     */
    public static <T> void export(HttpServletResponse response,
                                  String fileName,
                                  String[] headers,
                                  List<T> rows,
                                  RowMapper<T> mapper) throws IOException {
        // 文件名编码 (兼容 IE / Edge / Chrome / Firefox)
        String encoded = URLEncoder.encode(fileName, StandardCharsets.UTF_8).replace("+", "%20");
        response.setContentType("text/csv; charset=UTF-8");
        response.setCharacterEncoding(StandardCharsets.UTF_8.toString());
        response.setHeader("Content-Disposition", "attachment; filename=\"" + encoded + ".csv\"; filename*=UTF-8''" + encoded + ".csv");

        try (OutputStream os = response.getOutputStream();
             OutputStreamWriter writer = new OutputStreamWriter(os, StandardCharsets.UTF_8)) {

            // UTF-8 BOM (Excel 必备, 否则中文乱码)
            os.write(0xEF);
            os.write(0xBB);
            os.write(0xBF);

            // 表头
            writer.write(joinRow(headers));
            writer.write("\r\n");

            // 数据
            for (T row : rows) {
                Object[] cells = mapper.map(row);
                writer.write(joinRow(cells));
                writer.write("\r\n");
            }

            writer.flush();
        }
    }

    /**
     * 单行拼接 + CSV 转义
     */
    private static String joinRow(Object[] cells) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < cells.length; i++) {
            if (i > 0) sb.append(",");
            sb.append(escape(cells[i]));
        }
        return sb.toString();
    }

    /**
     * CSV 单元格转义:
     * - null -> 空字符串
     * - 含 , " \r \n 的 -> 用 " 包起来 + 内部 " 转义成 ""
     */
    private static String escape(Object value) {
        if (value == null) return "";
        String s = value.toString();
        if (s.contains(",") || s.contains("\"") || s.contains("\r") || s.contains("\n")) {
            return "\"" + s.replace("\"", "\"\"") + "\"";
        }
        return s;
    }

    @FunctionalInterface
    public interface RowMapper<T> {
        Object[] map(T row);
    }
}