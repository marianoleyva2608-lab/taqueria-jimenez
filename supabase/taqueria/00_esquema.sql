-- ============================================================
-- ESQUEMA COMPLETO · Taquería Jiménez
-- Reconstruido a partir del código de la app (mismo sistema que
-- Gorditas Mis Hermanas). Ejecutar UNA vez en el SQL Editor del
-- proyecto Supabase NUEVO de la taquería, antes de 01_datos_taqueria.sql.
-- ============================================================

create extension if not exists pgcrypto;

-- ─── Configuración ───────────────────────────────────────────
create table if not exists public.admin_settings (
  setting_key   text primary key,
  setting_value text,
  updated_at    timestamptz default now()
);

create table if not exists public.app_config (          -- llaves de Clip / OpenPay / Resend (edge functions)
  key   text primary key,
  value text
);

create table if not exists public.admin_users (
  id          uuid primary key default gen_random_uuid(),
  username    text unique not null,
  password    text not null,
  role        text not null default 'admin',           -- 'superadmin' | 'admin'
  branch_name text,                                    -- null = todas las sucursales
  created_at  timestamptz default now()
);

create table if not exists public.subscriptions (
  id           uuid primary key default gen_random_uuid(),
  branch_name  text unique not null,
  paid_until   date not null,
  contact_info text default 'WhatsApp: 449 111 2564',
  notes        text,
  updated_at   timestamptz default now()
);

-- ─── Menú ────────────────────────────────────────────────────
create table if not exists public.dishes (
  id               uuid primary key default gen_random_uuid(),
  name             text not null,
  description      text default '',
  price            numeric not null default 0,
  cost             numeric default 0,
  category         text not null default 'tacos',
  image_url        text,
  is_purchase      boolean default false,
  is_sale          boolean default true,
  available        boolean default true,
  requires_guisado boolean default false,
  pieces_per_order smallint,
  max_time         integer default 10,
  branch_name      text,                                -- null = todas las sucursales
  created_at       timestamptz default now()
);

create table if not exists public.guisados (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  branch_name text,
  available   boolean default true,
  meat_type   text check (meat_type in ('res','cerdo','pollo','sin_carne')),
  spice_level smallint not null default 0 check (spice_level between 0 and 3),
  with_meat   boolean not null default true,
  created_at  timestamptz default now()
);

create table if not exists public.drink_type_prices (
  type  text primary key,
  price numeric not null default 0
);

create table if not exists public.drink_flavors (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  type       text not null,
  available  boolean default true,
  created_at timestamptz default now()
);

-- ─── Salón y personal ────────────────────────────────────────
create table if not exists public.restaurant_tables (
  id           uuid primary key default gen_random_uuid(),
  table_number integer not null,
  status       text not null default 'free',            -- free | occupied
  pos_x        double precision default 50.0,
  pos_y        double precision default 50.0,
  branch_name  text,
  created_at   timestamptz default now()
);

create table if not exists public.waiters (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  pin         text,
  branch_name text,
  created_at  timestamptz default now()
);

create table if not exists public.waiter_ledger (       -- nómina: sueldos, préstamos, bonos, descuentos
  id          uuid primary key default gen_random_uuid(),
  waiter_id   uuid references public.waiters(id) on delete cascade,
  type        text not null,
  amount      numeric not null default 0,
  description text,
  branch_name text,
  created_at  timestamptz default now()
);

-- ─── Órdenes ─────────────────────────────────────────────────
create table if not exists public.orders (
  id                  uuid primary key default gen_random_uuid(),
  table_id            uuid references public.restaurant_tables(id) on delete set null,
  waiter_id           uuid references public.waiters(id) on delete set null,
  status              text not null default 'pending',  -- pending | ready | incomplete | completed | cancelled
  total_amount        numeric not null default 0,
  order_type          text default 'dine_in',           -- dine_in | takeout | to_go | delivery
  customer_name       text,
  branch_name         text,
  daily_folio         integer,
  payment_method      text,
  amount_cash         numeric,
  amount_card         numeric,
  delivery_platform   text check (delivery_platform in ('uber','didi')),
  discount_percent    numeric default 0,
  discount_amount     numeric default 0,
  discount_reason     text,
  cancel_reason       text,
  cancelled_at        timestamptz,
  cancelled_by        text,
  food_ready          boolean default false,
  drinks_ready        boolean default false,
  sent_to_kitchen_at  timestamptz,
  printed_at          timestamptz,
  cuenta_requested_at timestamptz,
  caja_printed_at     timestamptz,
  created_at          timestamptz default now()
);

create table if not exists public.order_items (
  id                uuid primary key default gen_random_uuid(),
  order_id          uuid references public.orders(id) on delete cascade,
  dish_id           uuid references public.dishes(id) on delete set null,
  quantity          integer not null default 1,
  price_at_time     numeric not null default 0,
  status            text not null default 'pending',
  guisados_selected text,                              -- JSON con opciones elegidas
  client_label      text,
  printed_at        timestamptz,
  created_at        timestamptz default now()
);

-- ─── Caja ────────────────────────────────────────────────────
create table if not exists public.cash_movements (
  id             uuid primary key default gen_random_uuid(),
  type           text not null,                         -- apertura | entrada | gasto | ...
  category       text,
  amount         numeric not null default 0,
  payment_method text,
  description    text,
  recipient      text,
  registered_by  text,
  branch_name    text,
  created_at     timestamptz default now()
);

create table if not exists public.cash_closings (
  id            uuid primary key default gen_random_uuid(),
  branch_name   text not null,
  closed_at     timestamptz not null default now(),
  expected_cash numeric not null,
  counted_cash  numeric not null,
  difference    numeric not null,
  registered_by text,
  notes         text
);

create table if not exists public.corte_requests (
  id           uuid primary key default gen_random_uuid(),
  branch_name  text not null,
  requested_at timestamptz not null default now(),
  printed_at   timestamptz
);

create table if not exists public.print_worker_heartbeats (
  id           text primary key,                        -- "<sucursal>:<área>"
  branch_name  text not null,
  print_area   text not null,
  last_seen_at timestamptz not null default now()
);

-- ─── Clientes, facturación y promociones ────────────────────
create table if not exists public.cw_clients (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  rfc          text,
  email        text,
  regimen_code text,
  person_type  text,
  created_at   timestamptz default now()
);

create table if not exists public.promo_codes (
  code        text primary key,
  percent     numeric not null check (percent > 0 and percent <= 100),
  active      boolean not null default true,
  expires_at  timestamptz,
  description text,
  created_at  timestamptz not null default now()
);

create table if not exists public.promo_redemptions (
  id          uuid primary key default gen_random_uuid(),
  code        text not null references public.promo_codes(code),
  phone       text not null,
  order_id    uuid,
  branch_name text,
  redeemed_at timestamptz not null default now(),
  unique (code, phone)
);

-- ─── Índices ─────────────────────────────────────────────────
create index if not exists orders_branch_created_idx on public.orders (branch_name, created_at desc);
create index if not exists orders_status_idx        on public.orders (status);
create index if not exists orders_table_idx         on public.orders (table_id);
create index if not exists order_items_order_idx    on public.order_items (order_id);
create index if not exists cash_movements_branch_idx on public.cash_movements (branch_name, created_at desc);
create index if not exists cash_closings_branch_idx on public.cash_closings (branch_name, closed_at desc);
create index if not exists corte_requests_branch_idx on public.corte_requests (branch_name);
create index if not exists dishes_category_idx      on public.dishes (category);

-- ─── Acceso (igual que gorditas: la app usa la anon key) ─────
do $$
declare t text;
begin
  foreach t in array array[
    'admin_settings','admin_users','subscriptions','dishes','guisados',
    'drink_type_prices','drink_flavors','restaurant_tables','waiters',
    'waiter_ledger','orders','order_items','cash_movements','cash_closings',
    'corte_requests','print_worker_heartbeats','cw_clients','promo_codes',
    'promo_redemptions'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "app_full_access" on public.%I', t);
    execute format('create policy "app_full_access" on public.%I for all to anon, authenticated using (true) with check (true)', t);
  end loop;
end $$;

-- app_config guarda llaves secretas: solo la lee la edge function (service_role)
alter table public.app_config enable row level security;

-- ─── Realtime (pantallas que se actualizan solas) ───────────
do $$
declare t text;
begin
  foreach t in array array[
    'orders','order_items','restaurant_tables','dishes','waiters','guisados',
    'admin_settings','admin_users','cw_clients','corte_requests','cash_movements'
  ] loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then null;
    end;
  end loop;
end $$;

-- ─── Fotos de platillos (Storage) ────────────────────────────
insert into storage.buckets (id, name, public)
values ('dish_images', 'dish_images', true)
on conflict (id) do nothing;

drop policy if exists "dish_images_read"  on storage.objects;
drop policy if exists "dish_images_write" on storage.objects;
drop policy if exists "dish_images_update" on storage.objects;
create policy "dish_images_read"  on storage.objects for select to anon, authenticated using (bucket_id = 'dish_images');
create policy "dish_images_write" on storage.objects for insert to anon, authenticated with check (bucket_id = 'dish_images');
create policy "dish_images_update" on storage.objects for update to anon, authenticated using (bucket_id = 'dish_images') with check (bucket_id = 'dish_images');
