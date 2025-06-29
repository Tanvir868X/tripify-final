# Facebook Authentication Setup Guide

## Prerequisites
1. A Facebook Developer Account
2. A Facebook App created in the Facebook Developer Console

## Step 1: Create Facebook App

1. Go to [developers.facebook.com](https://developers.facebook.com)
2. Click "Create App"
3. Choose "Consumer" as the app type
4. Fill in your app details
5. Add the "Facebook Login" product to your app

## Step 2: Configure Facebook App

### Web Configuration
1. In your Facebook App Dashboard, go to "Settings" → "Basic"
2. Copy your **App ID**
3. Go to "Settings" → "Advanced" and copy your **Client Token**

### Android Configuration
1. Go to "Settings" → "Basic"
2. Add your Android package name: `com.example.tripify`
3. Generate and add your Android key hash

## Step 3: Update Configuration Files

### 1. Web Configuration (`web/index.html`)
Replace `REPLACE_WITH_YOUR_FACEBOOK_APP_ID` with your actual Facebook App ID:

```javascript
appId: '123456789012345', // Your actual Facebook App ID
```

### 2. Android Configuration (`android/app/src/main/res/values/strings.xml`)
Replace the placeholder values:

```xml
<string name="facebook_app_id">123456789012345</string>
<string name="facebook_client_token">your_client_token_here</string>
<string name="fb_login_protocol_scheme">fb123456789012345</string>
```

### 3. App Configuration (`lib/config/app_config.dart`)
Update the Facebook configuration:

```dart
static const String facebookAppId = '123456789012345';
static const String facebookClientToken = 'your_client_token_here';
```

## Step 4: Configure Firebase

1. Go to your Firebase Console
2. Navigate to Authentication → Sign-in method
3. Enable Facebook provider
4. Add your Facebook App ID and App Secret

## Step 5: Test the Integration

1. Run `flutter pub get`
2. Run `flutter run`
3. Test both Google and Facebook sign-in

## Troubleshooting

### "window.FB is undefined" Error
- Make sure you've replaced the Facebook App ID in `web/index.html`
- Ensure your Facebook App is properly configured for web
- Check that the Facebook SDK is loading (check browser console)

### Android Build Issues
- Verify your package name matches in Facebook App settings
- Ensure you've added the correct key hash
- Check that all strings.xml values are properly set

### Firebase Integration Issues
- Verify Facebook provider is enabled in Firebase Console
- Ensure App ID and App Secret are correctly entered
- Check that your Facebook App is in "Live" mode (not development)

## Security Notes

- Never commit your actual API keys to version control
- Use environment variables or secure configuration management
- Keep your Facebook App Secret secure
- Regularly rotate your tokens and keys 