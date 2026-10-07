-- ============================================================
-- Filmory : tables, règles de sécurité (RLS) et temps réel
-- À coller une seule fois dans Supabase → SQL Editor → Run.
-- ============================================================

-- Créateur·rices du site (accès à la boîte du support et aux recommandations)
create table if not exists public.admins (
  user_id uuid primary key references auth.users on delete cascade
);
create or replace function public.is_admin() returns boolean
  language sql stable security definer set search_path = public
  as $$ select exists (select 1 from public.admins where user_id = auth.uid()) $$;

-- Profil et bibliothèque de chaque personne (privés)
create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  data jsonb not null default '{}', updated_at timestamptz default now()
);
create table if not exists public.libraries (
  id uuid primary key references auth.users on delete cascade,
  data jsonb not null default '{}', updated_at timestamptz default now()
);

-- Profil public, lu par les amis
create table if not exists public.public_profiles (
  id uuid primary key references auth.users on delete cascade,
  data jsonb not null default '{}', updated_at timestamptz default now()
);

-- Votes du film du mois : une voix par personne et par mois
create table if not exists public.votes (
  user_id uuid not null references auth.users on delete cascade,
  month text not null check (month ~ '^\d{4}-\d{2}$'),
  title_id text not null,
  title jsonb,
  created_at timestamptz default now(),
  primary key (user_id, month)
);

-- Recommandations du créateur (une seule ligne)
create table if not exists public.reco (
  id int primary key default 1 check (id = 1),
  data jsonb not null default '{}', updated_at timestamptz default now()
);

-- Support : un fil de demandes par personne
create table if not exists public.support_threads (
  user_id uuid primary key references auth.users on delete cascade,
  data jsonb not null default '{}', updated_at timestamptz default now()
);

alter table public.admins          enable row level security;
alter table public.profiles        enable row level security;
alter table public.libraries       enable row level security;
alter table public.public_profiles enable row level security;
alter table public.votes           enable row level security;
alter table public.reco            enable row level security;
alter table public.support_threads enable row level security;

-- admins : chacun peut seulement vérifier s'il en fait partie
create policy "admins: lire sa ligne" on public.admins
  for select to authenticated using (user_id = auth.uid());

-- profiles / libraries : chacun ne voit et ne modifie que les siens
create policy "profiles: les siens" on public.profiles
  for all to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy "libraries: les siennes" on public.libraries
  for all to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- public_profiles : lisibles par les personnes connectées, modifiables par leur propriétaire
create policy "public: lire" on public.public_profiles
  for select to authenticated using (true);
create policy "public: créer le sien" on public.public_profiles
  for insert to authenticated with check (id = auth.uid());
create policy "public: modifier le sien" on public.public_profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy "public: supprimer le sien" on public.public_profiles
  for delete to authenticated using (id = auth.uid());

-- votes : tout le monde voit le décompte, chacun ne touche qu'à sa voix
create policy "votes: lire" on public.votes
  for select using (true);
create policy "votes: voter" on public.votes
  for insert to authenticated with check (user_id = auth.uid());
create policy "votes: changer son vote" on public.votes
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "votes: retirer son vote" on public.votes
  for delete to authenticated using (user_id = auth.uid());

-- reco : lisibles par tous, modifiables par le créateur
create policy "reco: lire" on public.reco
  for select using (true);
create policy "reco: créateur" on public.reco
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- support : chacun voit ses demandes, le créateur voit et répond à toutes
create policy "support: lire" on public.support_threads
  for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy "support: écrire" on public.support_threads
  for insert to authenticated with check (user_id = auth.uid());
create policy "support: répondre" on public.support_threads
  for update to authenticated using (user_id = auth.uid() or public.is_admin())
  with check (user_id = auth.uid() or public.is_admin());

-- Mises à jour en direct (votes, recommandations, réponses du support)
alter publication supabase_realtime add table public.votes, public.reco, public.support_threads;


-- ============================================================
-- APRÈS avoir créé VOTRE compte sur le site, lancez cette ligne
-- (en remplaçant l'adresse) pour devenir créateur :
--
--   insert into public.admins (user_id)
--   select id from auth.users where email = 'votre@adresse.fr';
-- ============================================================
