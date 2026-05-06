import 'package:amgeca/providers/auth_provider.dart';
import 'package:amgeca/providers/auth_wrapper.dart';
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
        title: 'MoniliaScan',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
          scaffoldBackgroundColor: const Color(0xFFF6F8F2),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}
