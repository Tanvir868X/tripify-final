# Firebase Setup Guide for Tripify

## Prerequisites
1. Firebase project
2. Android app configured in Firebase Console
3. SHA-1 fingerprint of your debug keystore

## Setup Steps

### 1. Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project" or select existing project
3. Follow the setup wizard

### 2. Add Android App to Firebase
1. In Firebase Console, click the Android icon (+ Add app)
2. Enter package name: `com.example.tripify`
3. Enter SHA-1 fingerprint: `E7:76:CB:5D:A8:BD:C0:CF:9B:3F:24:FC:EC:E4:87:45:82:92:C0:67`
4. Download the `google-services.json` file

### 3. Place google-services.json
Put the downloaded `google-services.json` file in:
```
android/app/google-services.json
```

### 4. Enable Authentication
1. In Firebase Console, go to "Authentication"
2. Click "Get started"
3. Go to "Sign-in method" tab
4. Enable "Google" as a sign-in provider
5. Add your support email

### 5. Update build.gradle (Already Done)
The build.gradle files are already configured with:
- `com.google.gms.google-services` plugin
- Firebase dependencies in pubspec.yaml

### 6. Test the Implementation
Run the app and try the "Continue with Google" button.

## Troubleshooting
- Make sure SHA-1 fingerprint is correct
- Verify package name matches exactly
- Check that google-services.json is in the correct location
- Ensure Google Sign-In is enabled in Firebase Authentication
- Make sure you have internet connection

## Benefits of Firebase Auth
- ✅ More reliable than direct Google Sign-In
- ✅ Better error handling
- ✅ User management dashboard
- ✅ Analytics and monitoring
- ✅ Multiple sign-in methods (Google, Email, Phone, etc.)
- ✅ Automatic user persistence 