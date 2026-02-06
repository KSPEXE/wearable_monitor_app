import 'package:flutter/material.dart';
// Importamos la pantalla desde su nueva ubicación:
import 'package:wearable_monitor_app/presentation/dashboard_screen.dart'; 

void main() => runApp(const WearableApp());

class WearableApp extends StatelessWidget {
  const WearableApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      // Aquí llamamos a la clase Dashboard que ahora vive en el otro archivo
      home: const Dashboard(), 
    );
  }
}