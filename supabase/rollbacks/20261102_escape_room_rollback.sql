-- ย้อนกลับเกมห้องหนี (ลบตารางและฟังก์ชันทั้งหมดของระบบนี้ ข้อมูลผลเล่นจะหายด้วย)
drop function if exists public.er_session_board(uuid);
drop function if exists public.er_rooms();
drop function if exists public.er_answer(uuid, int, int[]);
drop function if exists public.er_join(uuid, int);
drop function if exists public.er_my_games();
drop table if exists public.er_attempts;
drop table if exists public.er_sessions;
drop table if exists public.er_quiz_sets;
drop function if exists public.er_public_doors(jsonb);
drop function if exists public.er_valid_doors(jsonb);
delete from public.external_systems where url like '%/escape-room%';
