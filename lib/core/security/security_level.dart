enum SecurityLevel {
  standard,
  enhanced,
  maximum,
  custom,
}

extension SecurityLevelX on SecurityLevel {
  String get storageValue => name;

  String get label {
    switch (this) {
      case SecurityLevel.standard:
        return 'Standard';
      case SecurityLevel.enhanced:
        return 'Enhanced';
      case SecurityLevel.maximum:
        return 'Maximum';
      case SecurityLevel.custom:
        return 'Custom';
    }
  }

  int get rank {
    switch (this) {
      case SecurityLevel.standard:
        return 1;
      case SecurityLevel.enhanced:
        return 2;
      case SecurityLevel.maximum:
        return 3;
      case SecurityLevel.custom:
        return 0;
    }
  }
}

enum SecurityProtocol {
  metadataProtection,
  onionRouting,
  sealedSender,
  postQuantumHybrid,
  matrixBridge,
  dhtDiscovery,
  meshOffline,
  quicTransport,
  websocketFallback,
  httpsFallback,
}

extension SecurityProtocolX on SecurityProtocol {
  String get storageKey => 'security.protocol.$name';

  String get label {
    switch (this) {
      case SecurityProtocol.metadataProtection:
        return 'حماية البيانات الوصفية';
      case SecurityProtocol.onionRouting:
        return 'توجيه Onion';
      case SecurityProtocol.sealedSender:
        return 'Sealed Sender';
      case SecurityProtocol.postQuantumHybrid:
        return 'تشفير ما بعد الكم الهجين';
      case SecurityProtocol.matrixBridge:
        return 'Matrix Bridge';
      case SecurityProtocol.dhtDiscovery:
        return 'DHT Discovery';
      case SecurityProtocol.meshOffline:
        return 'Mesh / BLE';
      case SecurityProtocol.quicTransport:
        return 'QUIC';
      case SecurityProtocol.websocketFallback:
        return 'WebSocket';
      case SecurityProtocol.httpsFallback:
        return 'HTTPS';
    }
  }
}
