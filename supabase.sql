-- Système : une ligne de sauvegarde par joueur, lisible et modifiable uniquement par lui
create table if not exists public.etats (
  user_id uuid primary key references auth.users(id) on delete cascade default auth.uid(),
  data jsonb not null,
  maj bigint not null default 0,
  updated_at timestamptz not null default now()
);
alter table public.etats enable row level security;
drop policy if exists "lire sa sauvegarde" on public.etats;
drop policy if exists "creer sa sauvegarde" on public.etats;
drop policy if exists "modifier sa sauvegarde" on public.etats;
create policy "lire sa sauvegarde" on public.etats for select to authenticated using (auth.uid() = user_id);
create policy "creer sa sauvegarde" on public.etats for insert to authenticated with check (auth.uid() = user_id);
create policy "modifier sa sauvegarde" on public.etats for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create or replace function public.etats_horodatage() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;
drop trigger if exists etats_horodatage on public.etats;
create trigger etats_horodatage before update on public.etats for each row execute function public.etats_horodatage();
grant select, insert, update on public.etats to authenticated;
