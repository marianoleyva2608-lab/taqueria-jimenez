# Taquería Jiménez · Punto de venta

Copia adaptada del sistema de **Gorditas Mis Hermanas** (`restaurant_pwa`), con la marca, el menú y la configuración de la Taquería Jiménez. Usa Flutter Web y un proyecto de Supabase propio.

Incluye: mesero con PIN y comandas por mesa, para llevar y domicilio, cocina (pantalla o impresora), caja con apertura y cierre, cortes, reportes y administración (menú, meseros, mesas y seguridad).

## 1. Base de datos (Supabase nuevo)

En el **SQL Editor** del proyecto de la taquería, ejecuta en este orden:

1. `supabase/taqueria/00_esquema.sql`: crea las tablas, las políticas y el realtime (copiados de las gorditas).
2. `supabase/taqueria/01_datos_taqueria.sql`: sucursal, accesos iniciales, 10 mesas y el menú con los precios de la pared.

Las bebidas no vienen en el menú porque los precios no se ven en el letrero. Dalas de alta en **Admin**.

Accesos iniciales (cámbialos al entrar): admin `admin` / `1234`, PIN maestro `0000`.

## 2. Deploy en EasyPanel

- Crea la app desde este repo. Se construye con el `Dockerfile`.
- Variables de entorno:
  - `SUPABASE_URL`: `https://<proyecto>.supabase.co`
  - `SUPABASE_ANON_KEY`: la anon public key
  - `GOOGLE_MAPS_API_KEY` (opcional, para calcular la cuota de envío)

Para el APK de tablet, pasa los mismos valores con `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`.

## Pendiente de ajustar

- La dirección y las coordenadas reales de la sucursal están en `lib/services/delivery_fee.dart`. Las actuales son de ejemplo.
- Los datos fiscales están en `CFDIConfig`, dentro de `lib/globals.dart`. Por ahora son los de demo.
- Para Clip y OpenPay hay que desplegar las edge functions en el proyecto nuevo (ver `supabase/functions/*/README.md`).
- Print-worker y kitchen-display: apúntalos al Supabase nuevo con sus variables `SUPABASE_URL` y `SUPABASE_ANON_KEY`.
