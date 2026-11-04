import 'package:cloud_functions/cloud_functions.dart';

// Optional HTTPS backend; otherwise call deployed Firebase Functions.
const backendUrl = String.fromEnvironment('BACKEND_URL');

String? backendConfigurationError(bool emulator, String url) {
  if (emulator) {
    return url.isEmpty ? null : 'BACKEND_URL chỉ dùng với Firebase thật.';
  }
  if (url.isEmpty) return 'Bản online cần BACKEND_URL HTTPS; Spark không có Cloud Functions.';
  final endpoint = Uri.tryParse(url);
  if (endpoint == null ||
      endpoint.scheme != 'https' ||
      endpoint.host.isEmpty ||
      endpoint.host == 'localhost' ||
      endpoint.host == '127.0.0.1' ||
      endpoint.userInfo.isNotEmpty ||
      endpoint.hasPort ||
      endpoint.hasQuery ||
      endpoint.hasFragment ||
      endpoint.path.isNotEmpty) {
    return 'BACKEND_URL phải là HTTPS origin của backend, không có port/path/query.';
  }
  return null;
}

extension GameCallable on FirebaseFunctions {
  HttpsCallable gameCallable(String name, {HttpsCallableOptions? options}) {
    if (backendUrl.isEmpty) return httpsCallable(name, options: options);
    return httpsCallableFromUrl('$backendUrl/api/$name', options: options);
  }
}
