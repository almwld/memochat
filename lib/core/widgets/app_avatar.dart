import 'package:flutter/material.dart';
class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, this.imageUrl, this.name, this.radius = 22});
  final String? imageUrl; final String? name; final double radius;
  @override Widget build(BuildContext context) {
    final fallback = (name == null || name!.trim().isEmpty) ? '?' : name!.trim()[0].toUpperCase();
    return CircleAvatar(radius: radius, backgroundImage: imageUrl == null || imageUrl!.isEmpty ? null : NetworkImage(imageUrl!), child: imageUrl == null || imageUrl!.isEmpty ? Text(fallback) : null);
  }
}
