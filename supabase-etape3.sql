-- ============================================================
-- Filmory, étape 3 : notifications, critiques publiques et likes,
-- quiz et classement, messagerie entre amis.
-- À coller dans Supabase → SQL Editor → Run, APRÈS supabase.sql.
-- Le script peut être relancé sans risque.
-- ============================================================

-- ---------- Notifications ----------
create table if not exists public.notifications (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users on delete cascade,              -- destinataire
  actor_id uuid references auth.users on delete cascade default auth.uid(),   -- auteur de l'action
  kind text not null check (kind in ('friend','like','quiz','reco')),
  data jsonb not null default '{}',
  read boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists notifications_user_idx on public.notifications (user_id, created_at desc);
alter table public.notifications enable row level security;
drop policy if exists "notif: lire les siennes" on public.notifications;
drop policy if exists "notif: envoyer" on public.notifications;
drop policy if exists "notif: marquer lue" on public.notifications;
drop policy if exists "notif: supprimer les siennes" on public.notifications;
create policy "notif: lire les siennes" on public.notifications
  for select to authenticated using (user_id = auth.uid());
create policy "notif: envoyer" on public.notifications
  for insert to authenticated with check (actor_id = auth.uid());
create policy "notif: marquer lue" on public.notifications
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "notif: supprimer les siennes" on public.notifications
  for delete to authenticated using (user_id = auth.uid());
-- seule la colonne « read » peut être modifiée
revoke update on public.notifications from anon, authenticated;
grant update (read) on public.notifications to authenticated;

-- ---------- Critiques publiques ----------
create table if not exists public.reviews (
  user_id uuid not null references auth.users on delete cascade,
  title_id text not null,
  title jsonb,                         -- copie légère du film (titre, affiche, année…)
  author jsonb not null default '{}',  -- nom et pseudo de l'auteur au moment de la publication
  rating numeric check (rating is null or (rating >= 0 and rating <= 5)),
  text text not null check (char_length(text) between 1 and 5000),
  spoiler boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, title_id)
);
create index if not exists reviews_title_idx on public.reviews (title_id);
alter table public.reviews enable row level security;
drop policy if exists "reviews: lire" on public.reviews;
drop policy if exists "reviews: écrire la sienne" on public.reviews;
drop policy if exists "reviews: modifier la sienne" on public.reviews;
drop policy if exists "reviews: supprimer la sienne ou modérer" on public.reviews;
create policy "reviews: lire" on public.reviews for select using (true);
create policy "reviews: écrire la sienne" on public.reviews
  for insert to authenticated with check (user_id = auth.uid());
create policy "reviews: modifier la sienne" on public.reviews
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "reviews: supprimer la sienne ou modérer" on public.reviews
  for delete to authenticated using (user_id = auth.uid() or public.is_admin());

-- Likes sur les critiques : un like par personne et par critique, jamais sur la sienne
create table if not exists public.review_likes (
  user_id uuid not null references auth.users on delete cascade,
  author_id uuid not null,
  title_id text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, author_id, title_id),
  foreign key (author_id, title_id) references public.reviews (user_id, title_id) on delete cascade,
  check (user_id <> author_id)
);
alter table public.review_likes enable row level security;
drop policy if exists "likes: lire" on public.review_likes;
drop policy if exists "likes: aimer" on public.review_likes;
drop policy if exists "likes: retirer" on public.review_likes;
create policy "likes: lire" on public.review_likes for select using (true);
create policy "likes: aimer" on public.review_likes
  for insert to authenticated with check (user_id = auth.uid());
create policy "likes: retirer" on public.review_likes
  for delete to authenticated using (user_id = auth.uid());

-- Critiques avec leur nombre de likes, les plus aimées d'abord (toutes, ou celles d'un titre)
create or replace function public.review_feed(p_title text default null, p_limit int default 20)
returns table (user_id uuid, title_id text, title jsonb, author jsonb, rating numeric, text text, spoiler boolean,
               created_at timestamptz, updated_at timestamptz, likes bigint, liked boolean)
language sql stable set search_path = public as $$
  select r.user_id, r.title_id, r.title, r.author, r.rating, r.text, r.spoiler, r.created_at, r.updated_at,
         (select count(*) from review_likes l where l.author_id = r.user_id and l.title_id = r.title_id) as likes,
         exists (select 1 from review_likes l where l.author_id = r.user_id and l.title_id = r.title_id and l.user_id = auth.uid()) as liked
  from reviews r
  where p_title is null or r.title_id = p_title
  order by likes desc, r.updated_at desc
  limit least(greatest(coalesce(p_limit, 20), 1), 100)
$$;
grant execute on function public.review_feed(text, int) to anon, authenticated;

-- ---------- Quiz ----------
create table if not exists public.quiz_scores (
  user_id uuid primary key references auth.users on delete cascade,
  name text not null default '',
  points int not null default 0,
  quizzes int not null default 0,
  passed int not null default 0,         -- quiz réussis (7 bonnes réponses sur 10 ou plus)
  best int not null default 0,
  month text not null default to_char(now() at time zone 'Europe/Paris', 'YYYY-MM'),
  month_points int not null default 0,
  month_passed int not null default 0,
  updated_at timestamptz not null default now()
);
alter table public.quiz_scores enable row level security;
drop policy if exists "quiz: lire" on public.quiz_scores;
create policy "quiz: lire" on public.quiz_scores for select using (true);
-- aucune règle d'écriture : seuls les scores validés par record_quiz() sont enregistrés

create or replace function public.record_quiz(p_correct int, p_total int, p_points int, p_name text)
returns public.quiz_scores
language plpgsql security definer set search_path = public as $$
declare
  r public.quiz_scores;
  m text := to_char(now() at time zone 'Europe/Paris', 'YYYY-MM');
  ok int;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_total <> 10 or p_correct < 0 or p_correct > p_total or p_points < 0 or p_points > p_correct * 15 then
    raise exception 'Score invalide';
  end if;
  ok := case when p_correct >= 7 then 1 else 0 end;
  select * into r from quiz_scores where user_id = auth.uid() for update;
  if found and r.updated_at > now() - interval '25 seconds' then raise exception 'Trop rapide'; end if;
  insert into quiz_scores as q (user_id, name, points, quizzes, passed, best, month, month_points, month_passed, updated_at)
  values (auth.uid(), left(coalesce(p_name, ''), 40), p_points, 1, ok, p_correct, m, p_points, ok, now())
  on conflict (user_id) do update set
    name = left(coalesce(nullif(p_name, ''), q.name), 40),
    points = q.points + p_points,
    quizzes = q.quizzes + 1,
    passed = q.passed + ok,
    best = greatest(q.best, p_correct),
    month_points = (case when q.month = m then q.month_points else 0 end) + p_points,
    month_passed = (case when q.month = m then q.month_passed else 0 end) + ok,
    month = m,
    updated_at = now()
  returning * into r;
  return r;
end $$;
revoke execute on function public.record_quiz(int, int, int, text) from public, anon;
grant execute on function public.record_quiz(int, int, int, text) to authenticated;

-- ---------- Messagerie ----------
create table if not exists public.messages (
  id bigint generated always as identity primary key,
  sender uuid not null references auth.users on delete cascade default auth.uid(),
  recipient uuid not null references auth.users on delete cascade,
  body text not null default '' check (char_length(body) <= 2000),
  title jsonb,                         -- film ou série conseillé
  created_at timestamptz not null default now(),
  read_at timestamptz,
  check (sender <> recipient),
  check (char_length(body) > 0 or title is not null)
);
create index if not exists messages_recipient_idx on public.messages (recipient, created_at desc);
create index if not exists messages_sender_idx on public.messages (sender, created_at desc);
alter table public.messages enable row level security;
drop policy if exists "messages: lire les siens" on public.messages;
drop policy if exists "messages: envoyer" on public.messages;
drop policy if exists "messages: marquer lus" on public.messages;
create policy "messages: lire les siens" on public.messages
  for select to authenticated using (sender = auth.uid() or recipient = auth.uid());
create policy "messages: envoyer" on public.messages
  for insert to authenticated with check (sender = auth.uid());
create policy "messages: marquer lus" on public.messages
  for update to authenticated using (recipient = auth.uid()) with check (recipient = auth.uid());
-- seule la date de lecture peut être modifiée
revoke update on public.messages from anon, authenticated;
grant update (read_at) on public.messages to authenticated;

-- ---------- Temps réel ----------
do $$
declare t text;
begin
  foreach t in array array['notifications', 'messages'] loop
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
