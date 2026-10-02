import 'package:flutter_test/flutter_test.dart';
import 'package:hissab/core/services/google_auth_service.dart';

void main() {
  group('GoogleAuthService & CloudUser Architecture Tests', () {
    test('CloudUser equality is based on stable sub ID, not email', () {
      const user1 = CloudUser(
        id: 'google-sub-998877',
        email: 'user1@gmail.com',
        displayName: 'Account One',
      );
      const user2 = CloudUser(
        id: 'google-sub-998877',
        email: 'changed-email@gmail.com',
        displayName: 'Updated Name',
      );
      const user3 = CloudUser(
        id: 'different-sub-112233',
        email: 'user1@gmail.com',
      );

      expect(user1 == user2, isTrue, reason: 'Same stable sub ID implies same account identity');
      expect(user1 == user3, isFalse, reason: 'Different sub IDs must never be considered same account');
      expect(user1.hashCode, equals(user2.hashCode));
    });

    test('CloudUser serialization and deserialization preserves all fields', () {
      const user = CloudUser(
        id: 'sub-xyz-123456789',
        email: 'hissab.user@gmail.com',
        displayName: 'Hissab Merchant',
        photoUrl: 'https://lh3.googleusercontent.com/a/photo',
      );

      final map = user.toMap();
      final restored = CloudUser.fromMap(map);

      expect(restored.id, equals(user.id));
      expect(restored.email, equals(user.email));
      expect(restored.displayName, equals(user.displayName));
      expect(restored.photoUrl, equals(user.photoUrl));
    });

    test('MockCloudAuthService respects supportsAuthenticate configuration', () async {
      final webMock = MockCloudAuthService(supportsAuthenticate: false);
      final androidMock = MockCloudAuthService(supportsAuthenticate: true);

      expect(webMock.supportsAuthenticate, isFalse);
      expect(androidMock.supportsAuthenticate, isTrue);

      expect(await webMock.getCurrentUser(), isNull);
      final signedIn = await webMock.signIn();
      expect(signedIn?.id, equals('mock-google-sub-12345678'));

      final client = await webMock.getAuthenticatedClient(requestDriveScope: true);
      expect(client, isNotNull);

      await webMock.signOut();
      expect(await webMock.getCurrentUser(), isNull);
    });

    test('GoogleAuthService singleton instance verification', () {
      final instance1 = GoogleAuthService();
      final instance2 = GoogleAuthService();

      expect(identical(instance1, instance2), isTrue, reason: 'GoogleAuthService must be a singleton');
    });
  });
}
