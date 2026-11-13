import 'services/runtime_env.dart';

/// Supabase de Taquería Jiménez. En web se lee de env-config.js
/// (variables SUPABASE_URL / SUPABASE_ANON_KEY del container en EasyPanel);
/// en APK se pasa con --dart-define.
String get kSupabaseUrl {
  final v = runtimeEnv('SUPABASE_URL');
  return v.isNotEmpty ? v : const String.fromEnvironment('SUPABASE_URL');
}

String get kSupabaseAnonKey {
  final v = runtimeEnv('SUPABASE_ANON_KEY');
  return v.isNotEmpty ? v : const String.fromEnvironment('SUPABASE_ANON_KEY');
}


/// Esquema de Postgres donde viven las tablas. Por defecto 'public'.
/// Si la taquería comparte proyecto de Supabase con otra app, sus tablas
/// van en el esquema 'taqueria' (variable SUPABASE_SCHEMA en EasyPanel).
String get kSupabaseSchema {
  final v = runtimeEnv('SUPABASE_SCHEMA');
  if (v.isNotEmpty) return v;
  const d = String.fromEnvironment('SUPABASE_SCHEMA');
  return d.isNotEmpty ? d : 'public';
}

/// Modo de pruebas sin Clip: PAGOS_SIMULADOS=true en EasyPanel.
/// El pago en línea del cliente se aprueba con un botón, sin cobrar.
bool get kPagosSimulados {
  final v = runtimeEnv('PAGOS_SIMULADOS');
  if (v.isNotEmpty) return v.toLowerCase() == 'true';
  return const bool.fromEnvironment('PAGOS_SIMULADOS');
}
