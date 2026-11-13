import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

/// Servicio para procesar pagos con Clip y enviar tickets por email.
///
/// Usa la edge function `clip-pago` desplegada en el Supabase del restaurante.
/// Lee credenciales (clip_secret_key, resend_api_key, etc.) de la tabla
/// `public.app_config`.
class ClipService {
  static String get _anonKey => kSupabaseAnonKey;
  static String get _fnUrl => '$kSupabaseUrl/functions/v1/clip-pago';

  static Future<Map<String, dynamic>> _call(
      Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse(_fnUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_anonKey',
        'apikey': _anonKey,
      },
      body: jsonEncode(body),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Procesa el pago con Clip y devuelve el resultado.
  static Future<ClipResult> procesarPago({
    required String token,
    required double amount,
    required String email,
    required List<Map<String, dynamic>> items,
    int installments = 1,
  }) async {
    final json = await _call({
      'action': 'clip',
      'token': token,
      'installments': installments,
      'amount': amount,
      'email': email,
      'items': items,
    });

    final status = (json['status']?.toString() ?? 'error').toLowerCase();
    return ClipResult(
      approved: status == 'approved' || json['ok'] == true,
      paymentId: json['payment_id']?.toString(),
      detail: json['status_detail']?.toString() ?? json['detail']?.toString(),
      errorMessage: json['message']?.toString(),
      status: status,
      threeDsUrl: json['three_ds_url']?.toString(),
    );
  }

  /// Estado de un pago de /payments (para esperar el resultado de 3DS).
  /// Devuelve 'approved', 'rejected', 'pending', etc., o null si falla.
  static Future<String?> paymentStatus({required String paymentId}) async {
    try {
      final json = await _call({
        'action': 'payment_status',
        'payment_id': paymentId,
      });
      return json['status']?.toString().toLowerCase();
    } catch (_) {
      return null;
    }
  }

  /// Crea un link de Checkout Redireccionado de Clip.
  /// Retorna { url, paymentId } o null si falla.
  static Future<ClipLinkResult?> crearLinkPago({
    required double amount,
    required String description,
    String? redirectUrl,
  }) async {
    final json = await _call({
      'action': 'create_link',
      'amount': amount,
      'description': description,
      if (redirectUrl != null) 'redirect_url': redirectUrl,
    });
    if (json['ok'] != true) return null;
    final url = json['url']?.toString() ?? '';
    final paymentId = json['payment_id']?.toString() ?? '';
    if (url.isEmpty || paymentId.isEmpty) return null;
    return ClipLinkResult(url: url, paymentId: paymentId);
  }

  /// Consulta el status actual de un payment link.
  /// Devuelve el status (CHECKOUT_CREATED, CHECKOUT_COMPLETED, etc.) o null si falla.
  static Future<String?> checkStatus({required String paymentId}) async {
    try {
      final json = await _call({
        'action': 'check_status',
        'payment_id': paymentId,
      });
      if (json['ok'] != true) return null;
      return json['status']?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Envía el ticket por email después de un pago exitoso.
  static Future<void> enviarTicket({
    required String email,
    required String paymentId,
    required double total,
    required List<Map<String, dynamic>> items,
  }) async {
    await _call({
      'action': 'ticket',
      'email': email,
      'payment_id': paymentId,
      'total': total,
      'items': items,
    });
  }
}

class ClipLinkResult {
  final String url;
  final String paymentId;
  const ClipLinkResult({required this.url, required this.paymentId});
}

class ClipResult {
  final bool approved;
  final String? paymentId;
  final String? detail;
  final String? errorMessage;
  final String? status;
  final String? threeDsUrl;

  const ClipResult({
    required this.approved,
    this.paymentId,
    this.detail,
    this.errorMessage,
    this.status,
    this.threeDsUrl,
  });
}
