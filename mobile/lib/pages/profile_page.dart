// lib/pages/profile_page.dart
// Halaman pengaturan profil pengguna. Mendukung edit username/foto profil,
// menampilkan email read-only, dan menyimpan perubahan ke backend.

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  String _email = '';
  String? _avatarUrl;
  File? _pickedImage;
  bool _isLoading = true;
  bool _isSaving = false;

  // Store originals to detect changes / cancel
  String _originalName = '';
  String? _originalAvatarUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final result = await ApiService.getMe();
    if (result['success'] == true && mounted) {
      final data = result['data'];
      setState(() {
        _nameController.text = data['full_name'] ?? '';
        _email = data['email'] ?? '';
        _avatarUrl = data['avatar_url'];
        _originalName = _nameController.text;
        _originalAvatarUrl = _avatarUrl;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  bool get _hasChanges {
    return _nameController.text != _originalName ||
        _pickedImage != null ||
        _avatarUrl != _originalAvatarUrl;
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildImagePickerSheet(),
    );
  }

  Widget _buildImagePickerSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Foto Profil',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 20),
          _sheetOption(
            icon: Icons.camera_alt_outlined,
            label: 'Ambil Foto',
            color: const Color(0xFF4F46E5),
            onTap: () {
              Navigator.pop(context);
              _getImage(ImageSource.camera);
            },
          ),
          _sheetOption(
            icon: Icons.photo_library_outlined,
            label: 'Pilih dari Galeri',
            color: const Color(0xFF0891B2),
            onTap: () {
              Navigator.pop(context);
              _getImage(ImageSource.gallery);
            },
          ),
          if (_avatarUrl != null || _pickedImage != null)
            _sheetOption(
              icon: Icons.delete_outline,
              label: 'Hapus Foto Profil',
              color: const Color(0xFFDC2626),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _pickedImage = null;
                  _avatarUrl = null;
                });
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _sheetOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: color == const Color(0xFFDC2626) ? color : Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      if (kIsWeb) {
        // On web, it might fall back to file picker if camera is blocked/unavailable.
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kamera tidak didukung pada platform desktop, membuka file explorer...'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        source = ImageSource.gallery;
      }
    }

    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source, maxWidth: 512, maxHeight: 512, imageQuality: 80);
      if (image != null && mounted) {
        setState(() {
          _pickedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil gambar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    String? uploadedAvatarUrl;

    // Upload the new image first if picked
    if (_pickedImage != null) {
      final uploadResult = await ApiService.uploadFile(_pickedImage!);
      if (uploadResult['success'] == true) {
        uploadedAvatarUrl = uploadResult['file_url'] as String;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal upload foto: ${uploadResult['message']}'), backgroundColor: Colors.red),
          );
        }
        setState(() => _isSaving = false);
        return;
      }
    }

    final payload = <String, dynamic>{};
    if (_nameController.text != _originalName) {
      payload['full_name'] = _nameController.text;
    }

    // If new image uploaded or avatar removed
    if (uploadedAvatarUrl != null) {
      payload['avatar_url'] = uploadedAvatarUrl;
    } else if (_avatarUrl == null && _originalAvatarUrl != null) {
      // Avatar was removed
      payload['avatar_url'] = '';
    }

    if (payload.isEmpty) {
      setState(() => _isSaving = false);
      if (mounted) Navigator.pop(context, true);
      return;
    }

    final result = await ApiService.updateProfile(payload);
    setState(() => _isSaving = false);

    if (result['success'] == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil berhasil diperbarui!'),
          backgroundColor: Color(0xFF059669),
        ),
      );
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: ${result['message']}'), backgroundColor: Colors.red),
      );
    }
  }

  void _cancel() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: _cancel,
        ),
        title: const Text(
          'Settings',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        centerTitle: false,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE5E7EB)),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Section Title
                  Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ─── Profile Avatar ──────────────────────────────────────
                  _buildAvatarSection(),
                  const SizedBox(height: 40),

                  // ─── Username Field ──────────────────────────────────────
                  _buildField(
                    label: 'Username',
                    child: TextField(
                      controller: _nameController,
                      onChanged: (_) => setState(() {}), // trigger rebuild for hasChanges
                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ─── Email Field (Read-Only) ─────────────────────────────
                  _buildField(
                    label: 'Email',
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Text(
                        _email,
                        style: const TextStyle(fontSize: 15, color: Color(0xFF9CA3AF)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // ─── Action Buttons ──────────────────────────────────────
                  _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildAvatarSection() {
    return Column(
      children: [
        Stack(
          children: [
            // Avatar circle
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5E7EB), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipOval(child: _buildAvatarImage()),
            ),
            // Camera badge
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _nameController.text.isNotEmpty ? _nameController.text : 'User',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 4),
        Text(
          _email,
          style: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
        ),
      ],
    );
  }

  Widget _buildAvatarImage() {
    if (_pickedImage != null) {
      if (kIsWeb) {
        return Image.network(_pickedImage!.path, width: 110, height: 110, fit: BoxFit.cover);
      }
      return Image.file(_pickedImage!, width: 110, height: 110, fit: BoxFit.cover);
    }
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      String url = _avatarUrl!;
      if (url.contains('localhost')) {
        final apiHost = Uri.parse(ApiService.baseUrl).host;
        url = url.replaceAll('localhost', apiHost);
      }
      return Image.network(
        url,
        width: 110,
        height: 110,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildDefaultAvatar(),
      );
    }
    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 110,
      height: 110,
      color: const Color(0xFFEEF2FF),
      child: const Icon(Icons.person, size: 50, color: Color(0xFF9CA3AF)),
    );
  }

  Widget _buildField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isSaving ? null : _cancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6B7280),
              side: const BorderSide(color: Color(0xFFD1D5DB)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FilledButton(
            onPressed: (_isSaving || !_hasChanges) ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              disabledBackgroundColor: const Color(0xFFC7D2FE),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Save', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
