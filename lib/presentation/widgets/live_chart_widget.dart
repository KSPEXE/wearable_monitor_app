import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/sensor_data.dart';

class LiveChartWidget extends StatefulWidget {
  final Stream<dynamic> stream;

  const LiveChartWidget({super.key, required this.stream});

  @override
  State<LiveChartWidget> createState() => _LiveChartWidgetState();
}

class _LiveChartWidgetState extends State<LiveChartWidget> {
  final List<FlSpot> _puntos = [];
  double _xValue = 0;
  // Suscripción interna solo para este widget
  StreamSubscription? _subscription; 

 @override
void initState() {
  super.initState();
  _subscription = widget.stream.listen((data) {
    // FILTRO: Solo graficamos si el dato es de la pulsera
    if (mounted && data is SensorData) {
      setState(() {
        _puntos.add(FlSpot(_xValue, data.irValue / 1000));
        if (_puntos.length > 50) _puntos.removeAt(0);
        _xValue++;
      });
    }
  });
}

  @override
  void dispose() {
    _subscription?.cancel(); // Vital cancelar para no fugar memoria
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          lineTouchData: const LineTouchData(enabled: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: _puntos,
              isCurved: true,
              color: Colors.redAccent,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: Colors.red.withOpacity(0.1)),
            ),
          ],
        ),
      ),
    );
  }
}