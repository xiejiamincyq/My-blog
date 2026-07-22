在当前 Astro 博客仓库中完成一次“每日 GitHub 高星项目”中文文章生成。

先按 Asia/Shanghai 的当前日期计算 `YYYY-MM-DD`，并检查：

- 如果 `src/content/blog/github-high-stars-YYYY-MM-DD.md` 已存在，立即停止，不修改博客仓库。
- 如果 `C:\Users\21604\.codex\automations\github\memory.md` 已记录当天发布成功，立即停止，不修改博客仓库。

如果当天尚未生成文章：

1. 使用网络搜索 GitHub 当天热门/高星项目，优先参考 GitHub Trending 和 GitHub 搜索结果。
2. 选出 5 个值得中文开发者关注的项目。谨慎核实仓库链接、主要语言、总 star 数和项目简介。
3. 不要把历史总 star 写成当天新增 star。无法稳定取得新增值时，明确写作“当日热门（总 star）”。
4. 写一篇原创中文 Markdown 博客，文件放到 `src/content/blog/github-high-stars-YYYY-MM-DD.md`。
5. frontmatter 必须包含 `title`、`description`、`pubDate`、`tags`、`featured`。`heroImage` 是可选字段：只有在确实生成或已有合适本地图片时才填写；如果当前 CLI 环境没有图片生成工具，就省略 `heroImage`，不要编造图片路径。
6. 文章标题包含日期和“GitHub 高星项目”。正文开头说明排序口径，然后用编号小节介绍 5 个项目：项目名、链接、语言、star 数据、中文简介、适合谁、值得关注的原因。
7. 全文必须是正常 UTF-8 中文，不要输出乱码。

写完后按顺序运行并全部通过：

1. `npm.cmd run format:check`
2. `npm.cmd run lint:md`
3. `npm.cmd run build`

如果格式检查失败，只对本次新增 Markdown 执行 `npm.cmd run format -- <文件路径>`，然后从第一项重新验证。不要使用会被 PowerShell 执行策略影响的 `npm run`。

不要执行 `git add`、`git commit`、`git push`，也不要修改 memory。外层桌面触发脚本会在文章稳定落盘后负责验证、提交、推送和记录发布成功。
