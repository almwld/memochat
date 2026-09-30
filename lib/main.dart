import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/services/firebase_bootstrap.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MemoChatApp());
  unawaited(FirebaseBootstrap.initialize());
}
