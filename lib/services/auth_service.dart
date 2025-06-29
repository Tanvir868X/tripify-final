import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
    clientId: '259390620824-fl4jku803h0u5uqfsmomtp5qf49j4f8q.apps.googleusercontent.com',
  );

  // Phone number verification
  static Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(String) onError,
    required Function(PhoneAuthCredential) onVerificationCompleted,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onVerificationCompleted,
      verificationFailed: (FirebaseAuthException e) {
        String errorMessage = 'Verification failed';
        switch (e.code) {
          case 'invalid-phone-number':
            errorMessage = 'Invalid phone number format';
            break;
          case 'too-many-requests':
            errorMessage = 'Too many requests. Please try again later';
            break;
          case 'quota-exceeded':
            errorMessage = 'SMS quota exceeded. Please try again later';
            break;
          default:
            errorMessage = e.message ?? 'Verification failed';
        }
        onError(errorMessage);
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // Handle timeout if needed
      },
      timeout: const Duration(seconds: 60),
    );
  }

  // Sign in with phone number and verification code
  static Future<UserCredential?> signInWithPhoneNumber({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      // Save user data to SharedPreferences
      if (userCredential.user != null) {
        await _saveUserData(userCredential.user!);
        print('Successfully signed in with phone: ${userCredential.user!.phoneNumber}');
      }
      
      return userCredential;
    } catch (error) {
      print('Phone Sign-In Error: $error');
      return null;
    }
  }

  static Future<UserCredential?> signInWithGoogle() async {
    try {
      // Check if running on web
      if (kIsWeb) {
        print('Google Sign-In on Web - using signInSilently for better compatibility');
        // For web, try to sign in silently first
        try {
          final GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
          if (googleUser != null) {
            return await _handleGoogleSignInResult(googleUser);
          }
        } catch (e) {
          print('Silent sign-in failed, trying regular sign-in: $e');
        }
      }

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print('User cancelled Google Sign-In');
        return null;
      }

      return await _handleGoogleSignInResult(googleUser);
    } catch (error) {
      print('Firebase Google Sign-In Error: $error');
      
      // Provide more specific error messages
      if (error.toString().contains('invalid_client')) {
        print('Client ID issue detected. Please check Firebase Console for correct Web Client ID.');
      } else if (error.toString().contains('popup_closed')) {
        print('Sign-in popup was closed by user');
      }
      
      return null;
    }
  }

  static Future<UserCredential?> _handleGoogleSignInResult(GoogleSignInAccount googleUser) async {
    try {
      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the credential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      // Save user data to SharedPreferences
      if (userCredential.user != null) {
        await _saveUserData(userCredential.user!);
        print('Successfully signed in: ${userCredential.user!.email}');
      }
      
      return userCredential;
    } catch (error) {
      print('Error handling Google sign-in result: $error');
      return null;
    }
  }

  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      await _clearUserData();
      print('Successfully signed out');
    } catch (error) {
      print('Sign Out Error: $error');
    }
  }

  static Future<bool> isSignedIn() async {
    try {
      return _auth.currentUser != null;
    } catch (error) {
      return false;
    }
  }

  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  static Stream<User?> get authStateChanges {
    return _auth.authStateChanges();
  }

  static Future<void> _saveUserData(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', user.uid);
    await prefs.setString('user_email', user.email ?? '');
    await prefs.setString('user_name', user.displayName ?? '');
    await prefs.setString('user_photo', user.photoURL ?? '');
    await prefs.setString('user_phone', user.phoneNumber ?? '');
    await prefs.setBool('is_signed_in', true);
  }

  static Future<void> _clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('user_name');
    await prefs.remove('user_photo');
    await prefs.remove('user_phone');
    await prefs.setBool('is_signed_in', false);
  }

  static Future<Map<String, String?>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'id': prefs.getString('user_id'),
      'email': prefs.getString('user_email'),
      'name': prefs.getString('user_name'),
      'photo': prefs.getString('user_photo'),
      'phone': prefs.getString('user_phone'),
    };
  }

  static Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user != null) {
        await _saveUserData(userCredential.user!);
        print('Successfully signed up: \\${userCredential.user!.email}');
      }
      return userCredential;
    } catch (error) {
      print('Email Sign-Up Error: $error');
      rethrow;
    }
  }

  static Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user != null) {
        await _saveUserData(userCredential.user!);
        print('Successfully signed in: \\${userCredential.user!.email}');
      }
      return userCredential;
    } catch (error) {
      print('Email Sign-In Error: $error');
      rethrow;
    }
  }
} 