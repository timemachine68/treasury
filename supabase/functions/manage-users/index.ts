import { createClient } from "jsr:@supabase/supabase-js@2";

// จัดการบัญชีผู้ใช้ (สร้าง / สร้างหลายคน / รีเซ็ตรหัส / ลบ)
// สิทธิ์ (แก้ 15 พ.ย. 2569): ทำได้เฉพาะ admin หรือครูแนะแนว (is_guidance) ที่เปิดสิทธิ์เมนู "จัดการบัญชี" (menu_permissions.manage = true)
// บัญชีครูทั่วไป/บัญชีกลุ่มสาระ เรียกฟังก์ชันนี้ตรง ๆ ไม่ได้แล้ว

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });

const EMAIL_DOMAIN = "guidance-pcw.local";

type Caller = {
  id: string;
  username: string;
  display_name: string;
  role: string;
  is_guidance: boolean | null;
  menu_permissions: Record<string, unknown> | null;
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function sanitizeUsername(u: string): string | null {
  const s = (u ?? "").toString().trim().toLowerCase();
  if (!/^[a-z0-9._-]{3,40}$/.test(s)) return null;
  return s;
}

async function getCaller(req: Request): Promise<Caller | null> {
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "");
  if (!token) return null;
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data?.user) return null;
  const { data: profile } = await admin
    .from("profiles")
    .select("id, username, display_name, role, is_guidance, menu_permissions")
    .eq("id", data.user.id)
    .maybeSingle();
  if (!profile) return null;
  return profile as Caller;
}

// ครูที่จัดการบัญชีนักเรียนได้: admin หรือ ครูแนะแนวที่เปิดสิทธิ์เมนูจัดการบัญชี
function canManageStudents(c: Caller): boolean {
  if (c.role === "admin") return true;
  return c.role === "teacher" && c.is_guidance === true && c.menu_permissions?.manage === true;
}

async function usernameExists(username: string) {
  const { data } = await admin.from("profiles").select("id").eq("username", username).maybeSingle();
  return !!data;
}

async function createUserWithProfile(p: {
  username: string;
  password: string;
  display_name: string;
  role: "admin" | "teacher" | "student";
  class_room?: string | null;
  student_id?: string | null;
}) {
  const username = sanitizeUsername(p.username);
  if (!username) return { ok: false, error: "ชื่อผู้ใช้ไม่ถูกต้อง (a-z, 0-9, . _ - ยาว 3-40 ตัว): " + p.username };
  if (!p.password || String(p.password).length < 6) return { ok: false, error: `รหัสผ่านของ ${username} ต้องยาวอย่างน้อย 6 ตัว` };
  if (!p.display_name || !String(p.display_name).trim()) return { ok: false, error: `ไม่มีชื่อ-นามสกุลของ ${username}` };
  if (await usernameExists(username)) return { ok: false, error: `ชื่อผู้ใช้ ${username} มีอยู่แล้ว` };

  const email = `${username}@${EMAIL_DOMAIN}`;
  const { data: created, error: createErr } = await admin.auth.admin.createUser({
    email,
    password: String(p.password),
    email_confirm: true,
    user_metadata: { username, display_name: p.display_name },
  });
  if (createErr || !created?.user) return { ok: false, error: `สร้างบัญชี ${username} ไม่สำเร็จ: ${createErr?.message ?? "unknown"}` };

  const studentId = p.student_id ? String(p.student_id).trim() : username;

  const { error: profErr } = await admin.from("profiles").insert({
    id: created.user.id,
    username,
    display_name: String(p.display_name).trim(),
    role: p.role,
    class_room: p.class_room ? String(p.class_room).trim() : null,
    student_id: studentId || null,
  });
  if (profErr) {
    await admin.auth.admin.deleteUser(created.user.id);
    return { ok: false, error: `บันทึกโปรไฟล์ ${username} ไม่สำเร็จ: ${profErr.message}` };
  }
  return { ok: true, user_id: created.user.id, username };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  let body: any;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }
  const action = body?.action as string;

  try {
    // ---- ตรวจว่าต้องตั้งค่าครั้งแรกไหม (ไม่ต้องล็อกอิน) ----
    if (action === "check_bootstrap") {
      const { count } = await admin
        .from("profiles")
        .select("id", { count: "exact", head: true })
        .eq("role", "admin");
      return json({ needs_bootstrap: (count ?? 0) === 0 });
    }

    // ---- สร้างแอดมินคนแรก (ทำได้ครั้งเดียวตอนยังไม่มีแอดมิน) ----
    if (action === "bootstrap_admin") {
      const { count } = await admin
        .from("profiles")
        .select("id", { count: "exact", head: true })
        .eq("role", "admin");
      if ((count ?? 0) > 0) return json({ error: "มีผู้ดูแลระบบอยู่แล้ว" }, 403);
      const r = await createUserWithProfile({
        username: body.username,
        password: body.password,
        display_name: body.display_name,
        role: "admin",
      });
      return r.ok ? json({ success: true }) : json({ error: r.error }, 400);
    }

    // ---- ที่เหลือต้องล็อกอิน และต้องมีสิทธิ์จัดการบัญชี ----
    const caller = await getCaller(req);
    if (!caller) return json({ error: "กรุณาเข้าสู่ระบบ" }, 401);
    const isAdmin = caller.role === "admin";
    if (!canManageStudents(caller)) return json({ error: "บัญชีนี้ไม่มีสิทธิ์จัดการบัญชีผู้ใช้" }, 403);

    if (action === "create_user") {
      const targetRole = body.role as string;
      if (!["admin", "teacher", "student"].includes(targetRole)) return json({ error: "role ไม่ถูกต้อง" }, 400);
      if (!(isAdmin || targetRole === "student")) return json({ error: "ไม่มีสิทธิ์สร้างบัญชีประเภทนี้" }, 403);
      const r = await createUserWithProfile({
        username: body.username,
        password: body.password,
        display_name: body.display_name,
        role: targetRole as any,
        class_room: body.class_room ?? null,
        student_id: body.student_id ?? null,
      });
      return r.ok ? json({ success: true, username: r.username }) : json({ error: r.error }, 400);
    }

    if (action === "bulk_create_students") {
      const students = body.students;
      if (!Array.isArray(students) || students.length === 0) return json({ error: "ไม่มีรายชื่อนักเรียน" }, 400);
      if (students.length > 200) return json({ error: "ครั้งละไม่เกิน 200 คนนะคะ" }, 400);
      const results: { username: string; ok: boolean; error?: string }[] = [];
      for (const s of students) {
        const r = await createUserWithProfile({
          username: s.username,
          password: s.password,
          display_name: s.display_name,
          role: "student",
          class_room: s.class_room ?? null,
          student_id: s.student_id ?? null,
        });
        results.push({ username: String(s.username ?? ""), ok: r.ok, error: r.ok ? undefined : r.error });
      }
      const okCount = results.filter((r) => r.ok).length;
      return json({ success: true, created: okCount, failed: results.length - okCount, results });
    }

    if (action === "reset_password") {
      const username = sanitizeUsername(body.username);
      const newPassword = String(body.new_password ?? "");
      if (!username) return json({ error: "ชื่อผู้ใช้ไม่ถูกต้อง" }, 400);
      if (newPassword.length < 6) return json({ error: "รหัสผ่านใหม่ต้องยาวอย่างน้อย 6 ตัว" }, 400);
      const { data: target } = await admin.from("profiles").select("id, role").eq("username", username).maybeSingle();
      if (!target) return json({ error: "ไม่พบผู้ใช้นี้" }, 404);
      if (!(isAdmin || target.role === "student")) return json({ error: "ไม่มีสิทธิ์รีเซ็ตรหัสผ่านบัญชีนี้" }, 403);
      const { error } = await admin.auth.admin.updateUserById(target.id, { password: newPassword });
      if (error) return json({ error: error.message }, 400);
      return json({ success: true });
    }

    if (action === "delete_user") {
      const username = sanitizeUsername(body.username);
      if (!username) return json({ error: "ชื่อผู้ใช้ไม่ถูกต้อง" }, 400);
      const { data: target } = await admin.from("profiles").select("id, role").eq("username", username).maybeSingle();
      if (!target) return json({ error: "ไม่พบผู้ใช้นี้" }, 404);
      if (target.id === caller.id) return json({ error: "ลบบัญชีตัวเองไม่ได้ค่ะ" }, 400);
      if (!(isAdmin || target.role === "student")) return json({ error: "ไม่มีสิทธิ์ลบบัญชีนี้" }, 403);
      const { error } = await admin.auth.admin.deleteUser(target.id);
      if (error) return json({ error: error.message }, 400);
      return json({ success: true });
    }

    return json({ error: "ไม่รู้จักคำสั่งนี้" }, 400);
  } catch (e) {
    return json({ error: `เกิดข้อผิดพลาด: ${e instanceof Error ? e.message : String(e)}` }, 500);
  }
});
