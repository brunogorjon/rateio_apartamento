-- ================================================================
-- RATEIO DO APARTAMENTO — configuração do Supabase
-- ================================================================
-- ANTES DE EXECUTAR:
-- 1) Troque os e-mails abaixo pelos e-mails das pessoas autorizadas.
-- 2) Se alterar o groupId, use o MESMO valor em config.js.
-- 3) Execute tudo no SQL Editor do seu projeto Supabase.
-- ================================================================

create table if not exists public.rateio_groups (
  id text primary key,
  member_emails text[] not null default '{}',
  data jsonb not null default '{}'::jsonb,
  revision bigint not null default 0,
  updated_at timestamptz not null default now(),
  updated_by uuid null
);

alter table public.rateio_groups enable row level security;

-- Remove permissões amplas e libera somente o necessário.
revoke all on table public.rateio_groups from anon;
revoke all on table public.rateio_groups from authenticated;
grant select on table public.rateio_groups to authenticated;
grant update (data) on table public.rateio_groups to authenticated;

-- Políticas: somente e-mails presentes em member_emails enxergam/alteram o grupo.
drop policy if exists "rateio_select_members" on public.rateio_groups;
create policy "rateio_select_members"
on public.rateio_groups
for select
to authenticated
using (
  exists (
    select 1
    from unnest(member_emails) as allowed(email)
    where lower(allowed.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  )
);

drop policy if exists "rateio_update_members" on public.rateio_groups;
create policy "rateio_update_members"
on public.rateio_groups
for update
to authenticated
using (
  exists (
    select 1
    from unnest(member_emails) as allowed(email)
    where lower(allowed.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  )
)
with check (
  exists (
    select 1
    from unnest(member_emails) as allowed(email)
    where lower(allowed.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  )
);

-- O navegador só envia "data". O banco controla revisão, data e autor.
create or replace function public.rateio_before_update()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  new.revision := old.revision + 1;
  new.updated_at := now();
  new.updated_by := auth.uid();
  new.id := old.id;
  new.member_emails := old.member_emails;
  return new;
end;
$$;

drop trigger if exists trg_rateio_before_update on public.rateio_groups;
create trigger trg_rateio_before_update
before update on public.rateio_groups
for each row execute function public.rateio_before_update();

-- Auditoria administrativa: fica disponível no painel/SQL do Supabase,
-- mas não é exposta ao navegador dos participantes.
create table if not exists public.rateio_audit (
  id bigint generated always as identity primary key,
  group_id text not null,
  revision bigint not null,
  changed_at timestamptz not null default now(),
  changed_by uuid null,
  changed_email text null,
  snapshot jsonb not null
);

alter table public.rateio_audit enable row level security;
revoke all on table public.rateio_audit from anon;
revoke all on table public.rateio_audit from authenticated;

create or replace function public.rateio_write_audit()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  insert into public.rateio_audit(group_id, revision, changed_at, changed_by, changed_email, snapshot)
  values (
    new.id,
    new.revision,
    now(),
    auth.uid(),
    auth.jwt() ->> 'email',
    new.data
  );
  return new;
end;
$$;

drop trigger if exists trg_rateio_write_audit on public.rateio_groups;
create trigger trg_rateio_write_audit
after update on public.rateio_groups
for each row execute function public.rateio_write_audit();

-- Cria o grupo compartilhado.
-- >>> TROQUE OS E-MAILS ABAIXO <<<
insert into public.rateio_groups (id, member_emails, data)
values (
  'apartamento-praia-2026',
  array[
    'brunogorjon@gmail.com',
    'PESSOA2@EXEMPLO.COM'
  ],
  '{}'::jsonb
)
on conflict (id) do update
set member_emails = excluded.member_emails;

-- Ativa atualizações em tempo real para a tabela.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'rateio_groups'
  ) then
    execute 'alter publication supabase_realtime add table public.rateio_groups';
  end if;
end $$;

-- Exemplos para administrar acessos depois:
--
-- Ver os autorizados:
-- select id, member_emails from public.rateio_groups;
--
-- Trocar a lista de autorizados:
-- update public.rateio_groups
-- set member_emails = array['voce@email.com','amigo@email.com']
-- where id = 'apartamento-praia-2026';
--
-- Ver histórico/auditoria:
-- select revision, changed_at, changed_email
-- from public.rateio_audit
-- where group_id = 'apartamento-praia-2026'
-- order by revision desc;
