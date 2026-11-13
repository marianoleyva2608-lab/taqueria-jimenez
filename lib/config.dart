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

