# 虾米的博客

一个使用 Astro 搭建的个人博客。文章放在 `src/content/blog`，使用 Markdown 编写。

## 本地预览

```bash
npm.cmd install
npm.cmd run dev
```

## 新增文章

在 `src/content/blog` 新建 `.md` 文件，并参考现有文章填写标题、简介、日期和标签。

## 部署

项目已包含 GitHub Pages 工作流。推送到 `main` 分支后，GitHub Actions 会自动构建并发布到 Pages。
