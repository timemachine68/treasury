alter table public.announcements drop constraint if exists announcements_category_check;
alter table public.announcements drop column if exists category;
