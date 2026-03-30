import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PrayerTimesPage extends ConsumerWidget {
  const PrayerTimesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            // Qibla Header
            const Center(
              child: Text('اتجاه القبلة', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1C))),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text('حدد اتجاه صلاتك بدقة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF707974))),
            ),
            const SizedBox(height: 32),
            
            // Compass Area
            Center(
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF0F2F1),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 10))
                      ]
                    ),
                    child: Center(
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF003527),
                        ),
                        child: Stack(
                          children: [
                            // N E W S indicators
                            const Positioned(top: 16, left: 0, right: 0, child: Center(child: Text('N', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)))),
                            const Positioned(bottom: 16, left: 0, right: 0, child: Center(child: Text('S', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)))),
                            const Positioned(right: 16, top: 0, bottom: 0, child: Center(child: Text('E', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)))),
                            const Positioned(left: 16, top: 0, bottom: 0, child: Center(child: Text('W', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)))),
                            
                            // Center compass needle
                            Center(
                              child: Transform.rotate(
                                angle: 1.0, // Arbitrary angle for preview
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(width: 4, height: 180, color: const Color(0xFFFFE088)),
                                    const Positioned(
                                      top: 10,
                                      child: CircleAvatar(radius: 12, backgroundColor: Color(0xFFFFE088)),
                                    ),
                                    const Positioned(
                                      bottom: 10,
                                      child: CircleAvatar(radius: 12, backgroundColor: Color(0xFFFFE088)),
                                    ),
                                    Container(
                                      width: 40, height: 40,
                                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFFE088), width: 3), color: const Color(0xFF003527)),
                                      child: const Center(child: Icon(Icons.explore, color: Color(0xFFFFE088), size: 20)),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 8))
                        ]
                      ),
                      child: Row(
                        children: [
                          const Text('أنت في الاتجاه الصحيح', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(width: 12),
                          Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF735C00))),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 60),

            // Prayer Times Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: const [
                Text('مواقيت الصلاة اليوم', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1C))),
                Text('الجمعة، ١٥ رمضان', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF707974))),
              ],
            ),
            const SizedBox(height: 20),

            // Prayer List
            _buildPrayerTimeTile(name: 'الفجر', time: '04:12 ص', icon: Icons.wb_twilight, isActive: true),
            _buildPrayerTimeTile(name: 'الظهر', time: '12:05 م', icon: Icons.wb_sunny_outlined, isDone: true),
            _buildPrayerTimeTile(name: 'العصر', time: '03:32 م', icon: Icons.light_mode_outlined, isDone: true, isCheckGold: true),
            _buildPrayerTimeTile(name: 'المغرب', time: '06:14 م', icon: Icons.nightlight_round),
            _buildPrayerTimeTile(name: 'العشاء', time: '07:44 م', icon: Icons.nightlight_outlined),

            const SizedBox(height: 24),
            
            // Location Area
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F2F1),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Row(
                children: [
                  const Icon(Icons.my_location, color: Color(0xFF1A1C1C), size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('الموقع الحالي: القاهرة، مصر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A1C1C))),
                        SizedBox(height: 4),
                        Text('يتم تحديث المواقيت تلقائياً حسب موقعك', style: TextStyle(fontSize: 12, color: Color(0xFF707974))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text('تغيير', style: TextStyle(color: Color(0xFF735C00), fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerTimeTile({
    required String name,
    required String time,
    required IconData icon,
    bool isActive = false,
    bool isDone = false,
    bool isCheckGold = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF003527) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: isActive ? [] : [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 16, offset: const Offset(0, 4))
        ]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white.withOpacity(0.1) : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: isActive ? Colors.white : const Color(0xFF1A1C1C), size: 28),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('صلاة $name', style: TextStyle(color: isActive ? Colors.white70 : const Color(0xFF707974), fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(time, style: TextStyle(color: isActive ? Colors.white : const Color(0xFF1A1C1C), fontSize: 24, fontWeight: FontWeight.w900)),
                ],
              ),
            ],
          ),
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE088),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('الحالية', style: TextStyle(color: Color(0xFF241A00), fontWeight: FontWeight.w800, fontSize: 14)),
            )
          else
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isCheckGold ? const Color(0xFF735C00) : const Color(0xFFBFC9C3), width: 2),
                color: isCheckGold ? const Color(0xFF735C00) : Colors.transparent,
              ),
              child: isDone ? Icon(Icons.check, size: 20, color: isCheckGold ? Colors.white : const Color(0xFFBFC9C3)) : null,
            )
        ],
      ),
    );
  }
}
