import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/routing/router.dart';

void main() {
  test('signed out anywhere -> signin', () {
    expect(
      authRedirect(
        signedIn: false,
        ageVerified: false,
        profileComplete: false,
        location: '/',
      ),
      '/auth/signin',
    );
  });
  test('signed in, not verified -> age gate', () {
    expect(
      authRedirect(
        signedIn: true,
        ageVerified: false,
        profileComplete: false,
        location: '/',
      ),
      '/onboarding/age',
    );
  });
  test('signed in + verified on signin -> home', () {
    expect(
      authRedirect(
        signedIn: true,
        ageVerified: true,
        profileComplete: true,
        location: '/auth/signin',
      ),
      '/discover',
    );
  });
  test('signed in + verified on home -> stay', () {
    expect(
      authRedirect(
        signedIn: true,
        ageVerified: true,
        profileComplete: true,
        location: '/discover',
      ),
      null,
    );
  });
  test('signed out on phone verify -> stay (mid phone sign-in)', () {
    expect(
      authRedirect(
        signedIn: false,
        ageVerified: false,
        profileComplete: false,
        location: '/auth/phone',
      ),
      null,
    );
  });
  test('signed in + verified on phone verify -> home', () {
    expect(
      authRedirect(
        signedIn: true,
        ageVerified: true,
        profileComplete: true,
        location: '/auth/phone',
      ),
      '/discover',
    );
  });
  test('age-verified, profile incomplete -> profile setup', () {
    expect(
      authRedirect(
        signedIn: true,
        ageVerified: true,
        profileComplete: false,
        location: '/',
      ),
      '/onboarding/profile',
    );
  });
  test('already on profile setup -> stay', () {
    expect(
      authRedirect(
        signedIn: true,
        ageVerified: true,
        profileComplete: false,
        location: '/onboarding/profile',
      ),
      null,
    );
  });
  test('complete on profile setup -> home', () {
    expect(
      authRedirect(
        signedIn: true,
        ageVerified: true,
        profileComplete: true,
        location: '/onboarding/profile',
      ),
      '/discover',
    );
  });
  test('complete on home -> stay', () {
    expect(
      authRedirect(
        signedIn: true,
        ageVerified: true,
        profileComplete: true,
        location: '/discover',
      ),
      null,
    );
  });
}
