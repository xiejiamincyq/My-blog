// @ts-nocheck
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

type ArticlePayload = {
  slug?: string;
  title?: string;
  description?: string;
  pubDate?: string;
  tags?: string[];
  featured?: boolean;
  heroImage?: string;
  body?: string;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
};

const json = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

const env = (name: string) => {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing environment variable: ${name}`);
  return value;
};

const githubRequest = async (path: string, init: RequestInit = {}) => {
  const token = env("GITHUB_TOKEN");
  const owner = env("GITHUB_OWNER");
  const repo = env("GITHUB_REPO");

  const response = await fetch(`https://api.github.com/repos/${owner}/${repo}${path}`, {
    ...init,
    headers: {
      Accept: "application/vnd.github+json",
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      "X-GitHub-Api-Version": "2022-11-28",
      ...(init.headers ?? {}),
    },
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`GitHub API failed ${response.status}: ${text}`);
  }

  return response.json();
};

const getSupabaseUser = async (req: Request) => {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) throw new Error("Missing Authorization header");

  const supabaseUrl = env("SUPABASE_URL");
  const serviceRoleKey = env("SUPABASE_SERVICE_ROLE_KEY");
  const token = authHeader.replace(/^Bearer\s+/i, "");

  const userResponse = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: {
      Authorization: `Bearer ${token}`,
      apikey: serviceRoleKey,
    },
  });

  if (!userResponse.ok) throw new Error("Invalid Supabase session");
  const userPayload = await userResponse.json();

  const profileResponse = await fetch(
    `${supabaseUrl}/rest/v1/profiles?id=eq.${userPayload.id}&select=role`,
    {
      headers: {
        Authorization: `Bearer ${serviceRoleKey}`,
        apikey: serviceRoleKey,
      },
    },
  );

  if (!profileResponse.ok) throw new Error("Unable to verify profile role");
  const profiles = await profileResponse.json();
  if (profiles[0]?.role !== "admin") throw new Error("Admin access required");

  return userPayload;
};

const safeSlug = (slug: string) =>
  slug
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9-]/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "");

const articlePath = (slug: string) => `src/content/blog/${safeSlug(slug)}.md`;

const encodeBase64 = (value: string) => btoa(unescape(encodeURIComponent(value)));

const toMarkdown = (payload: ArticlePayload) => {
  const slug = safeSlug(payload.slug ?? payload.title ?? "untitled");
  const frontmatter = [
    "---",
    `title: ${JSON.stringify(payload.title ?? "未命名文章")}`,
    `description: ${JSON.stringify(payload.description ?? "")}`,
    `pubDate: ${payload.pubDate ?? new Date().toISOString().slice(0, 10)}`,
    `tags: ${JSON.stringify(payload.tags ?? [])}`,
    `featured: ${Boolean(payload.featured)}`,
    payload.heroImage ? `heroImage: ${JSON.stringify(payload.heroImage)}` : undefined,
    "---",
  ]
    .filter(Boolean)
    .join("\n");

  return { slug, content: `${frontmatter}\n\n${payload.body ?? ""}\n` };
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    await getSupabaseUser(req);

    const url = new URL(req.url);
    const slug = safeSlug(url.searchParams.get("slug") ?? "");

    if (req.method === "GET") {
      if (!slug) return json({ error: "Missing slug" }, 400);
      const file = await githubRequest(`/contents/${articlePath(slug)}`);
      return json({
        slug,
        sha: file.sha,
        content: decodeURIComponent(escape(atob(file.content.replace(/\n/g, "")))),
      });
    }

    if (req.method === "POST" || req.method === "PUT") {
      const payload = (await req.json()) as ArticlePayload & { sha?: string };
      const article = toMarkdown(payload);
      const path = articlePath(article.slug);

      let sha = payload.sha;
      if (!sha && req.method === "PUT") {
        const current = await githubRequest(`/contents/${path}`);
        sha = current.sha;
      }

      const result = await githubRequest(`/contents/${path}`, {
        method: "PUT",
        body: JSON.stringify({
          message: `${req.method === "POST" ? "Create" : "Update"} article ${article.slug}`,
          content: encodeBase64(article.content),
          ...(sha && { sha }),
        }),
      });

      return json({ slug: article.slug, commit: result.commit?.sha });
    }

    if (req.method === "DELETE") {
      if (!slug) return json({ error: "Missing slug" }, 400);
      const current = await githubRequest(`/contents/${articlePath(slug)}`);
      const result = await githubRequest(`/contents/${articlePath(slug)}`, {
        method: "DELETE",
        body: JSON.stringify({
          message: `Delete article ${slug}`,
          sha: current.sha,
        }),
      });

      return json({ slug, commit: result.commit?.sha });
    }

    return json({ error: "Method not allowed" }, 405);
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Unknown error" }, 400);
  }
});
