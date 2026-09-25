-- Bug fix: "teacher score any session" USING clause was missing scorer_id, unlike its own
-- WITH CHECK and unlike the symmetric "self score own session" policy (using+check both check
-- scorer_id). This let any teacher/admin UPDATE or DELETE another teacher's already-submitted
-- iv_scores row, since USING only gated on scorer_role+role, not who actually scored it.
-- Fix: only the original scorer or an admin may touch an existing "teacher" score row.
-- (WITH CHECK already required scorer_id = auth.uid() for the write itself — unchanged.)

drop policy "teacher score any session" on public.iv_scores;

create policy "teacher score any session" on public.iv_scores
  for all to authenticated
  using (scorer_role = 'teacher' and (scorer_id = auth.uid() or get_my_role() = 'admin'))
  with check (scorer_role = 'teacher' and scorer_id = auth.uid() and get_my_role() in ('teacher','admin'));
