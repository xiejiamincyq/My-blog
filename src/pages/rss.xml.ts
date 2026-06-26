import rss from "@astrojs/rss";
import { getPostSlug, getPublishedPosts } from "../lib/posts";
import { sitePath } from "../lib/paths";

export async function GET(context: { site: URL }) {
  const posts = await getPublishedPosts();

  return rss({
    title: "虾米的博客",
    description: "记录想法、阅读、技术与生活的个人空间。",
    site: context.site,
    items: posts.map((post) => ({
      title: post.data.title,
      description: post.data.description,
      pubDate: post.data.pubDate,
      link: `blog/${getPostSlug(post)}/`,
      categories: post.data.tags,
    })),
    customData: "<language>zh-CN</language>",
    stylesheet: sitePath("rss/styles.xsl"),
  });
}
