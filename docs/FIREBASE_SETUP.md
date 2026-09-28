# Firebase setup

MemoChat keeps Firebase integration behind services and repositories. No Firebase credentials are committed.

## Required setup

1. Create a Firebase project.
2. Register the Android application with package id `com.memochat.app`.
3. Add the generated Android Firebase configuration to the Android project.
4. Enable Authentication and Firestore.
5. Enable Cloud Messaging when push notifications are needed.
6. Deploy the Firestore rules in `firestore.rules`.

The app can still compile and run its in-memory demo without Firebase configuration. Call `FirebaseBootstrap.initialize()` only after the platform configuration is installed.
