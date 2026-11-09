// ออกลิงก์ดาวน์โหลดไฟล์แนบชั่วคราว (10 นาที) ให้คนที่ไม่ได้ล็อกอิน
// - kind "news": ข่าวต้องเปิดอยู่ (is_active) และติ๊กเผยแพร่สาธารณะ (is_public)
// - kind "peer": ต้องมีรหัสลิงก์ลับที่ยังใช้ได้ และสื่อต้องติ๊กแชร์ให้เพื่อนครู (share_with_peers)
// ใช้ service role เฉพาะในนี้ ตรวจเงื่อนไขก่อนทุกครั้ง และรับแค่ id (ไม่รับ path จากผู้ใช้)
import { createClient } from "npm:@supabase/supabase-js@2.49.4";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function out(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return out(405, { error: "ใช้ได้เฉพาะ POST" });

  let body: { kind?: string; id?: string; token?: string };
  try { body = await req.json(); } catch { return out(400, { error: "ข้อมูลไม่ถูกต้อง" }); }
  const { kind, id, token } = body;
  if (!id || !UUID.test(id)) return out(400, { error: "ไม่พบรายการ" });

  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });

  let bucket = "", path = "", name = "";
  if (kind === "news") {
    const { data, error } = await sb.from("announcements")
      .select("file_path,file_name").eq("id", id).eq("is_active", true).eq("is_public", true).maybeSingle();
    if (error) return out(500, { error: "ระบบขัดข้อง ลองใหม่อีกครั้ง" });
    if (!data?.file_path) return out(404, { error: "ไม่พบไฟล์ หรือข่าวนี้ไม่ได้เผยแพร่แล้ว" });
    bucket = "announcements"; path = data.file_path; name = data.file_name || "";
  } else if (kind === "peer") {
    if (typeof token !== "string" || token.length < 40 || token.length > 128) return out(403, { error: "ลิงก์ใช้ไม่ได้แล้ว" });
    const { data: link } = await sb.from("peer_share_links").select("token").eq("id", 1).maybeSingle();
    if (!link || link.token !== token) return out(403, { error: "ลิงก์ใช้ไม่ได้แล้ว" });
    const { data, error } = await sb.from("resources")
      .select("file_path,file_name,download_count").eq("id", id).eq("share_with_peers", true).maybeSingle();
    if (error) return out(500, { error: "ระบบขัดข้อง ลองใหม่อีกครั้ง" });
    if (!data?.file_path) return out(404, { error: "ไม่พบไฟล์ หรือสื่อนี้เลิกแชร์แล้ว" });
    bucket = "resources"; path = data.file_path; name = data.file_name || "";
    await sb.from("resources").update({ download_count: (data.download_count || 0) + 1 }).eq("id", id);
  } else {
    return out(400, { error: "ข้อมูลไม่ถูกต้อง" });
  }

  const { data: signed, error: sErr } = await sb.storage.from(bucket).createSignedUrl(path, 600, { download: name || true });
  if (sErr || !signed) return out(500, { error: "เปิดไฟล์ไม่สำเร็จ" });
  return out(200, { url: signed.signedUrl });
});
