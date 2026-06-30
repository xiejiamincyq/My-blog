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

export async function hashVisitor() {
  const key = "blog_visitor_id";
  let id = localStorage.getItem(key);
  if (!id) {
    id = crypto.randomUUID();
    localStorage.setItem(key, id);
  }

  const input = `${id}:${navigator.userAgent}`;
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(input));
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}
