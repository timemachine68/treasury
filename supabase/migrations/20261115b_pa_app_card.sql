-- การ์ด "แอป PA" ในหน้าระบบของเรา (ครูทุกคนที่ไม่จำกัดเมนู + ครูแนะแนว 3 คน; บัญชีกลุ่มสาระไม่เห็น)
insert into public.external_systems (id, title, url, visible_to, category, sort_order)
values ('5a7e0c11-9a2b-4c3d-8e4f-2026111500a1', 'แอป PA · ผลงานและเกียรติบัตรอบรม', 'https://timemachine68.github.io/treasury/pa-app.html', array['teacher'], null, 22)
on conflict (id) do nothing;
update public.profiles
   set menu_permissions = jsonb_set(menu_permissions, '{appsOnly}', (menu_permissions->'appsOnly') || '"5a7e0c11-9a2b-4c3d-8e4f-2026111500a1"'::jsonb)
 where is_guidance and jsonb_typeof(menu_permissions->'appsOnly') = 'array'
   and not (menu_permissions->'appsOnly') ? '5a7e0c11-9a2b-4c3d-8e4f-2026111500a1';
