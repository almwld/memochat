import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ToastService {
  const ToastService._();
  static Future<void> show(String message) async => Fluttertoast.showToast(msg: message);
  static Future<void> showSuccess(String message) => show(message);
  static Future<void> showError(String message) => show(message);
  static Future<void> showInfo(String message) => show(message);
  static Future<void> showWarning(String message) => show(message);
}
