-- Task-02 fixture schema snapshot

create table if not exists addresses (
  id uuid primary key,
  user_id uuid not null,
  line1 text not null,
  city text not null,
  is_default boolean not null default false,
  updated_at timestamptz not null default now()
);

create index if not exists idx_addresses_user_id on addresses(user_id);

-- NOTE: no uniqueness guard for one-default-per-user in baseline fixture.
-- This omission is intentional for experiment discussion.
