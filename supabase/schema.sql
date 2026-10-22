-- =====================================================================
-- TaskFlow — схема базы данных Supabase
-- Запуск: Supabase Dashboard → SQL Editor → New query → вставить → Run
-- Скрипт можно запускать повторно: он удаляет и создаёт объекты заново.
-- =====================================================================

-- ---------- 0. Очистка (для повторного запуска) ----------
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user();
drop table if exists public.reminders;
drop table if exists public.tasks;
drop table if exists public.categories;
drop table if exists public.profiles;

-- ---------- 1. Профили пользователей ----------
-- Учётные записи (email, пароль) хранит Supabase Auth в auth.users,
-- здесь только дополнительные данные профиля.
create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  name        text check (char_length(name) <= 100),
  created_at  timestamptz not null default now()
);

-- ---------- 2. Категории ----------
create table public.categories (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name        text not null check (char_length(name) between 1 and 50),
  color       text not null default '#2EC4B6' check (color ~ '^#[0-9A-Fa-f]{6}$'),
  created_at  timestamptz not null default now(),
  unique (user_id, name)
);

-- ---------- 3. Задачи ----------
create table public.tasks (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users (id) on delete cascade,
  category_id  uuid references public.categories (id) on delete set null,  -- ФТ-11: задачи остаются «без категории»
  title        text not null check (char_length(title) between 1 and 200),
  description  text check (char_length(description) <= 2000),
  due_at       timestamptz,
  priority     smallint not null default 2 check (priority between 1 and 3),   -- 1 высокий, 2 средний, 3 низкий
  repeat       text not null default 'none' check (repeat in ('none', 'daily', 'weekly', 'monthly')),
  is_done      boolean not null default false,
  completed_at timestamptz,                                                   -- ФТ-18: когда выполнена (серии, тепловая карта)
  created_at   timestamptz not null default now()
);

-- ---------- 4. Напоминания ----------
create table public.reminders (
  id              uuid primary key default gen_random_uuid(),
  task_id         uuid not null references public.tasks (id) on delete cascade,
  remind_at       timestamptz not null,
  offset_minutes  integer not null default 0 check (offset_minutes in (0, 15, 60, 1440)),  -- ФТ-13
  is_sent         boolean not null default false,
  created_at      timestamptz not null default now()
);

comment on table public.tasks is 'Задачи пользователя: priority 1 — высокий, 2 — средний, 3 — низкий';

-- ---------- 5. Индексы ----------
create index tasks_user_due_idx      on public.tasks (user_id, due_at);
create index tasks_category_idx      on public.tasks (category_id);
create index categories_user_idx     on public.categories (user_id);
create index reminders_task_idx      on public.reminders (task_id);
create index tasks_user_completed_idx on public.tasks (user_id, completed_at) where completed_at is not null;

-- ---------- 6. Row Level Security (НФТ-2) ----------
-- Каждый пользователь видит и меняет только свои данные.
alter table public.profiles   enable row level security;
alter table public.categories enable row level security;
alter table public.tasks      enable row level security;
alter table public.reminders  enable row level security;

-- profiles: читать и менять только свой профиль (создаётся триггером)
create policy "profiles: свой профиль — чтение" on public.profiles
  for select to authenticated using (id = (select auth.uid()));
create policy "profiles: свой профиль — изменение" on public.profiles
  for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- categories: полный доступ к своим категориям
create policy "categories: свои" on public.categories
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- tasks: свои задачи; категорию можно указать только свою
create policy "tasks: свои" on public.tasks
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (
    user_id = (select auth.uid())
    and (
      category_id is null
      or exists (select 1 from public.categories c
                 where c.id = category_id and c.user_id = (select auth.uid()))
    )
  );

-- reminders: доступ через владельца задачи
create policy "reminders: через свою задачу" on public.reminders
  for all to authenticated
  using (exists (select 1 from public.tasks t
                 where t.id = task_id and t.user_id = (select auth.uid())))
  with check (exists (select 1 from public.tasks t
                      where t.id = task_id and t.user_id = (select auth.uid())));

-- ---------- 7. Автосоздание профиля и стартовых категорий ----------
-- При регистрации (ФТ-1) создаются профиль и три категории по умолчанию.
-- Имя берётся из поля "name", переданного при signUp, иначе из email.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'name', split_part(new.email, '@', 1)));

  insert into public.categories (user_id, name, color) values
    (new.id, 'Учёба',  '#2EC4B6'),
    (new.id, 'Работа', '#FF7A59'),
    (new.id, 'Дом',    '#F5B700');

  return new;
end;
$$;

-- функцию вызывает только триггер, напрямую из API она недоступна
revoke execute on function public.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- 8. Проверка ----------
-- После запуска должно вернуться 4 строки с rls_enabled = true:
select tablename, rowsecurity as rls_enabled
from pg_tables
where schemaname = 'public' and tablename in ('profiles', 'categories', 'tasks', 'reminders')
order by tablename;
