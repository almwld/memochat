import 'package:fluttertoast/fluttertoast.dart';

class ToastService {
  static Future<void> showInfo(String message) async => Fluttertoast.showToast(msg: message);
  static Future<void> showSuccess(String message) async => Fluttertoast.showToast(msg: message);
  static Future<void> showError(String message) async => Fluttertoast.showToast(msg: message);
  static Future<void> show(String message) async => Fluttertoast.showToast(msg: message);
  static Future<void> hide() async => Fluttertoast.cancel();
  static Future<void> showContext(BuildContext context, String message) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
