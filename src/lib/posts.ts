import { getCollection } from "astro:content";
import type { CollectionEntry } from "astro:content";

export async function getPublishedPosts() {
  const posts = await getCollection("blog");

  return posts.sort(
    (a, b) => b.data.pubDate.valueOf() - a.data.pubDate.valueOf(),
  );
}

export async function getAllTags() {
  const posts = await getPublishedPosts();
  const tags = posts.flatMap((post) => post.data.tags);

  return [...new Set(tags)].sort((a, b) => a.localeCompare(b, "zh-CN"));
}

export function getPostSlug(post: CollectionEntry<"blog">) {
  return post.id.replace(/\.(md|mdx)$/i, "");
}
