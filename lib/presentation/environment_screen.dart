import 'package:flutter/material.dart';
import 'package:wearable_monitor_app/data/repositories/bluetooth_repository.dart';
import 'package:wearable_monitor_app/domain/entities/environment_data.dart';

class EnvironmentScreen extends StatefulWidget {
  final BluetoothRepository repository;

  const EnvironmentScreen({super.key, required this.repository});

  @override
  State<EnvironmentScreen> createState() => _EnvironmentScreenState();
}

class _EnvironmentScreenState extends State<EnvironmentScreen> {
  // Variables locales para reflejar el estado del cuarto
  bool puertaAbierta = false;
  bool luzDetectada = false;
  bool vibracion = false;
  bool rele1 = false;
  bool rele2 = false;

  @override
  void initState() {
    super.initState();
    // Escuchamos el stream del repositorio que ya es "dynamic"
    widget.repository.dataStream.listen((data) {
      if (!mounted) return;
      
      // FILTRO: Aquí solo nos interesan los datos de tipo EnvironmentData
      if (data is EnvironmentData) {
        setState(() {
          puertaAbierta = data.isDoorOpen;
          luzDetectada = data.isLightDetected;
          vibracion = data.isVibrationDetected;
          rele1 = data.isRelay1On;
          rele2 = data.isRelay2On;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Control de Habitación"),
        backgroundColor: Colors.cyanAccent.withValues(alpha: 0.1),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // TARJETAS DE ESTADO DE SENSORES
            _buildSensorTile(
              "Puerta", 
              puertaAbierta ? "ABIERTA" : "Cerrada", 
              puertaAbierta ? Colors.red : Colors.green, 
              Icons.door_sliding
            ),
            const SizedBox(height: 15),
            _buildSensorTile(
              "Iluminación", 
              luzDetectada ? "Luz Detectada" : "Oscuridad", 
              Colors.orange, 
              Icons.wb_sunny
            ),
            const SizedBox(height: 15),
            _buildSensorTile(
              "Vibración", 
              vibracion ? "¡ALERTA!" : "Normal", 
              vibracion ? Colors.redAccent : Colors.blueGrey, 
              Icons.vibration
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Divider(color: Colors.white24),
            ),

            const Text("INTERRUPTORES DE RELÉS", 
              style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 20),

            // BOTONES PARA CONTROLAR LOS RELÉS
            Row(
              children: [
                Expanded(child: _buildRelayButton("Luz Techo", rele1, "1")),
                const SizedBox(width: 15),
                Expanded(child: _buildRelayButton("Ventilador", rele2, "2")),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorTile(String titulo, String valor, Color color, IconData icono) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icono, color: color, size: 30),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              Text(valor, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRelayButton(String nombre, bool estado, String comando) {
    return InkWell(
      onTap: () => widget.repository.enviarDatos(comando),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: estado ? Colors.cyanAccent : Colors.grey[900],
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.power_settings_new, color: estado ? Colors.black : Colors.white54),
            const SizedBox(height: 8),
            Text(nombre, style: TextStyle(color: estado ? Colors.black : Colors.white)),
            Text(estado ? "ENCENDIDO" : "APAGADO", 
              style: TextStyle(color: estado ? Colors.black54 : Colors.white38, fontSize: 10)
            ),
          ],
        ),
      ),
    );
  }
}