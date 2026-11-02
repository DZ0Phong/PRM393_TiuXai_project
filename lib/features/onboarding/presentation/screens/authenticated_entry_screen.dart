import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../splash/presentation/screens/splash_screen.dart';
import 'onboarding_screen.dart';

/// Shows onboarding once per account, then runs the splash before entering the lobby.
class AuthenticatedEntryScreen extends StatefulWidget {
  final User user;
  final WidgetBuilder lobbyBuilder;
  final WidgetBuilder adminBuilder;

  const AuthenticatedEntryScreen({
    super.key,
    required this.user,
    required this.lobbyBuilder,
    required this.adminBuilder,
  });

  @override
  State<AuthenticatedEntryScreen> createState() =>
      _AuthenticatedEntryScreenState();
}

class _AuthenticatedEntryScreenState extends State<AuthenticatedEntryScreen> {
  late final Future<bool> _seenOnboarding = _readSeenState();
  late Future<bool> _adminStatus = _readAdminStatus();
  bool _finishedOnboarding = false;
  bool _showSplash = false;

  String get _preferenceKey => 'onboarding_seen_${widget.user.uid}';

  Future<bool> _readSeenState() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_preferenceKey) ?? false;
  }

  Future<bool> _readAdminStatus() async {
    // Reuse Firebase Auth's current token on app startup. Forcing a network
    // refresh here can fail while the local Auth Emulator is still starting.
    // Admin claim changes take effect after the user signs in again.
    final token = await widget.user.getIdTokenResult();
    return token.claims?['admin'] == true;
  }

  Future<void> _saveSeenState() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_preferenceKey, true);
    } catch (_) {
      // Keep the current login flow usable if local preferences are unavailable.
    }
  }

  Future<void> _start() async {
    await _saveSeenState();
    if (!mounted) return;
    setState(() {
      _finishedOnboarding = true;
      _showSplash = true;
    });
  }

  Future<void> _skip() async {
    await _saveSeenState();
    if (!mounted) return;
    setState(() {
      _finishedOnboarding = true;
      _showSplash = false;
    });
  }

  void _finishSplash() {
    if (mounted) setState(() => _showSplash = false);
  }

  Widget _destination() => FutureBuilder<bool>(
    future: _adminStatus,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        final error = snapshot.error;
        final authCode = error is FirebaseAuthException ? error.code : null;
        final sessionExpired = authCode == 'user-not-found' ||
            authCode == 'user-token-expired' ||
            authCode == 'invalid-user-token';
        return Scaffold(
          backgroundColor: const Color(0xff10131a),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Không xác minh được quyền truy cập.',
                    style: TextStyle(color: Color(0xffe1e2eb)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    sessionExpired
                        ? 'Phiên đăng nhập Emulator đã hết hiệu lực. Hãy đăng nhập lại.'
                        : authCode == null
                        ? 'Kiểm tra Auth Emulator đang chạy, rồi thử lại.'
                        : 'Firebase Auth báo lỗi: $authCode',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xff9ba3b3),
                      fontSize: 12,
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _adminStatus = _readAdminStatus()),
                    child: const Text('Thử lại'),
                  ),
                  TextButton.icon(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Đăng nhập lại'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Scaffold(
          backgroundColor: Color(0xff10131a),
          body: Center(
            child: CircularProgressIndicator(color: Color(0xffffc174)),
          ),
        );
      }
      return snapshot.data!
          ? widget.adminBuilder(context)
          : widget.lobbyBuilder(context);
    },
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _seenOnboarding,
    builder: (context, snapshot) {
      if (_showSplash) return SplashScreen(onFinished: _finishSplash);
      if (_finishedOnboarding || snapshot.data == true) return _destination();
      if (!snapshot.hasData && !snapshot.hasError) {
        return const Scaffold(
          backgroundColor: Color(0xff10131a),
          body: Center(
            child: CircularProgressIndicator(color: Color(0xffffc174)),
          ),
        );
      }
      return OnboardingScreen(
        user: widget.user,
        onStart: _start,
        onSkip: _skip,
      );
    },
  );
}
