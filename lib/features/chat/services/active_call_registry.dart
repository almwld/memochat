// ============================================================
// 📞 ActiveCallRegistry — Singleton لحالة المكالمة النشطة
// ============================================================
// - يتتبع مكالمة واحدة فقط في الوقت الواحد
// - بدون Queue (سلوك busy مباشر)
// - idempotent (register/unregister آمنة للتكرار)
// ============================================================

import 'package:flutter/foundation.dart';

class ActiveCallRegistry {
  ActiveCallRegistry._();
  static final ActiveCallRegistry instance = ActiveCallRegistry._();

  String? _activeCallId;
  DateTime? _startedAt;

  bool get hasActiveCall => _activeCallId != null;
  String? get activeCallId => _activeCallId;
  DateTime? get startedAt => _startedAt;

  Duration? get elapsed {
    if (_startedAt == null) return null;
    return DateTime.now().difference(_startedAt!);
  }

  bool isActive(String callId) => _activeCallId == callId;

  void register(String callId) {
    final id = callId.trim();
    if (id.isEmpty || _activeCallId == id) return;
    if (_activeCallId != null) {
      debugPrint('⚠️ ActiveCallRegistry: OVERRIDE $_activeCallId → $id');
    }
    _activeCallId = id;
    _startedAt = DateTime.now();
    debugPrint('📞 ActiveCallRegistry: REGISTER $id');
  }

  void unregister([String? callId]) {
    if (_activeCallId == null) return;
    final requested = callId?.trim();
    if (requested != null && requested.isNotEmpty && requested != _activeCallId) {
      debugPrint('⚠️ ActiveCallRegistry: skip unregister (current: $_activeCallId, requested: $requested)');
      return;
    }
    debugPrint('📞 ActiveCallRegistry: UNREGISTER $_activeCallId');
    _activeCallId = null;
    _startedAt = null;
  }

  void reset() {
    if (_activeCallId == null) return;
    debugPrint('📞 ActiveCallRegistry: RESET (was: $_activeCallId)');
    _activeCallId = null;
    _startedAt = null;
  }
}
