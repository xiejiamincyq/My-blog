export const SEO_DEFAULTS = {
  siteName: "虾米的博客",
  title: "虾米的博客",
  description: "记录想法、阅读、技术与生活的个人空间。把日常里的想法，慢慢写成自己的地图。",
  ogImage: "/images/og-default.png",
  locale: "zh_CN",
  siteUrl: "https://example.com",
  authorName: "虾米",
} as const;

export function formatPageTitle(pageTitle?: string): string {
  if (!pageTitle || pageTitle === SEO_DEFAULTS.siteName) {
    return SEO_DEFAULTS.siteName;
  }

  return `${pageTitle} | ${SEO_DEFAULTS.siteName}`;
}

export function absoluteURL(path: string, site: URL): string {
  if (/^https?:\/\//i.test(path)) {
    return path;
  }

  const url = new URL(site.toString());
  const sitePathname = url.pathname.replace(/\/$/, "");
  const cleanPath = path.startsWith("/") ? path : `/${path}`;

  if (sitePathname && (cleanPath === sitePathname || cleanPath.startsWith(`${sitePathname}/`))) {
    url.pathname = cleanPath;
  } else {
    url.pathname = `${sitePathname}${cleanPath}`.replace(/\/{2,}/g, "/");
  }

  return url.toString();
}

export function canonicalURL(path: string, site: URL): string {
  return absoluteURL(path, site);
}
