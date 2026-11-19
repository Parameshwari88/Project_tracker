import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

/// drive.file only lets the app touch files it created itself.
const kScopes = <String>[
  'https://www.googleapis.com/auth/drive.file',
];

/// Web OAuth client ID from Google Cloud (see docs/google-setup.md).
/// Pass with: --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com
const kServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

class _AuthClient extends http.BaseClient {
  _AuthClient(this._token);
  final String _token;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _inner.send(request);
  }
}

class GoogleAuthService {
  bool _initialised = false;
  GoogleSignInAccount? _account;

  GoogleSignInAccount? get account => _account;

  Future<void> _init() async {
    if (_initialised) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: kServerClientId.isEmpty ? null : kServerClientId,
    );
    _initialised = true;
  }

  /// Silent sign-in on app start. Returns null if the user must sign in.
  Future<GoogleSignInAccount?> tryRestore() async {
    await _init();
    final result = GoogleSignIn.instance.attemptLightweightAuthentication();
    _account = await Future.value(result);
    return _account;
  }

  Future<GoogleSignInAccount> signIn() async {
    await _init();
    _account = await GoogleSignIn.instance.authenticate(scopeHint: kScopes);
    return _account!;
  }

  Future<void> signOut() async {
    await _init();
    await GoogleSignIn.instance.signOut();
    _account = null;
  }

  /// Authenticated HTTP client for Google APIs.
  Future<http.Client> client() async {
    final acc = _account;
    if (acc == null) throw StateError('Not signed in');
    final authz = await acc.authorizationClient.authorizationForScopes(kScopes) ??
        await acc.authorizationClient.authorizeScopes(kScopes);
    return _AuthClient(authz.accessToken);
  }
}
