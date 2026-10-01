import 'package:flutter_test/flutter_test.dart';
import 'package:memochat/core/security/firestore_authorization.dart';

void main() {
  test('ownership policy compares the authenticated uid exactly', () {
    expect(FirestoreAuthorization.ownsForUid('alice', 'alice'), isTrue);
    expect(FirestoreAuthorization.ownsForUid('alice', 'bob'), isFalse);
  });

  test('participant policy accepts both participant field contracts', () {
    expect(
      FirestoreAuthorization.participantForUid(
        'alice',
        {'participants': ['alice', 'bob']},
      ),
      isTrue,
    );
    expect(
      FirestoreAuthorization.participantForUid(
        'bob',
        {'participantIds': ['alice', 'bob']},
      ),
      isTrue,
    );
    expect(
      FirestoreAuthorization.participantForUid(
        'mallory',
        {'participants': ['alice', 'bob']},
      ),
      isFalse,
    );
  });

  test('participant policy safely handles missing fields', () {
    expect(
      FirestoreAuthorization.participantForUid('alice', const {}),
      isFalse,
    );
  });
}
