import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ShareFormDialog extends StatefulWidget {
  final String link;
  final String qrUrl;

  const ShareFormDialog({super.key, required this.link, required this.qrUrl});

  @override
  State<ShareFormDialog> createState() => _ShareFormDialogState();
}

class _ShareFormDialogState extends State<ShareFormDialog> {
  int _selectedTab = 0;
  late final TextEditingController _linkController;

  @override
  void initState() {
    super.initState();
    _linkController = TextEditingController(text: widget.link);
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ShareFormDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.link != widget.link) {
      _linkController.text = widget.link;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Kirim formulir',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Kirim melalui',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _tabIcon(Icons.link, 0),
                const SizedBox(width: 4),
                _tabIcon(Icons.qr_code, 1),
              ],
            ),
            const Divider(height: 24),
            if (_selectedTab == 0) _buildLinkTab() else _buildQrTab(),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Batal',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabIcon(IconData icon, int index) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          border: isSelected
              ? const Border(
                  bottom: BorderSide(color: Color(0xFF0F52BA), width: 3),
                )
              : null,
        ),
        child: Icon(
          icon,
          color: isSelected ? const Color(0xFF0F52BA) : Colors.black38,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildLinkTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _linkController,
          readOnly: true,
          style: const TextStyle(fontSize: 13, color: Color(0xFF2563EB)),
          decoration: const InputDecoration(
            border: UnderlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.link));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Tautan disalin!')));
            },
            child: const Text(
              'Salin',
              style: TextStyle(
                color: Color(0xFF0F52BA),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQrTab() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Image.network(
          widget.qrUrl,
          height: 180,
          width: 180,
          errorBuilder: (context, error, stackTrace) => const SizedBox(
            height: 180,
            width: 180,
            child: Center(
              child: Icon(Icons.qr_code, size: 80, color: Colors.black26),
            ),
          ),
        ),
      ),
    );
  }
}
