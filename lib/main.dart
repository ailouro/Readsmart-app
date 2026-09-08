import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login_screen.dart';
import 'package:flutter/cupertino.dart';

void main() async {
  // Must be called before using platform channels or plugins
  WidgetsFlutterBinding.ensureInitialized();

  // Bump image cache to 150 MB (default is only ~100 MB) — fewer evictions
  PaintingBinding.instance.imageCache.maximumSizeBytes = 150 << 20;
  PaintingBinding.instance.imageCache.maximumSize = 1000;

  // Lock to portrait — avoids extra layout passes from orientation changes
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Transparent status bar so the app feels full-screen and native
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ReadSmartApp());
}

class ReadSmartApp extends StatelessWidget {
  const ReadSmartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ReadSmart',
      // ScrollBehavior: faster fling physics on all platforms
      scrollBehavior: const MaterialScrollBehavior(),
      theme: ThemeData(
        primaryColor: Colors.blue,
        useMaterial3: true,
        textTheme: GoogleFonts.fredokaTextTheme(Theme.of(context).textTheme),
        // Disable splash/highlight on buttons — removes jank on rapid taps
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        pageTransitionsTheme: PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
