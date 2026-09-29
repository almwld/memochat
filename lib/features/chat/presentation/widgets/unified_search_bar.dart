import 'package:flutter/material.dart';

class UnifiedSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String hintText;
  final VoidCallback? onTap;
  const UnifiedSearchBar({super.key,this.controller,this.onChanged,this.hintText='بحث',this.onTap});
  @override Widget build(BuildContext context)=>TextField(controller:controller,onChanged:onChanged,onTap:onTap,decoration:InputDecoration(hintText:hintText,prefixIcon:const Icon(Icons.search),border:OutlineInputBorder(borderRadius:BorderRadius.circular(16))));
}
