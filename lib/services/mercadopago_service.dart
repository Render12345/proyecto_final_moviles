// pubspec.yaml -> dependencies:  http: ^1.2.0
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/mercadopago_config.dart';

class PreferenciaMp {
  final String id;
  final String initPoint;
  PreferenciaMp(this.id, this.initPoint);
}

class MercadoPagoService {
  static const _base = 'https://api.mercadopago.com';

  static Map<String, String> get _headers => {
        'Authorization': 'Bearer ${MercadoPagoConfig.accessToken}',
        'Content-Type': 'application/json',
      };

  /// Crea la preferencia de pago (Checkout Pro).
  static Future<PreferenciaMp> crearPreferencia({
    required String plan,
    required String titulo,
    required int importe,
    required String externalReference,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/checkout/preferences'),
      headers: _headers,
      body: jsonEncode({
        'items': [
          {
            'id': plan,
            'title': titulo,
            'quantity': 1,
            'unit_price': importe,
            'currency_id': 'MXN',
          },
        ],
        'external_reference': externalReference,
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('MercadoPago (${res.statusCode}): ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final url = data['init_point'];

    return PreferenciaMp(data['id'] as String, url as String);
  }

  /// Busca el pago asociado a nuestra referencia. Devuelve null si aún no hay
  /// ninguno. Si hay varios intentos, prefiere el aprobado.
  static Future<Map<String, dynamic>?> buscarPago(
    String externalReference,
  ) async {
    final uri = Uri.parse('$_base/v1/payments/search').replace(
      queryParameters: {
        'external_reference': externalReference,
        'sort': 'date_created',
        'criteria': 'desc',
      },
    );

    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) {
      throw Exception('MercadoPago (${res.statusCode}): ${res.body}');
    }

    final results =
        ((jsonDecode(res.body) as Map<String, dynamic>)['results'] as List?) ??
            [];
    if (results.isEmpty) return null;

    final pagos = results.cast<Map<String, dynamic>>();
    return pagos.firstWhere(
      (p) => p['status'] == 'approved',
      orElse: () => pagos.first,
    );
  }
}