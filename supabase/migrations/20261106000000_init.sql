create table public.changes (
  seq bigint generated always as identity primary key,
  change_id uuid not null unique,
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  entity_type text not null check (entity_type in ('list','item')),
  entity_id uuid not null,
  device_id text not null,
  hlc text not null,
  payload text not null,
  created_at timestamptz not null default now()
);
create index changes_user_seq on public.changes (user_id, seq);
alter table public.changes enable row level security;
create policy changes_own on public.changes for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create table public.devices (
  id text primary key,
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  name text not null,
  platform text not null,
  last_seen_at timestamptz not null default now()
);
alter table public.devices enable row level security;
create policy devices_own on public.devices for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

alter publication supabase_realtime add table public.changes;

create function public.delete_account() returns void
language sql security definer set search_path = public as $$
  delete from auth.users where id = auth.uid();
$$;
revoke all on function public.delete_account() from public, anon;
grant execute on function public.delete_account() to authenticated;
