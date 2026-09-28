abstract final class Validators {
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'البريد الإلكتروني مطلوب';
    final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());
    return valid ? null : 'البريد الإلكتروني غير صالح';
  }
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'رقم الهاتف مطلوب';
    final valid = RegExp(r'^\+?[0-9]{7,15}$').hasMatch(value.replaceAll(RegExp(r'[\s-]'), ''));
    return valid ? null : 'رقم الهاتف غير صالح';
  }
  static String? password(String? value) => value == null || value.length < 8 ? 'كلمة المرور يجب أن تكون 8 أحرف على الأقل' : null;
  static String? required(String? value, [String message = 'هذا الحقل مطلوب']) => value == null || value.trim().isEmpty ? message : null;
}
