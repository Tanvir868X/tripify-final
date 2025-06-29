# Google Sign-In Setup Guide

## Prerequisites
1. Google Cloud Console project
2. Android app configured in Google Cloud Console
3. SHA-1 fingerprint of your debug keystore

## Setup Steps

### 1. Get SHA-1 Fingerprint
Run this command in your project directory:
```bash
cd android
./gradlew signingReport
```

Look for the SHA-1 value in the debug variant.

### 2. Google Cloud Console Setup
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable Google Sign-In API
4. Go to "Credentials" → "Create Credentials" → "OAuth 2.0 Client IDs"
5. Choose "Android" as application type
6. Enter your package name: `com.example.tripify`
7. Enter the SHA-1 fingerprint from step 1
8. Download the `google-services.json` file

### 3. Add google-services.json
Place the downloaded `google-services.json` file in:
```
android/app/google-services.json
```

### 4. Update build.gradle
Add to `android/build.gradle.kts`:
```kotlin
plugins {
    id("com.google.gms.google-services") version "4.4.0" apply false
}
```

Add to `android/app/build.gradle.kts`:
```kotlin
plugins {
    id("com.google.gms.google-services")
}
```

### 5. Test the Implementation
Run the app and try the "Continue with Google" button.

## Troubleshooting
- Make sure SHA-1 fingerprint is correct
- Verify package name matches exactly
- Check that google-services.json is in the correct location
- Ensure Google Sign-In API is enabled in Google Cloud Console 