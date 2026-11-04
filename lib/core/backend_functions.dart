import 'package:cloud_functions/cloud_functions.dart';

// Use real Firebase Auth/Firestore, but call the group's private HTTPS backend.
const backendUrl = String.fromEnvironment('BACKEND_URL');

extension GameCallable on FirebaseFunctions {
  HttpsCallable gameCallable(String name, {HttpsCallableOptions? options}) {
    if (backendUrl.isEmpty) return httpsCallable(name, options: options);
    return httpsCallableFromUrl('$backendUrl/api/$name', options: options);
  }
}
