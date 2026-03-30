import 'package:flutter/material.dart';

/// Azkar and Tasbeeh counter page.
///
/// Features:
/// - Browse categorized Azkar (Morning, Evening, Tasbeeh)
/// - Smart Tasbeeh counter with haptic feedback
/// - Offline access to all Azkar
class AzkarPage extends StatefulWidget {
  const AzkarPage({Key? key}) : super(key: key);

  @override
  State<AzkarPage> createState() => _AzkarPageState();
}

class _AzkarPageState extends State<AzkarPage> {
  int _counter = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Azkar & Tasbeeh')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'الأذكار و التسبيح',
              textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            const Text('Azkar Feature Coming Soon'),
            const SizedBox(height: 16),
            Text(
              'This page will display:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '• Morning and Evening Azkar\n'
                '• Smart Tasbeeh counter\n'
                '• Haptic feedback on tap\n'
                '• Offline access\n'
                '• Category filtering',
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Demo Counter: $_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() => _counter++),
              child: const Text('Increment'),
            ),
          ],
        ),
      ),
    );
  }
}
