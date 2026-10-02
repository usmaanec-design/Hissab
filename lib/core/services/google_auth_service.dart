import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';


/// Stable user identity representation.
/// Primary unique identity is [id] (Google 'sub'), NOT email.
class CloudUser {
  final String id; // Stable Google sub / account ID
  final String email;
  final String? displayName;
  final String? photoUrl;

  const CloudUser({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
      };

  factory CloudUser.fromMap(Map<String, dynamic> map) => CloudUser(
        id: map['id'] as String,
        email: map['email'] as String,
        displayName: map['displayName'] as String?,
        photoUrl: map['photoUrl'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CloudUser &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CloudUser(id: $id, email: $email, name: $displayName)';
}

/// Abstract authentication service interface for cross-platform support (Android, iOS, Web, Test)
abstract class ICloudAuthService {
  Future<CloudUser?> getCurrentUser();
  Future<CloudUser?> signIn();
  Future<CloudUser?> signInSilently();
  Future<void> signOut();
  Future<void> disconnect();
  Future<http.Client?> getAuthenticatedClient({bool requestDriveScope = true});
  Stream<CloudUser?> get authStateChanges;
  bool get supportsAuthenticate;
  bool get isSigningIn;
}

/// Production Google Sign-In service implementation using current GoogleSignIn 7.x package APIs.
/// Fully platform-aware for Web (Google Identity Services) and Android/iOS.
class GoogleAuthService implements ICloudAuthService {
  static const List<String> driveScopes = [
    'https://www.googleapis.com/auth/drive.file',
  ];

  static const List<String> basicScopes = [
    'email',
    'profile',
    'openid',
  ];

  // Singleton instance
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;

  GoogleAuthService._internal() {
    _initListener();
  }

  final StreamController<CloudUser?> _authController = StreamController<CloudUser?>.broadcast();
  CloudUser? _currentUser;
  GoogleSignInAccount? _currentAccount;

  static bool _isInitialized = false;
  static Completer<void>? _initCompleter;
  Completer<CloudUser?>? _signInCompleter;

  // Web OAuth Client ID - configured from Google Cloud
  static const String defaultWebClientId =
      '789722583176-81gt15ltbeehqfcah7pdmb5b7p3o47r5.apps.googleusercontent.com';
  static String? webClientId = defaultWebClientId;

  @override
  bool get supportsAuthenticate {
    if (kIsWeb) return false;
    try {
      return GoogleSignIn.instance.supportsAuthenticate();
    } catch (_) {
      return false;
    }
  }

  @override
  bool get isSigningIn => _signInCompleter != null && !_signInCompleter!.isCompleted;

  void _initListener() {
    try {
      GoogleSignIn.instance.authenticationEvents.listen(
        (event) {
          if (event is GoogleSignInAuthenticationEventSignIn) {
            _currentAccount = event.user;
            _currentUser = _mapAccount(event.user);
            _savePersistedUser(_currentUser!);
            _authController.add(_currentUser);
            if (_signInCompleter != null && !_signInCompleter!.isCompleted) {
              _signInCompleter!.complete(_currentUser);
            }
          } else if (event is GoogleSignInAuthenticationEventSignOut) {
            _currentAccount = null;
            _currentUser = null;
            _clearPersistedUser();
            _authController.add(null);
          }
        },
        onError: (error) {
          debugPrint('GoogleSignIn.authenticationEvents error: $error');
          if (_signInCompleter != null && !_signInCompleter!.isCompleted) {
            _signInCompleter!.complete(null);
          }
        },
      );
    } catch (e) {
      debugPrint('Failed to attach GoogleSignIn listener: $e');
    }
  }

  /// Initialize GoogleSignIn exactly once across the entire application.
  Future<void> ensureInitialized({String? clientId}) async {
    if (_isInitialized) return;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<void>();
    try {
      final effectiveClientId = clientId ?? webClientId ?? defaultWebClientId;
      if (kIsWeb && effectiveClientId.isNotEmpty) {
        await GoogleSignIn.instance.initialize(
          clientId: effectiveClientId,
        );
      } else {
        await GoogleSignIn.instance.initialize(
          serverClientId: effectiveClientId,
        );
      }
      _isInitialized = true;
      _initCompleter!.complete();
    } catch (e) {
      debugPrint('GoogleSignIn.instance.initialize error: $e');
      _initCompleter!.complete();
    }
  }

  CloudUser _mapAccount(GoogleSignInAccount account) {
    return CloudUser(
      id: account.id, // Stable Google account sub identifier
      email: account.email,
      displayName: account.displayName,
      photoUrl: account.photoUrl,
    );
  }

  @override
  Stream<CloudUser?> get authStateChanges => _authController.stream;

  static const String _prefUserId = 'google_user_id';
  static const String _prefUserEmail = 'google_user_email';
  static const String _prefUserName = 'google_user_name';
  static const String _prefUserPhoto = 'google_user_photo';

  Future<void> _savePersistedUser(CloudUser user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefUserId, user.id);
      await prefs.setString(_prefUserEmail, user.email);
      if (user.displayName != null) {
        await prefs.setString(_prefUserName, user.displayName!);
      } else {
        await prefs.remove(_prefUserName);
      }
      if (user.photoUrl != null) {
        await prefs.setString(_prefUserPhoto, user.photoUrl!);
      } else {
        await prefs.remove(_prefUserPhoto);
      }
    } catch (e) {
      debugPrint('Failed to persist Google user: $e');
    }
  }

  Future<CloudUser?> _loadPersistedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_prefUserId);
      final email = prefs.getString(_prefUserEmail);
      if (id != null && email != null) {
        return CloudUser(
          id: id,
          email: email,
          displayName: prefs.getString(_prefUserName),
          photoUrl: prefs.getString(_prefUserPhoto),
        );
      }
    } catch (e) {
      debugPrint('Failed to load persisted Google user: $e');
    }
    return null;
  }

  Future<void> _clearPersistedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefUserId);
      await prefs.remove(_prefUserEmail);
      await prefs.remove(_prefUserName);
      await prefs.remove(_prefUserPhoto);
    } catch (e) {
      debugPrint('Failed to clear persisted Google user: $e');
    }
  }

  @override
  Future<CloudUser?> getCurrentUser() async {
    if (_currentUser != null) return _currentUser;

    // 1. First restore locally persisted user so app never demands login repeatedly
    final persisted = await _loadPersistedUser();
    if (persisted != null) {
      _currentUser = persisted;
      _authController.add(_currentUser);
    }

    // 2. Silently verify/refresh in the background if possible
    final silent = await signInSilently();
    if (silent != null) {
      _currentUser = silent;
      _savePersistedUser(silent);
      return silent;
    }

    return _currentUser;
  }

  @override
  Future<CloudUser?> signIn() async {
    await ensureInitialized();

    // Prevent multiple simultaneous sign-in requests
    if (_signInCompleter != null && !_signInCompleter!.isCompleted) {
      return _signInCompleter!.future;
    }

    _signInCompleter = Completer<CloudUser?>();

    try {
      if (supportsAuthenticate) {
        // Mobile (Android / iOS): Use authenticate flow
        // Do NOT request Drive scope during basic sign-in (request incrementally later)
        final account = await GoogleSignIn.instance.authenticate(
          scopeHint: basicScopes,
        );
        _currentAccount = account;
        _currentUser = _mapAccount(account);
        _savePersistedUser(_currentUser!);
        _authController.add(_currentUser);
        _signInCompleter!.complete(_currentUser);
        return _currentUser;
      } else {
        // Web: authenticate() is NOT supported by GIS SDK.
        // Web authentication is triggered via the GIS rendered button or lightweight authentication.
        final lightweight = await signInSilently();
        if (lightweight != null) {
          _signInCompleter!.complete(lightweight);
          return lightweight;
        }
        // If not already signed in on Web, the UI should display the Web GIS Button
        _signInCompleter!.complete(null);
        return null;
      }
    } catch (e) {
      debugPrint('Google Sign-In failed: $e');
      if (!_signInCompleter!.isCompleted) {
        _signInCompleter!.complete(null);
      }
      rethrow;
    }
  }

  @override
  Future<CloudUser?> signInSilently() async {
    await ensureInitialized();
    try {
      final account = await GoogleSignIn.instance.attemptLightweightAuthentication();
      if (account != null) {
        _currentAccount = account;
        _currentUser = _mapAccount(account);
        _savePersistedUser(_currentUser!);
        _authController.add(_currentUser);
        return _currentUser;
      }
      return null;
    } catch (e) {
      debugPrint('GoogleSignIn.attemptLightweightAuthentication error: $e');
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    await ensureInitialized();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('Google Sign-Out error: $e');
    } finally {
      _currentAccount = null;
      _currentUser = null;
      await _clearPersistedUser();
      _authController.add(null);
    }
  }

  @override
  Future<void> disconnect() async {
    await ensureInitialized();
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (e) {
      debugPrint('Google Disconnect error: $e');
    } finally {
      _currentAccount = null;
      _currentUser = null;
      await _clearPersistedUser();
      _authController.add(null);
    }
  }

  /// Obtains an authenticated HTTP client for Google Drive API.
  /// Incrementally requests the narrow [drive.file] scope only when needed.
  @override
  Future<http.Client?> getAuthenticatedClient({bool requestDriveScope = true}) async {
    await ensureInitialized();
    if (_currentAccount == null) {
      await signInSilently();
    }
    if (_currentAccount == null) return null;

    try {
      final scopes = requestDriveScope ? driveScopes : basicScopes;
      final headers = await _currentAccount!.authorizationClient.authorizationHeaders(
        scopes,
        promptIfNecessary: true,
      );
      if (headers == null) return null;
      return _AuthenticatedHttpClient(headers);
    } catch (e) {
      debugPrint('Failed to obtain authorization headers for Drive: $e');
      return null;
    }
  }
}

/// Authenticated HTTP client wrapper that injects OAuth Bearer tokens into Google Drive requests.
class _AuthenticatedHttpClient extends http.BaseClient {
  final Map<String, String> _authHeaders;
  final http.Client _inner = http.Client();

  _AuthenticatedHttpClient(this._authHeaders);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_authHeaders);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

/// Deterministic mock authentication service for unit tests and headless environments.
class MockCloudAuthService implements ICloudAuthService {
  CloudUser? _user;
  final StreamController<CloudUser?> _authController = StreamController<CloudUser?>.broadcast();
  final bool _supportsAuthenticate;

  MockCloudAuthService({
    CloudUser? initialUser,
    bool supportsAuthenticate = true,
  })  : _user = initialUser,
        _supportsAuthenticate = supportsAuthenticate;

  void setMockUser(CloudUser? user) {
    _user = user;
    _authController.add(_user);
  }

  @override
  bool get supportsAuthenticate => _supportsAuthenticate;

  @override
  bool get isSigningIn => false;

  @override
  Stream<CloudUser?> get authStateChanges => _authController.stream;

  @override
  Future<CloudUser?> getCurrentUser() async => _user;

  @override
  Future<CloudUser?> signIn() async {
    _user ??= const CloudUser(
      id: 'mock-google-sub-12345678',
      email: 'user@gmail.com',
      displayName: 'Test User',
    );
    _authController.add(_user);
    return _user;
  }

  @override
  Future<CloudUser?> signInSilently() async => _user;

  @override
  Future<void> signOut() async {
    _user = null;
    _authController.add(null);
  }

  @override
  Future<void> disconnect() async {
    _user = null;
    _authController.add(null);
  }

  @override
  Future<http.Client?> getAuthenticatedClient({bool requestDriveScope = true}) async {
    return _AuthenticatedHttpClient({'Authorization': 'Bearer mock-test-token'});
  }
}
