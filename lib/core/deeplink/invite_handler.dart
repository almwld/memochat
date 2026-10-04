import 'dart:async';
import 'package:app_links/app_links.dart';

class InviteHandler {
  InviteHandler._();
  static final instance = InviteHandler._();
  final AppLinks _links = AppLinks();
  StreamSubscription<Uri>? _subscription;

  Stream<Uri> get links => _links.uriLinkStream.where((uri) => uri.scheme == 'memochat' && uri.host == 'group' && uri.pathSegments.contains('invite'));

  void start(void Function(Uri uri) onLink) {
    _subscription ??= links.listen(onLink);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}