import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/routing/router.dart';

void main() {
  test('signed out anywhere -> signin', () {
    expect(authRedirect(signedIn: false, ageVerified: false, location: '/'), '/auth/signin');
  });
  test('signed in, not verified -> age gate', () {
    expect(authRedirect(signedIn: true, ageVerified: false, location: '/'), '/onboarding/age');
  });
  test('signed in + verified on signin -> home', () {
    expect(authRedirect(signedIn: true, ageVerified: true, location: '/auth/signin'), '/');
  });
  test('signed in + verified on home -> stay', () {
    expect(authRedirect(signedIn: true, ageVerified: true, location: '/'), null);
  });
}
