import 'package:cacao_scan/providers/auth_provider.dart';
import 'package:cacao_scan/providers/auth_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'CacaoScan',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme:
              ColorScheme.fromSeed(
                seedColor: const Color(0xFF6F3D20),
                brightness: Brightness.light,
              ).copyWith(
                primary: const Color(0xFF6F3D20),
                secondary: const Color(0xFFD7902F),
                tertiary: const Color(0xFF6C7F35),
                surface: const Color(0xFFFFF7E8),
              ),
          scaffoldBackgroundColor: const Color(0xFFF8EBD2),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF4A2817),
            foregroundColor: Color(0xFFFFF8EA),
            centerTitle: true,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFFFFF7E8),
            elevation: 1,
            shadowColor: const Color(0xFF3A1F12).withValues(alpha: 0.18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Color(0xFFE2C793)),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6F3D20),
              foregroundColor: const Color(0xFFFFF8EA),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF5A321C),
              side: const BorderSide(color: Color(0xFF8D6338)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          sliderTheme: const SliderThemeData(
            activeTrackColor: Color(0xFFD7902F),
            thumbColor: Color(0xFF6F3D20),
            inactiveTrackColor: Color(0xFFE2C793),
          ),
          switchTheme: SwitchThemeData(
            thumbColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.selected)
                  ? const Color(0xFFD7902F)
                  : const Color(0xFF8D6338);
            }),
            trackColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.selected)
                  ? const Color(0xFF6F3D20).withValues(alpha: 0.42)
                  : const Color(0xFFE2C793);
            }),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFFFFBF2),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF6F3D20), width: 2),
            ),
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}
