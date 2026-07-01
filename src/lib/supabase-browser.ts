// @ts-nocheck
const supabaseUrl = import.meta.env.PUBLIC_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.PUBLIC_SUPABASE_ANON_KEY;

let clientPromise: Promise<any> | undefined;

export const isSupabaseConfigured = Boolean(supabaseUrl && supabaseAnonKey);

export async function getSupabaseClient() {
  if (!isSupabaseConfigured) return null;

  if (!clientPromise) {
    clientPromise = import(/* @vite-ignore */ "https://esm.sh/@supabase/supabase-js@2").then(
      ({ createClient }) =>
        createClient(supabaseUrl, supabaseAnonKey, {
          auth: {
            persistSession: true,
            autoRefreshToken: true,
            detectSessionInUrl: true,
          },
        }),
    );
  }

  return clientPromise;
}

export function getUserLabel(user: any) {
  return (
    user?.user_metadata?.user_name ??
    user?.user_metadata?.name ??
    user?.email?.split("@")[0] ??
    "匿名用户"
  );
}

function getBrowserId(key: string) {
  let id = localStorage.getItem(key);
  if (!id) {
    id =
      crypto.randomUUID?.() ?? `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`;
    localStorage.setItem(key, id);
  }
  return id;
}

async function hashText(value: string) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export async function hashAnonymousIdentity() {
  return hashText(getBrowserId("blog_anonymous_id"));
}

export async function hashVisitor() {
  const id = getBrowserId("blog_visitor_id");
  const input = `${id}:${navigator.userAgent}`;
  return hashText(input);
}
