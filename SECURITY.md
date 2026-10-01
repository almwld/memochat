## MemoChat Security

- Firebase Authentication and Firestore authorization remain the server access boundary.
- Sensitive local secrets are protected by flutter_secure_storage.
- Optional التشفير العسكري mode uses a device-local AES-256-GCM key stored in secure storage for sensitive local payloads.
- The switch does not silently change the existing Firestore message contract, so enabling it cannot create undecryptable messages.

## End-to-end encryption status

MemoChat does not currently claim Signal Protocol E2EE. Real E2EE requires authenticated identity keys, pre-key distribution, persistent session stores, Double Ratchet/PQ ratcheting, multi-device key management, safety-number verification, encrypted media key envelopes, and protocol/vector tests.

Before advertising E2EE, verify identity keys, signed pre-keys, session persistence, replay/wrong-recipient handling, group SenderKey lifecycle, encrypted media keys, multi-device behavior, Firestore ciphertext-only rules, and release security testing.
