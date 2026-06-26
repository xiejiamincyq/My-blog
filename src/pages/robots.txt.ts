import type { APIRoute } from "astro";
import { SEO_DEFAULTS, absoluteURL } from "../lib/seo";

export const GET: APIRoute = ({ site }) => {
  const siteUrl = site ?? new URL(SEO_DEFAULTS.siteUrl);
  const sitemapUrl = absoluteURL("sitemap-index.xml", siteUrl);

  return new Response(`User-agent: *\nAllow: /\n\nSitemap: ${sitemapUrl}\n`, {
    headers: {
      "Content-Type": "text/plain; charset=utf-8",
    },
  });
};
