import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/model_boot_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));
  runApp(const AgentPhoneApp());
}

class AgentPhoneApp extends StatelessWidget {
  const AgentPhoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgentPhone',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF00695C),
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF5F7F6),
      ),
      // يُطبَّق على كل المسارات (بما فيها شاشة المحادثة بعد Navigator.push)
      builder: (BuildContext context, Widget? child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const ModelBootScreen(),
    );
  }
}
