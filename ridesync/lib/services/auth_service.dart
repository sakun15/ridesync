import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Wraps Firebase Auth. Screens and providers talk to this — never to
/// FirebaseAuth directly. Keeps the SDK swappable and error handling in one place.
class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Creates the auth account, then the matching Firestore user document.
  ///
  /// The Firestore write is deliberately not awaited inside a transaction with
  /// the auth call — Firebase Auth account creation can't be rolled back. If the
  /// document write fails, the account still exists; we handle that by creating
  /// the document lazily on next sign-in if missing.
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    await credential.user?.updateDisplayName(displayName.trim());
    await _createUserDocument(credential.user!, displayName.trim());

    return credential;
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // Self-heal: if signup succeeded but the document write didn't, create it now.
    await _ensureUserDocument(credential.user!);

    return credential;
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> _createUserDocument(User user, String displayName) async {
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'displayName': displayName,
      'photoUrl': null,
      'phoneNumber': null,
      'fcmToken': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _ensureUserDocument(User user) async {
    final doc = _firestore.collection('users').doc(user.uid);
    final snapshot = await doc.get();
    if (!snapshot.exists) {
      await _createUserDocument(user, user.displayName ?? 'Rider');
    }
  }

  /// Maps Firebase error codes to messages a person can act on.
  String mapAuthError(Object error) {
    if (error is! FirebaseAuthException) {
      return 'Something went wrong. Try again.';
    }

    switch (error.code) {
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a moment and try again.';
      case 'network-request-failed':
        return 'No connection. Check your network and try again.';
      default:
        return 'Something went wrong. Try again.';
    }
  }
}