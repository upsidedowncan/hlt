# Platform-Specific Instructions for Flutter WebRTC Audio

## Android Configuration

### 1. Permissions in Android Manifest
Add required permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### 2. Audio Attributes Configuration
For proper audio routing on Android, ensure you're using the correct audio attributes:

- Use `AudioManager.MODE_IN_COMMUNICATION` mode for voice calls
- Set audio attributes to `AudioAttributes.CONTENT_TYPE_SPEECH` for voice communication
- Enable echo cancellation and noise suppression for better call quality

### 3. Target SDK Version
Ensure your app targets at least SDK version 23 (Android 6.0) for better audio support:

In `android/app/build.gradle`:
```gradle
android {
    defaultConfig {
        minSdkVersion 23  // Minimum for proper audio support
        targetSdkVersion 33
        // ... other configs
    }
}
```

## iOS Configuration

### 1. Permissions in Info.plist
Add required permissions to `ios/Runner/Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs access to microphone for audio calls</string>
<key>UIBackgroundModes</key>
<array>
    <string>voip</string>
</array>
```

### 2. AVAudioSession Configuration
For proper audio routing on iOS:

- Use `AVAudioSessionCategoryPlayAndRecord` category for calls
- Set appropriate options: `defaultToSpeaker`, `allowBluetooth`, `mixWithOthers`
- Activate audio session properly before starting calls

### 3. Background App Refresh
Ensure your app can handle VoIP push notifications to receive calls when in background:

- Enable "Background Modes" capability in Xcode
- Enable "Voice over IP" background mode
- Handle VoIP push notifications properly

## Audio Session Best Practices

### 1. Initialization Order
1. Configure audio session before starting WebRTC calls
2. Initialize flutter_webrtc audio configuration early in your app lifecycle
3. Set up proper audio routing before getting media streams

### 2. Call State Management
- Configure audio session for communication mode when call starts
- Reset to normal mode when call ends
- Handle app foreground/background state changes properly

### 3. Audio Routing Control
- On iOS: Use `setAppleAudioIOMode` with `preferSpeakerOutput` parameter
- On Android: Use `setSpeakerphoneOn` method for speaker control
- Consider using `selectAudioOutput` to choose between different output devices

## Common Audio Issues and Solutions

### 1. No Audio Output
- Verify `RTCVideoView` widgets are present in the widget tree (even if hidden)
- Ensure audio tracks are enabled after connection
- Check audio session configuration is correct for your platform

### 2. Echo Issues
- Enable echo cancellation in getUserMedia constraints
- Use proper audio processing modes
- Ensure proper speaker/earpiece routing

### 3. Audio Quality Issues
- Use appropriate audio constraints: echoCancellation, noise suppression
- Consider audio bitrates and sample rates
- Test with different network conditions

### 4. Platform-Specific Routing Issues
- iOS: Ensure `AVAudioSession.sharedInstance().setActive(true)` after configuration
- Android: Use `setCommunicationMode(true)` for voice calls
- Check device-specific audio routing bugs

## Testing Checklist

### Before Releasing
- [ ] Test on multiple Android devices (different manufacturers)
- [ ] Test on multiple iOS versions and devices
- [ ] Verify audio works with headphones and Bluetooth devices
- [ ] Test switching between speaker and earpiece during calls
- [ ] Verify app handles background/foreground transitions properly
- [ ] Check audio performance with multiple concurrent calls
- [ ] Test with poor network conditions