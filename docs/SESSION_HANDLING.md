# Session Expiration Handling

This document explains how the mobile app handles session expiration (30-minute JWT token timeout).

## Overview

The backend JWT tokens expire after **30 minutes** (configured in `TagBack/auth/auth_utils.py`). When a token expires, the server returns a `401 Unauthorized` response. The mobile app now properly detects and handles these expired sessions.

## Implementation

### 1. HTTP Client with Session Detection

**File:** [lib/services/http_client.dart](../lib/services/http_client.dart)

A centralized HTTP client that:
- Automatically adds authentication headers to all requests
- Detects 401 Unauthorized responses
- Triggers automatic logout when sessions expire
- Shows user-friendly error messages
- Handles all HTTP error codes properly

```dart
// All API calls now use HttpClient
final response = await HttpClient.get('/bus');
final response = await HttpClient.post('/bus/locations', body: {...});
```

### 2. Session Expiration Exception

**File:** [lib/exceptions/session_expired_exception.dart](../lib/exceptions/session_expired_exception.dart)

Custom exception thrown when the session expires (401 response). This allows API consumers to handle session expiration differently from other errors.

### 3. Automatic Logout on Session Expiration

**File:** [lib/store/auth_store.dart](../lib/store/auth_store.dart)

The `AuthStore` now has a `forceLogout()` method that:
- Clears stored authentication tokens
- Resets authentication state
- Triggers UI updates via `notifyListeners()`

```dart
Future<void> forceLogout() async {
  try {
    await AuthService.logout();
  } finally {
    _isAuthenticated = false;
    _token = null;
    _user = null;
    _isLoading = false;
    notifyListeners();
  }
}
```

### 4. User-Friendly Session Expiration Dialog

**File:** [lib/main.dart](../lib/main.dart)

On app startup, a global session expiration handler is registered:

```dart
void _setupSessionExpirationHandler() {
  HttpClient.onSessionExpired = () async {
    final authStore = AuthStore();
    await authStore.forceLogout();

    // Show session expired dialog
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Session Expired'),
            content: const Text(
              'Your session has expired. Please log in again to continue.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Navigation handled automatically by AuthWrapper
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  };
}
```

### 5. Updated API Services

All API services now use the centralized `HttpClient`:

- **[lib/services/api_service.dart](../lib/services/api_service.dart)** - Bus and location APIs
- **[lib/services/routes_service.dart](../lib/services/routes_service.dart)** - Route APIs
- **[lib/services/user_settings_service.dart](../lib/services/user_settings_service.dart)** - User settings APIs

## User Experience

### Before Fix
1. User is logged in
2. After 30 minutes of inactivity, token expires
3. User tries to load buses/routes
4. App shows generic error: "Failed to connect to server: Exception: Could not validate credentials"
5. User remains "logged in" but can't access any data
6. User must manually restart the app or figure out they need to log out and back in

### After Fix
1. User is logged in
2. After 30 minutes of inactivity, token expires
3. User tries to load buses/routes
4. App detects 401 response
5. **Dialog appears:** "Session Expired - Your session has expired. Please log in again to continue."
6. User clicks "OK"
7. App automatically logs user out and shows login screen
8. User logs back in and continues using the app

## Architecture Diagram

```
┌─────────────────────────────────────────────────┐
│  UI Layer (Pages/Widgets)                       │
│  - BusTrackingPage                             │
│  - SettingsPage                                │
│  - AdvancedTrackerPage                         │
└─────────────────┬───────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────┐
│  Service Layer                                  │
│  - ApiService                                  │
│  - RoutesService                               │
│  - UserSettingsService                         │
└─────────────────┬───────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────┐
│  HttpClient (Centralized)                       │
│  - Add auth headers                            │
│  - Detect 401 responses                        │
│  - Trigger onSessionExpired callback           │
│  - Handle other HTTP errors                    │
└─────────────────┬───────────────────────────────┘
                  │
        ┌─────────┴─────────┐
        ▼                   ▼
┌───────────────┐   ┌──────────────────┐
│  Backend API  │   │  Session Handler │
│  (FastAPI)    │   │  (main.dart)     │
│               │   │  - Force logout  │
│  Returns 401  │   │  - Show dialog   │
│  on expired   │   │  - Navigate to   │
│  tokens       │   │    login         │
└───────────────┘   └──────────────────┘
```

## Error Handling Flow

```
API Request
    │
    ▼
HttpClient.request()
    │
    ├─── Success (200-299) ──────► Return response
    │
    ├─── 401 Unauthorized ───────► SessionExpiredException
    │                               │
    │                               ├─► Trigger onSessionExpired()
    │                               │   │
    │                               │   ├─► AuthStore.forceLogout()
    │                               │   │   │
    │                               │   │   └─► Clear tokens
    │                               │   │       Update state
    │                               │   │
    │                               │   └─► Show "Session Expired" dialog
    │                               │
    │                               └─► Throw exception
    │
    └─── Other errors (400, 500) ─► HttpException
                                     │
                                     └─► Extract error message
                                         Throw exception
```

## Testing Session Expiration

### Manual Testing

1. **Login to the app**
   ```dart
   // Use valid credentials
   ```

2. **Wait 30+ minutes** or **manually expire token** in backend:
   ```python
   # In TagBack/auth/auth_utils.py
   ACCESS_TOKEN_EXPIRE_MINUTES = 1  # Set to 1 minute for testing
   ```

3. **Trigger any API call** (load buses, routes, etc.)

4. **Verify:**
   - Dialog appears with "Session Expired" message
   - User is logged out automatically
   - Login screen is shown
   - No generic error messages

### Programmatic Testing

You can simulate a 401 response:

```dart
// In test environment
HttpClient.onSessionExpired = () {
  print('Session expired handler called');
};

// Trigger a 401 by using an invalid token
```

## Configuration

### Adjust Session Timeout (Backend)

Edit [TagBack/auth/auth_utils.py:11](../../TagBack/auth/auth_utils.py#L11):

```python
ACCESS_TOKEN_EXPIRE_MINUTES = 30  # Change to desired minutes
```

### Customize Session Expiration Message (Mobile)

Edit [lib/main.dart](../lib/main.dart) in `_setupSessionExpirationHandler()`:

```dart
AlertDialog(
  title: const Text('Session Expired'),  // Customize title
  content: const Text(
    'Your session has expired. Please log in again to continue.',  // Customize message
  ),
  // ...
)
```

## Security Considerations

1. **Token Storage:** Tokens are stored in `SharedPreferences` (unencrypted)
   - Consider using `flutter_secure_storage` for production

2. **Auto-logout:** Users are automatically logged out on 401
   - No server-side session invalidation needed

3. **No Token Refresh:** Currently no refresh token mechanism
   - Users must re-authenticate every 30 minutes of inactivity
   - Future improvement: Implement refresh tokens

## Future Improvements

1. **Refresh Token Mechanism**
   - Implement refresh tokens in backend
   - Auto-refresh access tokens before expiration
   - Reduce login frequency for users

2. **Secure Token Storage**
   - Use `flutter_secure_storage` package
   - Encrypt tokens in storage

3. **Session Activity Tracking**
   - Track last activity timestamp
   - Warn users before session expires
   - Auto-refresh on user activity

4. **Offline Support**
   - Cache user data locally
   - Allow limited offline functionality
   - Sync when connection restored

## Related Files

- [lib/services/http_client.dart](../lib/services/http_client.dart) - HTTP client with session handling
- [lib/services/auth_service.dart](../lib/services/auth_service.dart) - Authentication service
- [lib/store/auth_store.dart](../lib/store/auth_store.dart) - Authentication state management
- [lib/exceptions/session_expired_exception.dart](../lib/exceptions/session_expired_exception.dart) - Custom exception
- [lib/main.dart](../lib/main.dart) - App initialization with session handler
- [../../TagBack/auth/auth_utils.py](../../TagBack/auth/auth_utils.py) - Backend JWT configuration
