import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'login_page.dart';
import 'templatemakerpage.dart';

class FormTemplate {
  final String title;
  final String subtitle;

  FormTemplate({required this.title, required this.subtitle});
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  List<FormTemplate> templates = [
    FormTemplate(title: "Quizz", subtitle: "Updated 2 days ago"),
    FormTemplate(title: "Ujian", subtitle: "Updated 1 week ago"),
    FormTemplate(title: "Angket Classmeet", subtitle: "Updated 1 month ago"),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: appBar(),
      endDrawer: _buildEndDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildCreateNewTemplateBtn(),
            const SizedBox(height: 16),
            ...templates.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _buildTemplateCard(t.title, t.subtitle),
            )).toList(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: const Color(0xFF1E66D0),
        unselectedItemColor: const Color(0xFF9CA3AF),
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description_outlined),
            label: 'Template',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: 'History',
          ),
        ],
      ),
    );
  }

  Widget _buildCreateNewTemplateBtn() {
    return CustomPaint(
      painter: DashedRectPainter(
        color: const Color(0xFFB4C5D4),
        strokeWidth: 1.5,
        dashWidth: 6,
        dashSpace: 4,
      ),
      child: InkWell(
        onTap: () async {
          final newTemplate = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TemplateMakerPage()),
          );
          if (newTemplate != null && newTemplate is FormTemplate) {
            setState(() {
              templates.insert(0, newTemplate);
            });
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFB4C5D4), width: 1.2),
                ),
                child: const Icon(Icons.add, color: Color(0xFFB4C5D4), size: 20),
              ),
              const SizedBox(height: 12),
              const Text(
                "Create New Template",
                style: TextStyle(
                  color: Color(0xFF8BA3B8),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateCard(String title, String subtitle) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Placeholder Image Area
          Container(
            height: 120,
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAFA),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Center(
              child: _buildDocumentPlaceholder(),
            ),
          ),
          // Info Area
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
                const Icon(Icons.more_vert, color: Color(0xFF9CA3AF)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentPlaceholder() {
    return Container(
      width: 80,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 8, width: 45, decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 10),
          Container(height: 4, width: double.infinity, decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 6),
          Container(height: 4, width: double.infinity, decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 6),
          Container(height: 4, width: 30, decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(2))),
          const Spacer(),
          Container(height: 8, width: double.infinity, decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(2))),
        ],
      ),
    );
  }

  Widget _buildEndDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(top: 50, left: 24, right: 24, bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Form4x',
                  style: TextStyle(
                    color: Color(0xFF1E66D0),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Color(0xFF4B5563)),
                ),
              ],
            ),
          ),
          // Menu Items
          _buildDrawerItem(
            icon: Icons.grid_view_rounded,
            title: 'Dashboard',
            isSelected: _selectedIndex == 0,
            onTap: () {
              setState(() => _selectedIndex = 0);
              Navigator.pop(context);
            },
          ),
          _buildDrawerItem(
            icon: Icons.description_outlined,
            title: 'Template',
            isSelected: _selectedIndex == 1,
            onTap: () {
              setState(() => _selectedIndex = 1);
              Navigator.pop(context);
            },
          ),
          _buildDrawerItem(
            icon: Icons.history_rounded,
            title: 'History',
            isSelected: _selectedIndex == 2,
            onTap: () {
              setState(() => _selectedIndex = 2);
              Navigator.pop(context);
            },
          ),
          const Spacer(),
          // Footer
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFFE5E7EB),
                  child: Icon(Icons.person, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Gita NUr',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
                Icon(Icons.logout, color: Color(0xFF9CA3AF)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
          border: Border(
            right: BorderSide(
              color: isSelected ? const Color(0xFF1E66D0) : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF1E66D0) : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? const Color(0xFF1E66D0) : const Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Column searchBar() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 5, left: 5, right: 5),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: const Color(0XFFB4C5D4).withOpacity(0.11),
                blurRadius: 40,
                spreadRadius: 0.0
              )
            ]
          ),
          child: TextField(
            decoration: InputDecoration(
              filled: true,
              hintText: 'Search',
              hintStyle: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 14,
              ),
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(10),
              prefixIcon: SizedBox(
                width: 0,
                child: IntrinsicHeight(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: SvgPicture.asset('assets/icons/searchicon.svg'),
                      ),
                    ],
                  ),
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(55),
                borderSide: BorderSide.none
              ),
            ),
          ),
        )
      ],
    );
  }

  AppBar appBar() {
    return AppBar(
      foregroundColor: Colors.blue,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Form4x',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Tempat membuat Form terlengkap',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          )
        ],
      ),
      backgroundColor: const Color(0xFFB4C5D4),
      centerTitle: false,
      leading: GestureDetector(
        onTap: () {},
        child: Container(
          margin: const EdgeInsets.all(5),
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 1, left: 10, right: 5),
            child: SvgPicture.asset('assets/icons/pP.svg'),
          ),
        ),
      ),
      actions: [
        Builder(
          builder: (context) => GestureDetector(
            onTap: () {
              Scaffold.of(context).openEndDrawer();
            },
            child: Container(
              margin: const EdgeInsets.all(10),
              alignment: Alignment.center,
              width: 37,
              child: const Padding(
                padding: EdgeInsets.only(bottom: 1, left: 5, right: 10),
                child: Icon(Icons.menu, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 25, left: 5, right: 5),
          child: searchBar(),
        ),
      ),
    );
  }
}

class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;

  DashedRectPainter({
    this.color = Colors.grey,
    this.strokeWidth = 1.0,
    this.dashWidth = 6.0,
    this.dashSpace = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(12),
    );

    final Path path = Path()..addRRect(rrect);
    final Path dashPath = Path();
    for (var metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        dashPath.addPath(
          metric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
