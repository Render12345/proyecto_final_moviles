import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_final_moviles/models/user_model.dart';

void main() {
  test('parses a user profile and its demo card number', () {
    final user = UserModel.fromMap('user-123', {
      'nombre': 'Ada Lovelace',
      'email': 'ada@example.com',
      'role': 'user',
      'autorizado': true,
      'card_number': '9999000000000001',
      'dispositivos_vinculados': <String, bool>{'device-1': true},
    });

    expect(user.uid, 'user-123');
    expect(user.nombre, 'Ada Lovelace');
    expect(user.role, 'user');
    expect(user.autorizado, isTrue);
    expect(user.cardNumber, '9999000000000001');
    expect(user.dispositivosVinculados, {'device-1': true});
  });

  test('round-trips the demo card number through the database map', () {
    final user = UserModel(
      uid: 'user-456',
      nombre: 'Grace Hopper',
      email: 'grace@example.com',
      fotoUrl: '',
      provider: 'password',
      role: 'user',
      autorizado: false,
      planSuscripcion: 'ninguno',
      dispositivosVinculados: const {},
      cardNumber: '9999000000000002',
    );

    final restored = UserModel.fromMap(user.uid, user.toMap());

    expect(restored.cardNumber, user.cardNumber);
    expect(restored.autorizado, isFalse);
  });
}
