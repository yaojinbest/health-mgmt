package com.example.health.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.example.health.common.AuthContext;
import com.example.health.common.BusinessException;
import com.example.health.common.Result;
import com.example.health.entity.HealthArticle;
import com.example.health.service.HealthArticleService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/articles")
public class ArticleController {
    private final HealthArticleService articleService;

    @GetMapping
    public Result<List<HealthArticle>> list(@RequestParam(required = false) String category,
                                            @RequestParam(required = false) String keyword,
                                            @RequestParam(required = false) String diseaseTag) {
        LambdaQueryWrapper<HealthArticle> wrapper = new LambdaQueryWrapper<>();
        if (category != null && !category.isBlank()) {
            wrapper.eq(HealthArticle::getCategory, category);
        }
        if (keyword != null && !keyword.isBlank()) {
            wrapper.and(item -> item.like(HealthArticle::getTitle, keyword).or().like(HealthArticle::getSummary, keyword));
        }
        if (diseaseTag != null && !diseaseTag.isBlank()) {
            wrapper.like(HealthArticle::getDiseaseTag, diseaseTag);
        }
        wrapper.orderByDesc(HealthArticle::getPublishTime);
        return Result.ok(articleService.list(wrapper));
    }

    @GetMapping("/{id}")
    public Result<HealthArticle> detail(@PathVariable Long id) {
        HealthArticle article = articleService.getById(id);
        if (article == null) {
            throw new BusinessException("文章不存在");
        }
        article.setViewCount((article.getViewCount() == null ? 0 : article.getViewCount()) + 1);
        articleService.updateById(article);
        return Result.ok(article);
    }

    @GetMapping("/{id}/edit")
    public Result<HealthArticle> editDetail(@PathVariable Long id) {
        AuthContext.requireAdmin();
        HealthArticle article = articleService.getById(id);
        if (article == null) {
            throw new BusinessException("文章不存在");
        }
        return Result.ok(article);
    }

    @PostMapping("/delete/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        AuthContext.requireAdmin();
        if (articleService.getById(id) == null) {
            throw new BusinessException("文章不存在");
        }
        articleService.removeById(id);
        return Result.ok();
    }

    @PostMapping("/save")
    public Result<HealthArticle> save(@RequestBody HealthArticle article) {
        AuthContext.requireAdmin();
        if (article.getTitle() == null || article.getTitle().isBlank()) {
            throw new BusinessException("请填写文章标题");
        }
        if (article.getContent() == null || article.getContent().isBlank()) {
            throw new BusinessException("请填写文章正文");
        }
        if (article.getPublishTime() == null) {
            article.setPublishTime(LocalDateTime.now());
        }
        if (article.getViewCount() == null) {
            article.setViewCount(0);
        }
        articleService.saveOrUpdate(article);
        return Result.ok(article);
    }
}
