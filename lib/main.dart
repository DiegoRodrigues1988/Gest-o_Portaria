import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'screens/dashboard_screen.dart';
import 'screens/encomendas_screen.dart';
import 'screens/login_screen.dart';
import 'screens/moradores_screen.dart';
import 'screens/porteiros_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop SQLite support (Windows)
  if (Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const GestaoPortariaApp());
}

class GestaoPortariaApp extends StatelessWidget {
  const GestaoPortariaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gestão de Portaria',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
      ),
      home: const LoginScreen(),
      routes: {
        LoginScreen.routeName: (context) => const LoginScreen(),
        DashboardScreen.routeName: (context) => const DashboardScreen(),
        EncomendasScreen.routeName: (context) => const EncomendasScreen(),
        MoradoresScreen.routeName: (context) => const MoradoresScreen(),
        PorteirosScreen.routeName: (context) => const PorteirosScreen(),
      },
    );
  }
}
