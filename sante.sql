create table if not exists public.sante (user_id uuid not null references auth.users(id) on delete cascade, jour date not null, pas integer not null default 0, distance_km numeric not null default 0, energie_kcal numeric not null default 0, maj timestamptz not null default now(), primary key (user_id, jour));
alter table public.sante enable row level security;
drop policy if exists "lire sa sante" on public.sante;
create policy "lire sa sante" on public.sante for select to authenticated using (auth.uid() = user_id);
grant select on public.sante to authenticated;
create table if not exists public.jetons_sante (jeton text primary key, user_id uuid not null unique references auth.users(id) on delete cascade, cree timestamptz not null default now());
alter table public.jetons_sante enable row level security;
create or replace function public.sante_jeton() returns text language plpgsql security definer set search_path = public, extensions as $$
declare j text;
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  j := encode(extensions.gen_random_bytes(18), 'hex');
  insert into public.jetons_sante (jeton, user_id) values (j, auth.uid()) on conflict (user_id) do update set jeton = excluded.jeton, cree = now();
  return j;
end $$;
revoke all on function public.sante_jeton() from public, anon;
grant execute on function public.sante_jeton() to authenticated;
create or replace function public.sante_envoyer(cle text, pas numeric default 0, distance numeric default 0, energie numeric default 0, date_jour date default null) returns text language plpgsql security definer set search_path = public as $$
declare u uuid; d date := coalesce(date_jour, (now() at time zone 'Europe/Paris')::date); km numeric := coalesce(distance, 0);
begin
  select js.user_id into u from public.jetons_sante js where js.jeton = cle;
  if u is null then raise exception 'cle Sante invalide'; end if;
  if km > 300 then km := km / 1000; end if;
  insert into public.sante as s (user_id, jour, pas, distance_km, energie_kcal, maj) values (u, d, round(coalesce(pas, 0)), round(km, 2), round(coalesce(energie, 0)), now())
  on conflict (user_id, jour) do update set pas = excluded.pas, distance_km = excluded.distance_km, energie_kcal = excluded.energie_kcal, maj = now();
  return 'OK ' || d;
end $$;
revoke all on function public.sante_envoyer(text, numeric, numeric, numeric, date) from public;
grant execute on function public.sante_envoyer(text, numeric, numeric, numeric, date) to anon, authenticated;
