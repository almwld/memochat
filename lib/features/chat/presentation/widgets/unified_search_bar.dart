import 'package:flutter/material.dart';

class UnifiedSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String hintText;
  final VoidCallback? onTap;
  final String? hint;
  final EdgeInsets? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? textColor;
  final Color? hintColor;
  final Widget? suffixIcon;
  const UnifiedSearchBar({super.key,this.controller,this.onChanged,this.hintText='بحث',this.onTap});
  @override Widget build(BuildContext context){ final child=TextField(controller:controller,onChanged:onChanged,onTap:onTap,style:TextStyle(color:textColor),decoration:InputDecoration(hintText:hint ?? hintText,hintStyle:hintColor==null?null:TextStyle(color:hintColor),prefixIcon:const Icon(Icons.search),suffixIcon:suffixIcon,filled:backgroundColor!=null,fillColor:backgroundColor,border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:BorderSide(color:borderColor ?? Colors.grey)));); return margin==null?child:Padding(padding:margin!,child:child); }
}
