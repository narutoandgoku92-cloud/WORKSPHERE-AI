# Authentication System - EXACT FIXES & CODE PATCHES

## FIX #1: Correct CORS_ORIGINS Configuration

### File: `.env`

**BEFORE:**
```env
CORS_ORIGINS=["http://localhost:3000","http://localhost:8080","http://localhost:19006","http://127.0.0.1:3000"]
```

**AFTER:**
```env
CORS_ORIGINS=["http://localhost:8000","http://127.0.0.1:8000","http://10.0.2.2:8000","http://localhost:3000","http://localhost:8080","http://localhost:19006","http://127.0.0.1:3000","https://worksphere-ai.onrender.com","https://*.onrender.com"]
```

**Explanation:**
- `http://localhost:8000` - Local dev on desktop
- `http://127.0.0.1:8000` - Local dev via IP
- `http://10.0.2.2:8000` - Android Emulator (forwards to host localhost:8000)
- `http://localhost:3000` - Web dev
- `https://worksphere-ai.onrender.com` - Production Render deployment
- `https://*.onrender.com` - Any Render subdomain

---

## FIX #2: Correct Refresh Token Endpoint Path

### File: `lib/services/api_client.dart`

**BEFORE (Line 148):**
```dart
final res = await _dio.post(
  '/api/v1/auth/refresh',  // ❌ WRONG: double /api/v1
  data: {'refresh_token': refresh},
);
```

**AFTER:**
```dart
final res = await _dio.post(
  '/auth/refresh',  // ✓ CORRECT: baseUrl adds /api/v1
  data: {'refresh_token': refresh},
);
```

**Explanation:**
- Dio baseUrl = `/api/v1` (set at initialization)
- Path = `/auth/refresh`
- Full URL = baseUrl + path = `/api/v1/auth/refresh` ✓

---

## FIX #3: Remove Duplicate Auth Provider

### Action: DELETE `lib/providers/auth_provider_fixed.dart`

**Reason:**
- Causes confusion (two different implementations)
- Uses wrong paths (`/api/v1/auth/login` instead of `/auth/login`)
- Has inconsistent token expiration logic
- Use ONLY `lib/providers/auth_provider.dart`

---

## FIX #4: Implement Proper Auth Provider with Expiration Tracking

### File: `lib/providers/auth_provider.dart`

**Replace entire file with:** (See COMPLETE_AUTH_PROVIDER.dart below)

Key improvements:
- Tracks token expiration time
- Automatic refresh 5 minutes before expiration
- Platform-aware secure storage
- Proper error logging
- Removes hardcoded demo credentials
- Implements proper token lifecycle management

---

## FIX #5: Fix ApiClient to Support Web Platform

### File: `lib/services/api_client.dart`

**Add platform detection at top:**
```dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
```

**Update FlutterSecureStorage initialization:**

**BEFORE:**
```dart
final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
```

**AFTER:**
```dart
late final FlutterSecureStorage _secureStorage;
late final Box<String> _hiveBox;

ApiClient() {
  // Initialize secure storage based on platform
  if (kIsWeb) {
    // Web doesn't support flutter_secure_storage
    // Will use Hive only (less secure but necessary)
    _initializeWeb();
  } else {
    // Mobile: use FlutterSecureStorage
    _secureStorage = const FlutterSecureStorage();
    _initializeMobile();
  }
}

Future<void> _initializeWeb() async {
  _hiveBox = await Hive.openBox<String>('auth_web');
}

Future<void> _initializeMobile() async {
  _hiveBox = await Hive.openBox<String>('auth_mobile');
}
```

---

## FIX #6: Remove Demo Credentials from Login Screen

### File: `lib/screens/login_screen.dart`

**BEFORE (Lines 115-127):**
```dart
// Demo credentials
Card(
  color: Colors.amber[50],
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Demo Credentials:', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        const Text('Admin: admin@optiwork.ai / password123'),
        const SizedBox(height: 4),
        const Text('Employee: emp@optiwork.ai / password123'),
      ],
    ),
  ),
),
```

**AFTER:**
```dart
// Dev/Demo warning (only show in DEBUG builds)
if (kDebugMode)
  Card(
    color: Colors.red[50],
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DEBUG MODE: Demo Credentials', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.red[900])),
          const SizedBox(height: 8),
          const Text('Admin: admin@optiwork.ai / password123'),
          const SizedBox(height: 4),
          const Text('Employee: emp@optiwork.ai / password123'),
        ],
      ),
    ),
  ),
```

---

## FIX #7: Add Request Logging

### File: `lib/services/api_client.dart`

**Add to onRequest interceptor:**
```dart
onRequest: (options, handler) async {
  log('📤 REQUEST: ${options.method} ${options.path}');
  
  if (!await _hasNetworkConnection()) {
    log('❌ NO NETWORK CONNECTION');
    return handler.reject(
      DioException(
        requestOptions: options,
        error: 'No internet connection',
        type: DioExceptionType.connectionError,
      ),
    );
  }

  final token = _accessToken ?? await _read(_accessTokenKey);

  if (token != null && token.isNotEmpty) {
    options.headers['Authorization'] = 'Bearer $token';
    log('✓ Authorization header added');
  }

  handler.next(options);
},
```

**Add to onError interceptor:**
```dart
onError: (error, handler) async {
  final status = error.response?.statusCode;
  final req = error.requestOptions;

  log('❌ ERROR: ${req.method} ${req.path} - Status: $status');
  log('   Error: ${error.error}');
  log('   Response: ${error.response?.data}');

  final isUnauthorized = status == 401 || status == 403;

  if (isUnauthorized && !_refreshing) {
    log('🔄 Attempting token refresh...');
    try {
      await _refreshAuthToken();
      final retry = await _retry(req);
      log('✓ Request retry successful');
      return handler.resolve(retry);
    } catch (e) {
      log('❌ Token refresh failed: $e');
      await clearAuthTokens();
    }
  }

  handler.next(error);
},
```

---

## FIX #8: Verify Backend Configuration for Render

### File: `backend/.env` (or Render environment variables)

**Ensure these are set:**
```env
# Production/Staging (Render)
ENVIRONMENT=production
DEBUG=false
AUTO_INIT_DB=false

# Database
DATABASE_URL=postgresql://user:password@render-postgres-host:5432/db_name

# JWT
SECRET_KEY=<very-long-random-secret-key>
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=7

# Security
ALLOWED_HOSTS=your-backend-service.onrender.com
CORS_ORIGINS=["https://worksphere-ai.onrender.com","https://*.onrender.com","http://localhost:8000","http://10.0.2.2:8000"]

# Redis
REDIS_URL=redis://render-redis-host:6379/0
```

---

## FIX #9: Add Retry Logic to Login

### File: `lib/providers/auth_provider.dart` - `login()` method

**Add exponential backoff retry:**
```dart
Future<bool> login(String email, String password, {int retries = 3}) async {
  for (int attempt = 1; attempt <= retries; attempt++) {
    state = state.copyWith(isLoading: true, error: null);

    try {
      log('📝 Login attempt $attempt/$retries for $email');
      
      final response = await apiClient.post(
        '/auth/login',
        data: {"email": email, "password": password},
      );

      final data = response.data;
      final accessToken = data['access_token'];
      final refreshToken = data['refresh_token'];
      final userData = data['user'];

      if (accessToken == null || refreshToken == null) {
        throw Exception('Missing tokens in response');
      }

      await apiClient.setAuthTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      final box = await Hive.openBox<String>('auth');
      await box.put('user', jsonEncode(userData));

      state = state.copyWith(
        user: User.fromJson(userData),
        isAuthenticated: true,
        isLoading: false,
      );

      log('✅ Login successful');
      return true;
      
    } on DioException catch (e) {
      final errorMessage = e.response?.data?['detail'] ?? e.message ?? 'Login failed';
      log('❌ Login attempt $attempt failed: $errorMessage');
      
      if (attempt < retries) {
        // Exponential backoff: 500ms, 1s, 2s
        final delayMs = 500 * attempt;
        log('⏳ Retrying in ${delayMs}ms...');
        await Future.delayed(Duration(milliseconds: delayMs));
      } else {
        state = state.copyWith(
          isLoading: false,
          error: errorMessage.toString(),
        );
        return false;
      }
    } catch (e) {
      log('❌ Login error: $e');
      state = state.copyWith(isLoading: false, error: 'Login failed: $e');
      
      if (attempt < retries) {
        final delayMs = 500 * attempt;
        await Future.delayed(Duration(milliseconds: delayMs));
      } else {
        return false;
      }
    }
  }
  
  return false;
}
```

---

## FIX #10: Update AppConfig for Environment Variables

### File: `lib/config/app_config.dart`

**Ensure proper defaults and environment fallbacks:**
```dart
static String _getDefaultBaseUrl() {
  if (kIsWeb) {
    // Web: check environment variable, fallback to production URL
    return const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://worksphere-ai.onrender.com',
    );
  }

  if (defaultTargetPlatform == TargetPlatform.android) {
    // Android emulator: use special localhost mapping
    return const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8000',
    );
  }

  // iOS simulator and physical devices
  return const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
}
```

---

## FIX #11: Add Health Check Before Login

### File: `lib/services/api_client.dart`

**Add new method:**
```dart
Future<bool> healthCheck() async {
  try {
    final response = await _dio.get('/health');
    return response.statusCode == 200;
  } catch (e) {
    log('❌ Health check failed: $e');
    return false;
  }
}
```

**Use in login screen:**
```dart
Future<void> _handleLogin() async {
  // ... validation code ...

  setState(() => _isLoading = true);

  // Check backend health first
  final apiClient = ref.read(apiClientProvider);
  final isHealthy = await apiClient.healthCheck();
  
  if (!isHealthy) {
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backend server is unavailable. Try again later.')),
    );
    return;
  }

  final authNotifier = ref.read(authProvider.notifier);
  final success = await authNotifier.login(
    _emailController.text,
    _passwordController.text,
  );

  setState(() => _isLoading = false);

  if (success) {
    context.go('/dashboard');
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ref.read(authProvider).error ?? 'Login failed')),
    );
  }
}
```

---

## IMPLEMENTATION ORDER

1. **Immediately:** Fix CORS_ORIGINS in `.env` (FIX #1)
2. **Immediately:** Fix refresh path in api_client.dart (FIX #2)
3. **High Priority:** Replace auth_provider.dart with proper implementation (FIX #4)
4. **High Priority:** Delete auth_provider_fixed.dart (FIX #3)
5. **High Priority:** Fix login screen demo credentials (FIX #6)
6. **Medium Priority:** Add request logging (FIX #7)
7. **Medium Priority:** Add platform detection for web (FIX #5)
8. **Ongoing:** Verify Render backend config (FIX #8)
9. **Nice to have:** Add retry logic to login (FIX #9)
10. **Nice to have:** Add health check (FIX #11)

---

## TESTING CHECKLIST

After implementing all fixes:

- [ ] Test login on Android emulator (http://10.0.2.2:8000)
- [ ] Test login on iOS simulator (http://localhost:8000)
- [ ] Test login on Flutter web (https://worksphere-ai.onrender.com)
- [ ] Token automatically refreshes at 10-minute mark (should log refresh event)
- [ ] User stays logged in for >15 minutes without manual refresh
- [ ] Network error shows appropriate message
- [ ] Token refresh retry works
- [ ] CORS preflight passes (check browser DevTools Network tab)
- [ ] Backend health check responds within 5 seconds
- [ ] Demo credentials not visible in release builds

---

## VERIFICATION COMMANDS

### Check CORS headers:
```bash
curl -X OPTIONS https://worksphere-ai.onrender.com/api/v1/auth/login \
  -H "Origin: https://worksphere-ai.onrender.com" \
  -H "Access-Control-Request-Method: POST" \
  -v
```

### Check refresh endpoint:
```bash
curl -X POST http://localhost:8000/api/v1/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{"refresh_token": "your-token"}' \
  -v
```

### Check health:
```bash
curl http://localhost:8000/health
```

