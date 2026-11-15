-- ตรวจความปลอดภัยรอบ 15 พ.ย. 2569 (รันแล้วบนฐานข้อมูลจริง ไฟล์นี้เก็บไว้เป็นประวัติ)
revoke execute on function public.guard_criteria_lock() from public, anon, authenticated;
revoke execute on function public.log_criteria_change() from public, anon, authenticated;
revoke execute on function public.log_score_change() from public, anon, authenticated;
revoke execute on function public.log_status_change() from public, anon, authenticated;
revoke execute on function public.tgat_prep_validate_subjects() from public, anon, authenticated;
alter view public.v_scholarship_annual_summary set (security_invoker = true);
revoke all on public.student_identity from anon;
revoke all on public.vulnerable_profiles from anon;
revoke all on public.counseling_logs from anon;
