import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTextStyles {
  static const title = TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
  static const heading = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
  static const body = TextStyle(fontSize: 15, height: 1.4, color: AppColors.textPrimary);
  static const bodySecondary = TextStyle(fontSize: 14, height: 1.4, color: AppColors.textSecondary);
  static const caption = TextStyle(fontSize: 12, color: AppColors.textSecondary);
}
