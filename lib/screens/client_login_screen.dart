import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'client_welcome_screen.dart';

class ClientLoginScreen extends StatefulWidget {
  const ClientLoginScreen({super.key});

  @override
  State<ClientLoginScreen> createState() => _ClientLoginScreenState();
}

class _ClientLoginScreenState extends State<ClientLoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true; // Toggle for password visibility

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 🔹 Sign in with Firebase Authentication
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final User? user = userCredential.user;
      if (user != null) {
        // 🔹 Check if user exists in Firestore's "clients" collection
        DocumentSnapshot clientDoc =
            await _firestore.collection('clients').doc(user.uid).get();

        if (clientDoc.exists) {
          // ✅ User exists in Firestore -> Navigate to Welcome Screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => WelcomeScreen(
                patientName: clientDoc['name'] ?? 'Patient',
                patientId: user.uid,
              ),
            ),
          );
        } else {
          await _auth.signOut(); // Log them out immediately
          _showSnackbar('Error: You are not registered as a client.');
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred. Please try again.';
      if (e.code == 'user-not-found') {
        message = 'No user found for this email.';
      } else if (e.code == 'wrong-password') {
        message = 'Incorrect password.';
      }
      _showSnackbar(message);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _forgotPassword() async {
    // Show a dialog to get the user's email
    final TextEditingController emailController = TextEditingController();
    emailController.text =
        _emailController.text; // Pre-fill with current email if available

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your email address and we\'ll send you a link to reset your password.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'Enter your email',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              if (emailController.text.trim().isEmpty) {
                _showSnackbar('Please enter your email address');
                return;
              }

              try {
                setState(() {
                  _isLoading = true;
                });

                await _auth.sendPasswordResetEmail(
                  email: emailController.text.trim(),
                );

                _showSnackbar('Password reset link sent to your email');
              } on FirebaseAuthException catch (e) {
                String message = 'Failed to send password reset email';
                if (e.code == 'user-not-found') {
                  message = 'No user found with this email address';
                } else if (e.code == 'invalid-email') {
                  message = 'Invalid email address';
                }
                _showSnackbar(message);
              } finally {
                setState(() {
                  _isLoading = false;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal[700],
            ),
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal[600],
        title: const Text('Patient Login'),
        centerTitle: true,
        elevation: 4,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon at the top
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.teal[200],
                child: const Icon(Icons.lock, size: 50, color: Colors.teal),
              ),
              const SizedBox(height: 20),

              // Email Input Field
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Password Input Field
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Forgot Password?
              TextButton(
                onPressed: _forgotPassword,
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(color: Colors.teal, fontSize: 16),
                ),
              ),
              const SizedBox(height: 10),

              // Login Button
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[700],
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        'Login',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
