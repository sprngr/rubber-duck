-- Task-03 fixture: proposed redesign sketch (intentionally incomplete)

-- Team proposal summary:
-- 1) derive order totals instead of persisting orders.total_cents
-- 2) replace payments with ledger_entries
-- 3) add adjustments for discounts/refunds/taxes

create table if not exists orders (
  id uuid primary key,
  user_id uuid not null,
  status text not null,
  created_at timestamptz not null default now()
  -- total_cents removed (derived)
);

create table if not exists order_items (
  id uuid primary key,
  order_id uuid not null references orders(id),
  sku text not null,
  qty integer not null,
  unit_price_cents integer not null
);

create table if not exists ledger_entries (
  id uuid primary key,
  order_id uuid not null references orders(id),
  type text not null, -- charge | capture | refund | adjustment
  amount_cents integer not null,
  external_ref text,
  created_at timestamptz not null default now()
);

create table if not exists adjustments (
  id uuid primary key,
  order_id uuid not null references orders(id),
  kind text not null, -- discount | tax | refund | fee
  amount_cents integer not null,
  reason text,
  created_at timestamptz not null default now()
);

create index if not exists idx_ledger_entries_order_id on ledger_entries(order_id);
create index if not exists idx_adjustments_order_id on adjustments(order_id);

-- Intentionally missing in sketch for design discussion:
-- - compatibility view/translation for existing API payloads
-- - rollback strategy artifacts
-- - invariants/check constraints for accounting consistency
