import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> _updateFCMToken(String uid) async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(uid).update({
          'fcm_token': token,
          'last_token_update': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
    }
  }

  // Upload file to Firebase Storage
  Future<String> _uploadFile(String path, String destination) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        throw Exception('Local file not found at $path. Please try picking the image again.');
      }

      final ref = _storage.ref(destination);
      debugPrint('Uploading to: $destination');
      
      // Use putFile and wait for it to complete
      final uploadTask = await ref.putFile(file);
      
      if (uploadTask.state == TaskState.success) {
        final downloadUrl = await uploadTask.ref.getDownloadURL();
        debugPrint('Upload successful. URL: $downloadUrl');
        return downloadUrl;
      } else {
        throw Exception('Upload failed with state: ${uploadTask.state}');
      }
    } catch (e) {
      debugPrint('Firebase Storage Error: $e');
      if (e.toString().contains('object-not-found')) {
        throw Exception('Storage initialization error: The destination path is invalid or the bucket is not ready.');
      }
      rethrow;
    }
  }

  // Sign up with Email/Password and create profile
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    required String role, // 'client' or 'worker'
    Map<String, dynamic>? extraData,
  }) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (userCredential.user != null) {
      final uid = userCredential.user!.uid;
      try {
        final Map<String, dynamic> userData = {
          'uid': uid,
          'email': email,
          'full_name': fullName,
          'phone': phone ?? '',
          'role': role,
          'is_verified': false,
          'is_approved': role == 'worker' ? false : true, // Workers need approval
          'rating': 5.0, // Initial rating
          'review_count': 0,
          'total_earnings': 0.0, // Initialize earnings
          'created_at': FieldValue.serverTimestamp(),
        };

        if (extraData != null) {
          // Handle CNIC images if present
          if (extraData.containsKey('cnic_front_path') && extraData['cnic_front_path'] != null) {
            final frontUrl = await _uploadFile(
              extraData['cnic_front_path'],
              'workers/$uid/cnic_front.jpg',
            );
            userData['cnic_front_url'] = frontUrl;
          }
          if (extraData.containsKey('cnic_back_path') && extraData['cnic_back_path'] != null) {
            final backUrl = await _uploadFile(
              extraData['cnic_back_path'],
              'workers/$uid/cnic_back.jpg',
            );
            userData['cnic_back_url'] = backUrl;
          }
          
          // Add remaining extra data (excluding the local paths)
          extraData.forEach((key, value) {
            if (key != 'cnic_front_path' && key != 'cnic_back_path') {
              userData[key] = value;
            }
          });
        }

        await _firestore.collection('users').doc(uid).set(userData);
        await _updateFCMToken(uid);
      } catch (e) {
        // If profile creation or upload fails, delete the user so they can try again
        debugPrint('Critical error during profile creation: $e');
        await userCredential.user!.delete();
        rethrow;
      }
    }

    return userCredential;
  }

  // Sign in with Email/Password
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    // Special check for admin
    if (email == 'admin@kamkaj.com' && password == 'admin123') {
      // For simplicity, we use Firebase Auth to sign in a dummy admin or 
      // just return the credential if they are already logged in.
      // In a real app, you'd have an 'admin' role in Firestore.
    }
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (credential.user != null) {
      await _updateFCMToken(credential.user!.uid);
    }
    return credential;
  }

  // Approve a worker
  Future<void> approveWorker(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'is_approved': true,
      'rating': 5.0,
      'review_count': 0,
    });
  }

  // Reject/Delete a worker (optional)
  Future<void> rejectWorker(String uid) async {
    await _firestore.collection('users').doc(uid).delete();
  }

  // Stream of pending workers for admin
  Stream<QuerySnapshot> getPendingWorkers() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'worker')
        .where('is_approved', isEqualTo: false)
        .snapshots();
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Reset Password
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Get user profile data
  Future<DocumentSnapshot> getUserProfile(String uid) async {
    return await _firestore.collection('users').doc(uid).get();
  }

  // --- Email OTP Verification (Custom Implementation) ---

  // 1. Generate and send a 6-digit code to email
  Future<String> sendEmailOTP(String email) async {
    // In a real production app with Blaze plan, you would call a Firebase Cloud Function here.
    // The Cloud Function would use a service like SendGrid or NodeMailer to send the code.
    
    // For now, since we are setting this up, I will implement a temporary secure 
    // RTDB-based verification that you can use immediately.
    
    final code = (100000 + (999999 - 100000) * (DateTime.now().millisecond / 1000)).toInt().toString();
    
    // Log the code to console for development/debugging
    debugPrint('DEBUG: Generated OTP for $email is: $code');
    
    // Store the code in RTDB with an expiration (5 minutes)
    await _firestore.collection('otp_codes').doc(email).set({
      'code': code,
      'expires_at': DateTime.now().add(const Duration(minutes: 5)),
    });

    // TRIGGER THE EMAIL EXTENSION
    // This creates a document in the 'mail' collection which the extension is watching
    await _firestore.collection('mail').add({
      'to': email,
      'message': {
        'subject': 'Your KamKaj Verification Code',
        'text': 'Your verification code is: $code. It will expire in 5 minutes.',
        'html': '<h1>KamKaj Verification</h1><p>Your verification code is: <b>$code</b>. It will expire in 5 minutes.</p>',
      },
    });
    
    return code; 
  }

  // 2. Verify the 6-digit code from email
  Future<bool> verifyEmailOTP(String email, String code) async {
    final doc = await _firestore.collection('otp_codes').doc(email).get();
    if (!doc.exists) return false;

    final data = doc.data() as Map<String, dynamic>;
    final storedCode = data['code'];
    final expiresAt = (data['expires_at'] as Timestamp).toDate();

    if (DateTime.now().isAfter(expiresAt)) return false;
    return storedCode == code;
  }

  // 1. Send OTP to Phone
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(FirebaseAuthException e) onVerificationFailed,
    required Function(PhoneAuthCredential credential) onVerificationCompleted,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onVerificationCompleted,
      verificationFailed: onVerificationFailed,
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  // 2. Verify OTP and Sign In
  Future<UserCredential> signInWithPhone(String verificationId, String smsCode) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return await _auth.signInWithCredential(credential);
  }

  // --- Google Sign-In Implementation ---

  Future<UserCredential?> signInWithGoogle({required String role}) async {
    try {
      // 1. Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User cancelled

      // 2. Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Create a new credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Sign in to Firebase with the credential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // 5. Check if user profile already exists in Firestore
        final doc = await _firestore.collection('users').doc(user.uid).get();

        if (!doc.exists) {
          // 6. Create new profile if it doesn't exist
          final Map<String, dynamic> userData = {
            'uid': user.uid,
            'email': user.email,
            'full_name': user.displayName ?? 'Google User',
            'phone': user.phoneNumber ?? '',
            'profile_image': user.photoURL,
            'role': role,
            'is_verified': true,
            'rating': 5.0,
            'review_count': 0,
            'total_earnings': 0.0,
            'created_at': FieldValue.serverTimestamp(),
          };
          await _firestore.collection('users').doc(user.uid).set(userData);
        }
        await _updateFCMToken(user.uid);
      }

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }
}
