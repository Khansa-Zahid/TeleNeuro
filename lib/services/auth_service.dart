import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sign up with email and password
  Future<User?> signUp(String email, String password) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        throw Exception("Email and password must not be empty");
      }

      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }

      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        print("Password is too weak.");
      } else if (e.code == 'email-already-in-use') {
        print("Email is already in use.");
      } else {
        print("Error: ${e.message}");
      }
      return null;
    }
  }

  // Login with email and password
  Future<User?> login(String email, String password) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        throw Exception("Email and password must not be empty");
      }

      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        print("No user found with this email.");
      } else if (e.code == 'wrong-password') {
        print("Incorrect password.");
      } else {
        print("Error: ${e.message}");
      }
      return null;
    }
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    if (email.isEmpty) {
      throw Exception("Email must not be empty");
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      print("Error sending password reset email: ${e.message}");
      throw e;
    }
  }

  // Check user authentication status
  Stream<User?> get user => _auth.authStateChanges();

  // Get the current user
  User? get currentUser => _auth.currentUser;
}
