# Fake GPS by Horlakz

A small Android-only Flutter app that publishes a fixed mock GPS coordinate.
It keeps running through an Android foreground service until you tap Stop or
force-close the app.

## Install the debug APK

The shareable APK is at:

`dist/Fake-GPS-by-Horlakz-debug.apk`

Copy it to an Android phone, open it, and allow installation from that source
when Android asks. This is a debug-signed APK intended for private testing, not
Play Store distribution.

## Download a fresh APK from GitHub

The GitHub Actions workflow builds a fresh APK whenever `main` is updated. You
can also start it manually:

1. Open the repository on GitHub and select **Actions**.
2. Select **Build Android APK**.
3. Select **Run workflow**, keep the `main` branch selected, and confirm.
4. Open the completed run and download **Fake-GPS-by-Horlakz-debug** from the
   **Artifacts** section.
5. Extract the downloaded ZIP to get `Fake-GPS-by-Horlakz-debug.apk`.

GitHub keeps this build artifact for 30 days. The APK is debug-signed and can
be shared with another Android tester, who must complete the same mock-location
setup below.

## One-time phone setup

1. Open **Settings → About phone → Software information**.
2. Tap **Build number** seven times to enable Developer options.
3. Open **Settings → Developer options → Select mock location app**.
4. Choose **Fake GPS by Horlakz**.
5. Open the app and allow precise location and notification access.

Enter a latitude and longitude, tap **Start fake location**, then switch to the
app you want to test. Tap **Stop fake location** when finished. The last valid
coordinates are remembered.

Some apps detect mock locations or also use IP address, Wi-Fi, mobile network,
and other signals. This app cannot guarantee that every third-party app will
accept the simulated coordinate.

## Development

```text
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

The Flutter UI communicates with the Android implementation through one method
channel. `MockLocationService` owns the foreground notification and publishes a
new timestamped GPS test fix every second.
