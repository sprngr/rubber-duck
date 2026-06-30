-- Task-03 fixture: current ecommerce order model

create table if not exists orders (
  id uuid primary key,
  user_id uuid not null,
  total_cents integer not null,
  status text not null,
  created_at timestamptz not null default now()
);

create table if not exists order_items (
  id uuid primary key,
  order_id uuid not null references orders(id),
  sku text not null,
  qty integer not null,
  unit_price_cents integer not null
);

create table if not exists payments (
  id uuid primary key,
  order_id uuid not null references orders(id),
  provider text not null,
  amount_cents integer not null,
  status text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_orders_user_id on orders(user_id);
create index if not exists idx_order_items_order_id on order_items(order_id);
create index if not exists idx_payments_order_id on payments(order_id);
