-- Pega TODO este archivo en Supabase (proyecto de la TAQUERÍA) → SQL Editor → Run.
-- Se puede volver a correr sin duplicar nada.

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

-- ─── Compatibilidad: si una tabla ya existía con un esquema viejo, ───
-- agrega las columnas que le falten (create table if not exists no lo hace).

alter table public.admin_settings add column if not exists setting_key text;
alter table public.admin_settings add column if not exists setting_value text;
alter table public.admin_settings add column if not exists updated_at timestamptz default now();
alter table public.app_config add column if not exists key text;
alter table public.app_config add column if not exists value text;
alter table public.admin_users add column if not exists id uuid default gen_random_uuid();
alter table public.admin_users add column if not exists username text;
alter table public.admin_users add column if not exists password text;
alter table public.admin_users add column if not exists role text;
alter table public.admin_users add column if not exists branch_name text;
alter table public.admin_users add column if not exists created_at timestamptz default now();
alter table public.subscriptions add column if not exists id uuid default gen_random_uuid();
alter table public.subscriptions add column if not exists branch_name text;
alter table public.subscriptions add column if not exists paid_until date;
alter table public.subscriptions add column if not exists contact_info text default 'WhatsApp: 449 111 2564';
alter table public.subscriptions add column if not exists notes text;
alter table public.subscriptions add column if not exists updated_at timestamptz default now();
alter table public.dishes add column if not exists id uuid default gen_random_uuid();
alter table public.dishes add column if not exists name text;
alter table public.dishes add column if not exists description text default '';
alter table public.dishes add column if not exists price numeric;
alter table public.dishes add column if not exists cost numeric default 0;
alter table public.dishes add column if not exists category text;
alter table public.dishes add column if not exists image_url text;
alter table public.dishes add column if not exists is_purchase boolean default false;
alter table public.dishes add column if not exists is_sale boolean default true;
alter table public.dishes add column if not exists available boolean default true;
alter table public.dishes add column if not exists requires_guisado boolean default false;
alter table public.dishes add column if not exists pieces_per_order smallint;
alter table public.dishes add column if not exists max_time integer default 10;
alter table public.dishes add column if not exists branch_name text;
alter table public.dishes add column if not exists created_at timestamptz default now();
alter table public.guisados add column if not exists id uuid default gen_random_uuid();
alter table public.guisados add column if not exists name text;
alter table public.guisados add column if not exists branch_name text;
alter table public.guisados add column if not exists available boolean default true;
alter table public.guisados add column if not exists meat_type text;
alter table public.guisados add column if not exists spice_level smallint;
alter table public.guisados add column if not exists with_meat boolean;
alter table public.guisados add column if not exists created_at timestamptz default now();
alter table public.drink_type_prices add column if not exists type text;
alter table public.drink_type_prices add column if not exists price numeric;
alter table public.drink_flavors add column if not exists id uuid default gen_random_uuid();
alter table public.drink_flavors add column if not exists name text;
alter table public.drink_flavors add column if not exists type text;
alter table public.drink_flavors add column if not exists available boolean default true;
alter table public.drink_flavors add column if not exists created_at timestamptz default now();
alter table public.restaurant_tables add column if not exists id uuid default gen_random_uuid();
alter table public.restaurant_tables add column if not exists table_number integer;
alter table public.restaurant_tables add column if not exists status text;
alter table public.restaurant_tables add column if not exists pos_x double precision default 50.0;
alter table public.restaurant_tables add column if not exists pos_y double precision default 50.0;
alter table public.restaurant_tables add column if not exists branch_name text;
alter table public.restaurant_tables add column if not exists created_at timestamptz default now();
alter table public.waiters add column if not exists id uuid default gen_random_uuid();
alter table public.waiters add column if not exists name text;
alter table public.waiters add column if not exists pin text;
alter table public.waiters add column if not exists branch_name text;
alter table public.waiters add column if not exists created_at timestamptz default now();
alter table public.waiter_ledger add column if not exists id uuid default gen_random_uuid();
alter table public.waiter_ledger add column if not exists waiter_id uuid;
alter table public.waiter_ledger add column if not exists type text;
alter table public.waiter_ledger add column if not exists amount numeric;
alter table public.waiter_ledger add column if not exists description text;
alter table public.waiter_ledger add column if not exists branch_name text;
alter table public.waiter_ledger add column if not exists created_at timestamptz default now();
alter table public.orders add column if not exists id uuid default gen_random_uuid();
alter table public.orders add column if not exists table_id uuid;
alter table public.orders add column if not exists waiter_id uuid;
alter table public.orders add column if not exists status text;
alter table public.orders add column if not exists total_amount numeric;
alter table public.orders add column if not exists order_type text default 'dine_in';
alter table public.orders add column if not exists customer_name text;
alter table public.orders add column if not exists branch_name text;
alter table public.orders add column if not exists daily_folio integer;
alter table public.orders add column if not exists payment_method text;
alter table public.orders add column if not exists amount_cash numeric;
alter table public.orders add column if not exists amount_card numeric;
alter table public.orders add column if not exists delivery_platform text;
alter table public.orders add column if not exists discount_percent numeric default 0;
alter table public.orders add column if not exists discount_amount numeric default 0;
alter table public.orders add column if not exists discount_reason text;
alter table public.orders add column if not exists cancel_reason text;
alter table public.orders add column if not exists cancelled_at timestamptz;
alter table public.orders add column if not exists cancelled_by text;
alter table public.orders add column if not exists food_ready boolean default false;
alter table public.orders add column if not exists drinks_ready boolean default false;
alter table public.orders add column if not exists sent_to_kitchen_at timestamptz;
alter table public.orders add column if not exists printed_at timestamptz;
alter table public.orders add column if not exists cuenta_requested_at timestamptz;
alter table public.orders add column if not exists caja_printed_at timestamptz;
alter table public.orders add column if not exists created_at timestamptz default now();
alter table public.order_items add column if not exists id uuid default gen_random_uuid();
alter table public.order_items add column if not exists order_id uuid;
alter table public.order_items add column if not exists dish_id uuid;
alter table public.order_items add column if not exists quantity integer;
alter table public.order_items add column if not exists price_at_time numeric;
alter table public.order_items add column if not exists status text;
alter table public.order_items add column if not exists guisados_selected text;
alter table public.order_items add column if not exists client_label text;
alter table public.order_items add column if not exists printed_at timestamptz;
alter table public.order_items add column if not exists created_at timestamptz default now();
alter table public.cash_movements add column if not exists id uuid default gen_random_uuid();
alter table public.cash_movements add column if not exists type text;
alter table public.cash_movements add column if not exists category text;
alter table public.cash_movements add column if not exists amount numeric;
alter table public.cash_movements add column if not exists payment_method text;
alter table public.cash_movements add column if not exists description text;
alter table public.cash_movements add column if not exists recipient text;
alter table public.cash_movements add column if not exists registered_by text;
alter table public.cash_movements add column if not exists branch_name text;
alter table public.cash_movements add column if not exists created_at timestamptz default now();
alter table public.cash_closings add column if not exists id uuid default gen_random_uuid();
alter table public.cash_closings add column if not exists branch_name text;
alter table public.cash_closings add column if not exists closed_at timestamptz;
alter table public.cash_closings add column if not exists expected_cash numeric;
alter table public.cash_closings add column if not exists counted_cash numeric;
alter table public.cash_closings add column if not exists difference numeric;
alter table public.cash_closings add column if not exists registered_by text;
alter table public.cash_closings add column if not exists notes text;
alter table public.corte_requests add column if not exists id uuid default gen_random_uuid();
alter table public.corte_requests add column if not exists branch_name text;
alter table public.corte_requests add column if not exists requested_at timestamptz;
alter table public.corte_requests add column if not exists printed_at timestamptz;
alter table public.print_worker_heartbeats add column if not exists id text;
alter table public.print_worker_heartbeats add column if not exists branch_name text;
alter table public.print_worker_heartbeats add column if not exists print_area text;
alter table public.print_worker_heartbeats add column if not exists last_seen_at timestamptz;
alter table public.cw_clients add column if not exists id uuid default gen_random_uuid();
alter table public.cw_clients add column if not exists name text;
alter table public.cw_clients add column if not exists rfc text;
alter table public.cw_clients add column if not exists email text;
alter table public.cw_clients add column if not exists regimen_code text;
alter table public.cw_clients add column if not exists person_type text;
alter table public.cw_clients add column if not exists created_at timestamptz default now();
alter table public.promo_codes add column if not exists code text;
alter table public.promo_codes add column if not exists percent numeric;
alter table public.promo_codes add column if not exists active boolean;
alter table public.promo_codes add column if not exists expires_at timestamptz;
alter table public.promo_codes add column if not exists description text;
alter table public.promo_codes add column if not exists created_at timestamptz;
alter table public.promo_redemptions add column if not exists id uuid default gen_random_uuid();
alter table public.promo_redemptions add column if not exists code text;
alter table public.promo_redemptions add column if not exists phone text;
alter table public.promo_redemptions add column if not exists order_id uuid;
alter table public.promo_redemptions add column if not exists branch_name text;
alter table public.promo_redemptions add column if not exists redeemed_at timestamptz;

-- Índices únicos que usan los "on conflict" de la carga de datos.
create unique index if not exists admin_settings_key_uidx on public.admin_settings (setting_key);
create unique index if not exists subscriptions_branch_uidx on public.subscriptions (branch_name);

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


-- ============================================================
-- DATOS INICIALES · Taquería Jiménez
-- Ejecutar DESPUÉS de 00_esquema.sql, en el SQL Editor del proyecto
-- Supabase NUEVO de la taquería (no en el de las gorditas).
-- Precios tomados del menú de la pared (nov 2026).
-- ============================================================

-- Sucursal
insert into admin_settings (setting_key, setting_value) values
  ('branches_list', '["Sucursal Principal"]')
on conflict (setting_key) do update set setting_value = excluded.setting_value;

-- Accesos iniciales (CÁMBIALOS en Admin → Seguridad al entrar por primera vez)
insert into admin_settings (setting_key, setting_value) values
  ('admin_user', 'admin'),
  ('admin_pass', '1234'),
  ('master_pin', '0000'),
  ('kitchen_pin', '0000'),
  ('bar_pin', '0000')
on conflict (setting_key) do nothing;

-- Suscripción de la sucursal (90 días)
insert into subscriptions (branch_name, paid_until)
values ('Sucursal Principal', (current_date + interval '90 days')::date)
on conflict (branch_name) do nothing;

-- Mesas 1..10
insert into restaurant_tables (table_number, branch_name, status, pos_x, pos_y)
select n, 'Sucursal Principal', 'free', 50.0, 50.0 from generate_series(1,10) n
where not exists (select 1 from restaurant_tables where branch_name='Sucursal Principal');

-- Menú (65 productos). Bebidas: darlas de alta desde Admin con su precio.
insert into dishes (name, description, price, cost, category, requires_guisado, max_time)
select * from (values
  ('Taco de Pastor', '', 15, 0, 'tacos', false, 5),
  ('Taco de Chorizo', '', 15, 0, 'tacos', false, 5),
  ('Taco de Buche', '', 15, 0, 'tacos', false, 5),
  ('Taco de Cabeza', '', 15, 0, 'tacos', false, 5),
  ('Taco de Bistec', '', 16, 0, 'tacos', false, 5),
  ('Taco de Costilla', '', 16, 0, 'tacos', false, 5),
  ('Taco de Lengua', '', 22, 0, 'tacos', false, 5),
  ('Quesadilla de Pastor', 'Sencilla', 39, 0, 'quesadillas', false, 8),
  ('Quesadilla de Chorizo', 'Sencilla', 39, 0, 'quesadillas', false, 8),
  ('Quesadilla de Buche', 'Sencilla', 39, 0, 'quesadillas', false, 8),
  ('Quesadilla de Cabeza', 'Sencilla', 39, 0, 'quesadillas', false, 8),
  ('Quesadilla de Bistec', 'Sencilla', 42, 0, 'quesadillas', false, 8),
  ('Quesadilla de Costilla', 'Sencilla', 42, 0, 'quesadillas', false, 8),
  ('Quesadilla de Lengua', 'Sencilla', 50, 0, 'quesadillas', false, 8),
  ('Quesadilla de Pastor doble', 'Doble', 49, 0, 'quesadillas', false, 8),
  ('Quesadilla de Chorizo doble', 'Doble', 49, 0, 'quesadillas', false, 8),
  ('Quesadilla de Buche doble', 'Doble', 49, 0, 'quesadillas', false, 8),
  ('Quesadilla de Cabeza doble', 'Doble', 49, 0, 'quesadillas', false, 8),
  ('Quesadilla de Bistec doble', 'Doble', 52, 0, 'quesadillas', false, 8),
  ('Quesadilla de Costilla doble', 'Doble', 52, 0, 'quesadillas', false, 8),
  ('Quesadilla de Lengua doble', 'Doble', 60, 0, 'quesadillas', false, 8),
  ('Torta de Pastor', '', 50, 0, 'tortas', false, 8),
  ('Torta de Chorizo', '', 50, 0, 'tortas', false, 8),
  ('Torta de Buche', '', 50, 0, 'tortas', false, 8),
  ('Torta de Cabeza', '', 50, 0, 'tortas', false, 8),
  ('Torta de Bistec', '', 55, 0, 'tortas', false, 8),
  ('Torta de Costilla', '', 55, 0, 'tortas', false, 8),
  ('Torta de Lengua', '', 60, 0, 'tortas', false, 8),
  ('Burro de Pastor', '', 90, 0, 'burros', false, 8),
  ('Burro de Chorizo', '', 90, 0, 'burros', false, 8),
  ('Burro de Buche', '', 90, 0, 'burros', false, 8),
  ('Burro de Cabeza', '', 90, 0, 'burros', false, 8),
  ('Burro de Bistec', '', 100, 0, 'burros', false, 8),
  ('Burro de Costilla', '', 100, 0, 'burros', false, 8),
  ('Burro de Lengua', '', 120, 0, 'burros', false, 8),
  ('Plato de Pastor chico', 'Plato chico', 90, 0, 'platos', false, 10),
  ('Plato de Chorizo chico', 'Plato chico', 90, 0, 'platos', false, 10),
  ('Plato de Buche chico', 'Plato chico', 90, 0, 'platos', false, 10),
  ('Plato de Cabeza chico', 'Plato chico', 90, 0, 'platos', false, 10),
  ('Plato de Bistec chico', 'Plato chico', 100, 0, 'platos', false, 10),
  ('Plato de Costilla chico', 'Plato chico', 100, 0, 'platos', false, 10),
  ('Plato de Lengua chico', 'Plato chico', 120, 0, 'platos', false, 10),
  ('Plato de Pastor mediano', 'Plato mediano', 120, 0, 'platos', false, 10),
  ('Plato de Chorizo mediano', 'Plato mediano', 120, 0, 'platos', false, 10),
  ('Plato de Buche mediano', 'Plato mediano', 120, 0, 'platos', false, 10),
  ('Plato de Cabeza mediano', 'Plato mediano', 120, 0, 'platos', false, 10),
  ('Plato de Bistec mediano', 'Plato mediano', 140, 0, 'platos', false, 10),
  ('Plato de Costilla mediano', 'Plato mediano', 140, 0, 'platos', false, 10),
  ('Plato de Lengua mediano', 'Plato mediano', 160, 0, 'platos', false, 10),
  ('Plato de Pastor grande', 'Plato grande', 160, 0, 'platos', false, 10),
  ('Plato de Chorizo grande', 'Plato grande', 160, 0, 'platos', false, 10),
  ('Plato de Buche grande', 'Plato grande', 160, 0, 'platos', false, 10),
  ('Plato de Cabeza grande', 'Plato grande', 160, 0, 'platos', false, 10),
  ('Plato de Bistec grande', 'Plato grande', 180, 0, 'platos', false, 10),
  ('Plato de Costilla grande', 'Plato grande', 180, 0, 'platos', false, 10),
  ('Plato de Lengua grande', 'Plato grande', 200, 0, 'platos', false, 10),
  ('Kilo de Pastor', '1 kg', 480, 0, 'kilos', false, 15),
  ('Kilo de Chorizo', '1 kg', 480, 0, 'kilos', false, 15),
  ('Kilo de Buche', '1 kg', 480, 0, 'kilos', false, 15),
  ('Kilo de Cabeza', '1 kg', 480, 0, 'kilos', false, 15),
  ('Kilo de Bistec', '1 kg', 500, 0, 'kilos', false, 15),
  ('Kilo de Costilla', '1 kg', 500, 0, 'kilos', false, 15),
  ('Kilo de Lengua', '1 kg', 650, 0, 'kilos', false, 15),
  ('Taconmadre sencillo', 'Tortilla de harina, queso, pastor, piña y tocino', 50, 0, 'taconmadre', false, 8),
  ('Taconmadre doble', 'Tortilla de harina, queso, pastor, piña y tocino', 60, 0, 'taconmadre', false, 8)
) v(name, description, price, cost, category, requires_guisado, max_time)
where not exists (select 1 from dishes);
