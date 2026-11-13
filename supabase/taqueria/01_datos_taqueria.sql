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
insert into dishes (name, description, price, cost, category, requires_guisado, max_time) values
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
  ('Taconmadre doble', 'Tortilla de harina, queso, pastor, piña y tocino', 60, 0, 'taconmadre', false, 8);
