import 'package:flutter_test/flutter_test.dart';
import 'package:pact/core/utils/validators.dart';

void main() {
  test('usernames match the server regex', () {
    expect(Validators.username('al'), isNotNull);
    expect(Validators.username('alex_92'), isNull);
    expect(Validators.username('alex 92'), isNotNull);
    expect(Validators.username('a' * 21), isNotNull);
  });

  test('passwords need length and a digit', () {
    expect(Validators.password('short1'), isNotNull);
    expect(Validators.password('allletters'), isNotNull);
    expect(Validators.password('goodpass1'), isNull);
  });

  test('goals are 2-40 characters', () {
    expect(Validators.goal('G'), isNotNull);
    expect(Validators.goal('Gym'), isNull);
    expect(Validators.goal('x' * 41), isNotNull);
  });
}
