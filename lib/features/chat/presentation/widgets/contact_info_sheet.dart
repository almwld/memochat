import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:memochat/core/constants/app_colors.dart';
import 'package:memochat/core/constants/imagekit.dart';
import 'package:memochat/core/services/toast_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ContactInfoSheet extends StatefulWidget {
  final String? name;
  final String? phone;
  final String? imageUrl;
  final String? specialty;
  final double? rating;
  final int? reviews;
  final String? experience;
  final bool? isAvailable;

  const ContactInfoSheet({
    super.key,
    this.name = 'د. أحمد المؤيد',
    this.phone = '+967 777 777 777',
    this.imageUrl = ImageKit.doctor1,
    this.specialty = 'استشاري باطنية وأطفال',
    this.rating = 4.9,
    this.reviews = 328,
    this.experience = '20+ سنة',
    this.isAvailable = true,
  });

  @override
  State<ContactInfoSheet> createState() => _ContactInfoSheetState();
}

class _ContactInfoSheetState extends State<ContactInfoSheet> {
  bool _isFavorite = false;
  bool _savingContact = false;

  Future<void> _saveContact() async {
    if (_savingContact) return;
    setState(() => _savingContact = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('saved_chat_contacts') ?? <String>[];
      final contact = jsonEncode({'name': widget.name ?? '', 'phone': widget.phone ?? '', 'imageUrl': widget.imageUrl ?? '', 'specialty': widget.specialty ?? ''});
      if (!raw.contains(contact)) { raw.add(contact); await prefs.setStringList('saved_chat_contacts', raw); }
      if (mounted) ToastService.showSuccess('تم حفظ جهة الاتصال على هذا الجهاز');
    } catch (_) { if (mounted) ToastService.showError('تعذر حفظ جهة الاتصال'); }
    finally { if (mounted) setState(() => _savingContact = false); }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundImage: CachedNetworkImageProvider(widget.imageUrl!),
                              child: const Icon(Icons.person, size: 50, color: Colors.white),
                            ),
                            if (widget.isAvailable == true)
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Column(
                          children: [
                            Text(
                              widget.name!,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.specialty!,
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildInfoChip(
                                  icon: Icons.star,
                                  label: '${widget.rating} (${widget.reviews})',
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 8),
                                _buildInfoChip(
                                  icon: Icons.work,
                                  label: widget.experience!,
                                  color: Colors.blue,
                                ),
                                const SizedBox(width: 8),
                                _buildInfoChip(
                                  icon: widget.isAvailable == true ? Icons.check_circle : Icons.cancel,
                                  label: widget.isAvailable == true ? 'متاح' : 'غير متاح',
                                  color: widget.isAvailable == true ? Colors.green : Colors.red,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionButton(
                            context,
                            Icons.call,
                            'مكالمة',
                            Colors.green,
                            () {
                              Navigator.pop(context);
                              ToastService.showInfo('📞 جاري الاتصال...');
                            },
                          ),
                          _buildActionButton(
                            context,
                            Icons.videocam,
                            'فيديو',
                            Colors.blue,
                            () {
                              Navigator.pop(context);
                              ToastService.showInfo('📹 جاري مكالمة الفيديو...');
                            },
                          ),
                          _buildActionButton(
                            context,
                            Icons.message,
                            'رسالة',
                            AppColors.primary,
                            () {
                              Navigator.pop(context);
                              ToastService.showInfo('💬 جاري فتح الدردشة...');
                            },
                          ),
                          _buildActionButton(
                            context,
                            Icons.favorite_border,
                            'مفضلة',
                            Colors.red,
                            () {
                              setState(() => _isFavorite = !_isFavorite);
                              ToastService.showSuccess(
                                _isFavorite ? '❤️ تمت الإضافة إلى المفضلة' : '💔 تمت الإزالة من المفضلة'
                              );
                            },
                          ),
                        ],
                      ),
                      const Divider(color: Colors.grey, height: 32),
                      _buildMenuItem(
                        context,
                        Icons.person_add_alt,
                        'حفظ جهة الاتصال',
                        _savingContact ? () {} : _saveContact,
                      ),
                      _buildMenuItem(
                        context,
                        Icons.edit_note,
                        'إضافة ملاحظات',
                        () => ToastService.showInfo('📝 فتح الملاحظات...'),
                      ),
                      _buildMenuItem(
                        context,
                        Icons.notifications_off_outlined,
                        'كتم الإشعارات',
                        () => ToastService.showSuccess('🔇 تم كتم الإشعارات'),
                      ),
                      _buildMenuItem(
                        context,
                        Icons.photo_library_outlined,
                        'عرض الوسائط',
                        () => ToastService.showInfo('🖼️ جاري عرض الوسائط...'),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              radius: 28,
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, VoidCallback onTap, {String? subtitle}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: isDark ? Colors.white54 : Colors.grey[600]),
      title: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 14,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 11,
              ),
            )
          : null,
      trailing: Icon(
        Icons.chevron_left,
        color: isDark ? Colors.white54 : Colors.grey[400],
      ),
      onTap: onTap,
    );
  }
}
