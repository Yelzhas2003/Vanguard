-- Vanguard CRM: база данных для Supabase
-- Вставьте целиком в Supabase → SQL Editor → Run

create table if not exists public.docs (
  path        text primary key,          -- полный путь записи, например vg/main/clients/abc123
  col         text not null,             -- коллекция, например vg/main/clients
  data        jsonb not null default '{}'::jsonb,
  updated_at  timestamptz not null default now(),
  updated_by  uuid default auth.uid()
);
create index if not exists docs_col_idx on public.docs (col);

-- Защита: без входа данные не видны и не меняются
alter table public.docs enable row level security;

drop policy if exists "read for signed in"   on public.docs;
drop policy if exists "insert for signed in" on public.docs;
drop policy if exists "update for signed in" on public.docs;
drop policy if exists "delete for signed in" on public.docs;
create policy "read for signed in"   on public.docs for select to authenticated using (true);
create policy "insert for signed in" on public.docs for insert to authenticated with check (true);
create policy "update for signed in" on public.docs for update to authenticated using (true) with check (true);
create policy "delete for signed in" on public.docs for delete to authenticated using (true);

-- Время изменения и автор
create or replace function public.docs_touch() returns trigger language plpgsql as $$
begin new.updated_at := now(); new.updated_by := auth.uid(); return new; end $$;
drop trigger if exists docs_touch on public.docs;
create trigger docs_touch before insert or update on public.docs for each row execute function public.docs_touch();

-- Обновления в реальном времени (изменения видны всем сразу)
alter table public.docs replica identity full;
do $$ begin
  begin alter publication supabase_realtime add table public.docs; exception when duplicate_object then null; end;
end $$;
