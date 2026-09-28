import 'package:flutter/material.dart';
class AppTextField extends StatelessWidget {
  const AppTextField({super.key, this.controller, this.label, this.hint, this.validator, this.keyboardType, this.obscureText = false, this.onChanged});
  final TextEditingController? controller; final String? label; final String? hint; final String? Function(String?)? validator; final TextInputType? keyboardType; final bool obscureText; final ValueChanged<String>? onChanged;
  @override Widget build(BuildContext context) => TextFormField(controller: controller, validator: validator, keyboardType: keyboardType, obscureText: obscureText, onChanged: onChanged, decoration: InputDecoration(labelText: label, hintText: hint));
}
