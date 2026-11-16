import 'package:biko_mobile/data/models/auth_result.dart';
import 'package:biko_mobile/data/models/user_model.dart';
import 'package:biko_mobile/data/models/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  group('UserModel', () {
    test('fromJson lê o formato do backend (data SQLite em UTC)', () {
      final user = UserModel.fromJson(userJson(role: 'prestador'));
      expect(user.id, 2);
      expect(user.role, UserRole.prestador);
      expect(user.active, isTrue);
      expect(user.createdAt, DateTime.utc(2026, 11, 16, 19, 42));
      expect(user.photoUrl, isNull);
    });

    test('aceita telefone nulo', () {
      expect(UserModel.fromJson(userJson(phone: null)).phone, isNull);
    });

    test('perfil desconhecido ou campo com tipo errado -> FormatException', () {
      expect(
        () => UserModel.fromJson(userJson(role: 'chefe')),
        throwsFormatException,
      );
      expect(
        () => UserModel.fromJson({...userJson(), 'id': 'dois'}),
        throwsFormatException,
      );
      expect(
        () => UserModel.fromJson({...userJson()}..remove('email')),
        throwsFormatException,
      );
    });

    test('toJson -> fromJson preserva os dados', () {
      final user = UserModel.fromJson(userJson());
      final copy = UserModel.fromJson(user.toJson());
      expect(copy.toJson(), user.toJson());
    });

    test('toMap usa tipos do SQLite e fromMap volta ao mesmo usuário', () {
      final user = UserModel.fromJson(userJson(active: false));
      final map = user.toMap();
      expect(map['active'], 0);
      expect(map['created_at'], isA<int>());
      expect(UserModel.fromMap(map).toJson(), user.toJson());
    });

    test('primeiro nome e iniciais', () {
      final user = UserModel.fromJson(userJson(name: '  maria   da silva '));
      expect(user.firstName, 'maria');
      expect(user.initials, 'MD');
    });
  });

  group('AuthResult', () {
    test('lê token Bearer, usuário e validade', () {
      final result = AuthResult.fromJson({
        'user': userJson(),
        'token': validToken,
        'token_type': 'Bearer',
        'expires_at': 1900000000000,
      });
      expect(result.token, validToken);
      expect(result.user.email, 'cliente@biko.com');
      expect(result.expiresAt.isUtc, isTrue);
    });

    test('resposta sem token (login no modo web) -> FormatException', () {
      expect(
        () => AuthResult.fromJson({'user': userJson()}),
        throwsFormatException,
      );
    });
  });
}
