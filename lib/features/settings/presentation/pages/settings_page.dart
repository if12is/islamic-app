import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F9F9),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF9F9F9),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF1A1C1C), size: 32),
            onPressed: () {},
          ),
          title: const Text(
            'الفجر',
            style: TextStyle(color: Color(0xFF1A1C1C), fontWeight: FontWeight.w900, fontSize: 26, letterSpacing: -0.5),
          ),
          centerTitle: false,
          actions: [
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF003527),
                child: const Icon(Icons.person, color: Colors.white),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          children: [
            // Profile Area
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1C1C),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(Icons.person, size: 60, color: Colors.white24),
                  ),
                  Positioned(
                    bottom: -8,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF735C00),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit, size: 16, color: Colors.white),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text('أحمد عبدالله', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1C))),
            ),
            const Center(
              child: Text('القاهرة، مصر', style: TextStyle(fontSize: 14, color: Color(0xFF707974))),
            ),
            const SizedBox(height: 32),

            // Adhan Notifications
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 16, offset: const Offset(0, 4))
                ]
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.notifications_active, color: Color(0xFF735C00), size: 24),
                          SizedBox(width: 8),
                          Text('تنبيهات الأذان', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1C))),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F2F1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text('تخصيص الكل', style: TextStyle(color: Color(0xFF1A1C1C), fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSwitchRow('الفجر', Icons.wb_twilight, true),
                  _buildSwitchRow('الظهر', Icons.wb_sunny_outlined, true),
                  _buildSwitchRow('العصر', Icons.light_mode_outlined, true),
                  _buildSwitchRow('المغرب', Icons.nightlight_round, true),
                  _buildSwitchRow('العشاء', Icons.nightlight_outlined, false, isLast: true),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Calculation Method
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 16, offset: const Offset(0, 4))
                ]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.calculate_outlined, color: Color(0xFF735C00)),
                      SizedBox(width: 8),
                      Text('طريقة الحساب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1C))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('تحديد زاوية الفجر والعشاء بناءً على الموقع الجغرافي.', style: TextStyle(color: Color(0xFF707974), fontSize: 14)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F2F1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('الهيئة العامة المصرية للمساحة', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1C1C))),
                        Icon(Icons.keyboard_arrow_down, color: Color(0xFF707974)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Language
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F4),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.language, color: Color(0xFF735C00)),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('اللغة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1C1C))),
                          Text('العربية (الأصلية)', style: TextStyle(color: Color(0xFF707974), fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF707974)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Theme
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F4),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.palette_outlined, color: Color(0xFF735C00)),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('المظهر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1C1C))),
                          Text('الوضع الفاتح', style: TextStyle(color: Color(0xFF707974), fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF003527),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.light_mode, size: 16, color: Colors.white),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.dark_mode, size: 16, color: Color(0xFF707974)),
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Contact Us
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF064E3B), Color(0xFF003527)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('تواصل معنا', style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'نسعد دائماً باستقبال اقتراحاتكم لتطوير تجربة تطبيق الفجر.',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE088),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.email, color: Color(0xFF241A00)),
                        SizedBox(width: 12),
                        Text('إرسال رسالة', style: TextStyle(color: Color(0xFF241A00), fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Logout
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5F5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFDAD6)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('تسجيل الخروج', style: TextStyle(color: Color(0xFFBA1A1A), fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(width: 12),
                  Icon(Icons.logout, color: Color(0xFFBA1A1A)),
                ],
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow(String title, IconData icon, bool isActive, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF707974), size: 24),
              const SizedBox(width: 16),
              Text(title, style: const TextStyle(fontSize: 16, color: Color(0xFF1A1C1C), fontWeight: FontWeight.bold)),
            ],
          ),
          Switch(
            value: isActive,
            onChanged: (val) {},
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF003527),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFE2E8E4),
            trackOutlineColor: MaterialStateProperty.all(Colors.transparent),
          )
        ],
      ),
    );
  }
}
