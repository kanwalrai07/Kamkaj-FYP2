import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadCNIC({
    required String userId,
    required File file,
    required bool isFront,
  }) async {
    try {
      final fileName = isFront ? 'cnic_front.jpg' : 'cnic_back.jpg';
      final ref = _storage.ref().child('users/$userId/cnic/$fileName');

      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      if (e.toString().contains('object-not-found')) {
        throw Exception('Storage initialization error: The Firebase Storage bucket might not be initialized or rules are misconfigured.');
      }
      rethrow;
    }
  }

  Future<String> uploadProfileImage({
    required String userId,
    required File file,
  }) async {
    try {
      final ref = _storage.ref().child('users/$userId/profile.jpg');
      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      if (e.toString().contains('object-not-found')) {
        throw Exception('Storage initialization error: The Firebase Storage bucket might not be initialized or rules are misconfigured.');
      }
      rethrow;
    }
  }

  Future<String> uploadPortfolioImage({
    required String userId,
    required File file,
  }) async {
    try {
      final fileName = 'portfolio_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('users/$userId/portfolio/$fileName');
      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      rethrow;
    }
  }
}
