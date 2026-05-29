-- 1. Create table to store scheduled push notifications
create table if not exists public.pwa_push_reminders (
    id uuid default gen_random_uuid() primary key,
    user_uuid text not null,
    subscription jsonb not null, -- Contains endpoint and cryptographic keys
    scheduled_for timestamptz not null,
    payload jsonb not null, -- Contains {"title": "...", "body": "...", "data": {...}}
    sent boolean default false not null,
    created_at timestamptz default now() not null
);

-- Enable indexes for quick lookup by cron job
create index if not exists idx_pwa_push_reminders_unsent 
on public.pwa_push_reminders(scheduled_for) 
where sent = false;

-- Enable Row Level Security (RLS)
alter table public.pwa_push_reminders enable row level security;

-- Setup RLS policies for anonymous operations (PWA operates without user log-in credentials)
create policy "Allow anonymous inserts" on public.pwa_push_reminders 
    for insert to anon with check (true);

create policy "Allow anonymous deletions" on public.pwa_push_reminders 
    for delete to anon using (true);

create policy "Allow anonymous updates" on public.pwa_push_reminders
    for update to anon using (true) with check (true);

create policy "Allow anonymous reads" on public.pwa_push_reminders
    for select to anon using (true);

-- Enable pg_cron and pg_net extensions
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- NOTE: Ensure you replace 'YOUR_SERVICE_ROLE_KEY' with your actual Supabase Service Role key (found in API Settings)
-- This schedules the push notifications checks to run once every minute.
-- You can run this block inside the SQL Editor after your table is set up.
-- select cron.schedule(
--     'send-pwa-push-every-minute',
--     '* * * * *',
--     $$ select net.http_post(
--         url := 'https://kemsanovebctmaalxmdu.supabase.co/functions/v1/send-pwa-push',
--         headers := '{"Content-Type": "application/json", "Authorization": "Bearer YOUR_SERVICE_ROLE_KEY"}'::jsonb
--     ) $$
-- );
