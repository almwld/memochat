import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ToastService {
  static void showInfo(String message) => Fluttertoast.showToast(msg: message);
  static void showSuccess(String message) => Fluttertoast.showToast(msg: message);
  static void showError(String message) => Fluttertoast.showToast(msg: message);
  static void show(String message) => Fluttertoast.showToast(msg: message);
  static Future<void> hide() async => Fluttertoast.cancel();
  static void showContext(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
