-- Layali: proposed schema, NOT applied to any Supabase project.
-- Configure a dedicated Supabase project, Auth and secure server-side admin operations.
create extension if not exists pgcrypto;
create table if not exists public.layali_invitations (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references auth.users(id) on delete cascade,
 slug text not null unique check (slug ~ '^[a-z0-9-]{3,80}$'),
 status text not null default 'draft' check(status in ('draft','published','expired')),
 expires_at timestamptz,
 groom text not null,
 bride text not null,
 wording text not null default '',
 wedding_at timestamptz not null,
 display_date text not null,
 display_time text not null,
 venue text not null,
 city text not null,
 map_url text not null,
 template text not null default 'romantic',
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table if not exists public.layali_rsvps (
 id uuid primary key default gen_random_uuid(),
 invitation_id uuid not null references public.layali_invitations(id) on delete cascade,
 guest_name text not null check(length(guest_name) between 1 and 100),
 attending boolean not null,
 guest_count integer not null default 1 check(guest_count between 1 and 10),
 created_at timestamptz not null default now()
);
alter table public.layali_invitations enable row level security;
alter table public.layali_rsvps enable row level security;
create policy "owners read own invitations" on public.layali_invitations for select to authenticated using ((select auth.uid())=owner_id);
create policy "owners create own drafts" on public.layali_invitations for insert to authenticated with check ((select auth.uid())=owner_id and status='draft');
create policy "owners edit own invitations" on public.layali_invitations for update to authenticated using ((select auth.uid())=owner_id) with check ((select auth.uid())=owner_id);
create policy "owners delete own invitations" on public.layali_invitations for delete to authenticated using ((select auth.uid())=owner_id);
create policy "owners read own rsvps" on public.layali_rsvps for select to authenticated using (exists(select 1 from public.layali_invitations i where i.id=invitation_id and i.owner_id=(select auth.uid())));
-- Intentionally no anonymous INSERT policy for RSVP: implement rate-limited Edge Function
-- with CAPTCHA/abuse protection and server-side published/expiry validation.
-- Public invitation reads and admin authorization must be implemented via narrowly
-- scoped server-side endpoints, not by exposing owner records or service-role keys.
