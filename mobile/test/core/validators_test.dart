import 'package:biko_mobile/core/utils/phone_input_formatter.dart';
import 'package:biko_mobile/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators', () {
    test('nome exige ao menos 3 caracteres (ignorando espaços)', () {
      expect(Validators.name(null), isNotNull);
      expect(Validators.name('  ab  '), isNotNull);
      expect(Validators.name('Ana'), isNull);
    });

    test('e-mail segue a mesma regra do backend', () {
      expect(Validators.email(''), 'Informe o e-mail.');
      expect(Validators.email('maria@'), isNotNull);
      expect(Validators.email('maria@biko.c'), isNotNull);
      expect(Validators.email(' maria@biko.com '), isNull);
    });

    test('nova senha: 8+ caracteres com letras e números', () {
      expect(Validators.newPassword(''), isNotNull);
      expect(Validators.newPassword('abc123'), contains('8 caracteres'));
      expect(Validators.newPassword('abcdefgh'), contains('letras e números'));
      expect(Validators.newPassword('12345678'), contains('letras e números'));
      expect(Validators.newPassword('Senha1234'), isNull);
    });

    test('confirmação compara com a senha atual do campo', () {
      var original = 'Senha1234';
      final validate = Validators.confirmPassword(() => original);
      expect(validate('Senha1234'), isNull);
      original = 'Outra1234';
      expect(validate('Senha1234'), 'As senhas não conferem.');
      expect(validate(''), 'Confirme a senha.');
    });

    test('telefone é opcional, mas se informado precisa de DDD', () {
      expect(Validators.optionalPhone(''), isNull);
      expect(Validators.optionalPhone('(47) 9999'), isNotNull);
      expect(Validators.optionalPhone('(47) 9999-0001'), isNull);
      expect(Validators.optionalPhone('(47) 99999-0001'), isNull);
    });

    test('senha de login só precisa estar preenchida', () {
      expect(Validators.loginPassword(''), 'Informe a senha.');
      expect(Validators.loginPassword('x'), isNull);
    });
  });

  group('PhoneInputFormatter', () {
    test('formata enquanto digita', () {
      expect(PhoneInputFormatter.format(''), '');
      expect(PhoneInputFormatter.format('4'), '(4');
      expect(PhoneInputFormatter.format('47'), '(47');
      expect(PhoneInputFormatter.format('479'), '(47) 9');
      expect(PhoneInputFormatter.format('4799990'), '(47) 9999-0');
      expect(PhoneInputFormatter.format('4799990001'), '(47) 9999-0001');
      expect(PhoneInputFormatter.format('47999990001'), '(47) 99999-0001');
    });

    test('ignora letras e corta no 11º dígito', () {
      expect(PhoneInputFormatter.format('47a99999x00019999'), '(47) 99999-0001');
    });

    test('o resultado é aceito pelo validador', () {
      expect(
        Validators.optionalPhone(PhoneInputFormatter.format('47999990001')),
        isNull,
      );
    });
  });
}
