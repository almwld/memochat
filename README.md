# MemoChat

Modern Flutter messaging application foundation.

## Architecture
- Flutter
- Feature-first structure
- Repository layer
- Firebase-ready data contracts
- CI with analyze, tests and Android release build

## Roadmap
1. Core foundation
2. Authentication
3. Conversations and messaging
4. Media via Nextcloud
5. Push/local notifications
6. Voice/video calls via LiveKit
7. Offline synchronization and production hardening


## Architecture status

- Flutter client with Material 3 chat UI and optimistic-ready repository boundary.
- Firebase Auth/Firestore/FCM integration is isolated behind services.
- Local notifications, Nextcloud-compatible media upload, and LiveKit call transport are isolated behind services.
- Firestore security rules are included; credentials are intentionally not committed.
