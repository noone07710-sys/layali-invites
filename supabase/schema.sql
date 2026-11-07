-- Canonical schema snapshot of the Layali tables deployed to gxredstctzkuwgsegykd.
-- For a FRESH database only; do not run again against the existing project.
create extension if not exists pgcrypto;
create table public.layali_invitations(
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references auth.users(id) on delete cascade,
 slug text not null unique check(slug ~ '^[a-z0-9-]{3,80}$'),
 status text not null default 'draft' check(status in ('draft','published','expired')),
 expires_at timestamptz,
 groom text not null check(length(groom) between 1 and 100),
 bride text not null check(length(bride) between 1 and 100),
 wording text not null default '',
 wedding_at timestamptz not null,
 display_date text not null,
 display_time text not null,
 venue text not null,
 city text not null,
 map_url text not null check(map_url ~ '^https://'),
 template text not null default 'romantic' check(template in ('romantic','royal','emerald','lavender','burgundy','modern')),
 reveal_at numeric not null default .43 check(reveal_at between .1 and .85),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table public.layali_rsvps(
 id uuid primary key default gen_random_uuid(),
 invitation_id uuid not null references public.layali_invitations(id) on delete cascade,
 guest_name text not null check(length(guest_name) between 1 and 100),
 attending boolean not null,
 guest_count integer not null default 1 check(guest_count between 1 and 10),
 created_at timestamptz not null default now()
);
create index on public.layali_invitations(owner_id);
create index on public.layali_rsvps(invitation_id,created_at desc);
alter table public.layali_invitations enable row level security;
alter table public.layali_rsvps enable row level security;
create policy "owner create draft" on public.layali_invitations for insert to authenticated with check(owner_id=(select auth.uid()) and status='draft');
create policy "layali invitations read" on public.layali_invitations for select to authenticated using(owner_id=(select auth.uid()) or (select auth.jwt()->'app_metadata'->>'role')='layali_admin');
create policy "layali invitations update" on public.layali_invitations for update to authenticated using((owner_id=(select auth.uid()) and status='draft') or (select auth.jwt()->'app_metadata'->>'role')='layali_admin') with check((owner_id=(select auth.uid()) and status='draft') or (select auth.jwt()->'app_metadata'->>'role')='layali_admin');
create policy "admin delete invitations" on public.layali_invitations for delete to authenticated using((select auth.jwt()->'app_metadata'->>'role')='layali_admin');
create policy "layali responses read" on public.layali_rsvps for select to authenticated using((select auth.jwt()->'app_metadata'->>'role')='layali_admin' or exists(select 1 from public.layali_invitations i where i.id=invitation_id and i.owner_id=(select auth.uid())));
grant select,insert,update,delete on public.layali_invitations to authenticated;
grant select on public.layali_rsvps to authenticated;
revoke all on public.layali_invitations from anon;
revoke all on public.layali_rsvps from anon;
-- Public reads and RSVP writes are handled by the layali-public Edge Function,
-- never by granting anonymous direct access to the tables.
