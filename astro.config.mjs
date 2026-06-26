import { defineConfig } from "astro/config";
import sitemap from "@astrojs/sitemap";

const repository = process.env.GITHUB_REPOSITORY;
const [owner, repo] = repository?.split("/") ?? [];
const isProjectPages = Boolean(process.env.GITHUB_ACTIONS && repo && !repo.endsWith(".github.io"));
const base = isProjectPages ? `/${repo}` : undefined;

export default defineConfig({
  site: repository ? `https://${owner}.github.io${base ?? ""}` : "https://example.com",
  base,
  integrations: [sitemap()],
});
