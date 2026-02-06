import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; 
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
// Asegúrate de que estos archivos existan en tus carpetas:
import '../../domain/entities/sensor_data.dart';
import '../../domain/entities/environment_data.dart';

class BluetoothRepository {
  BluetoothConnection? _connection;
  
  // 1. Definimos el controlador
  final _dataController = StreamController<dynamic>.broadcast();
  List<int> _buffer = []; 

  // 2. ESTA ES LA LÍNEA QUE TE FALTA O NO SE GUARDÓ:
  Stream<dynamic> get dataStream => _dataController.stream;

  Future<void> connect(String address) async {
    try {
      _connection = await BluetoothConnection.toAddress(address);
      _connection!.input!.listen((Uint8List data) {
        _buffer.addAll(data);
        while (_buffer.contains(10)) { 
          int index = _buffer.indexOf(10);
          List<int> lineaBytes = _buffer.sublist(0, index);
          _buffer = _buffer.sublist(index + 1);

          try {
            String rawJson = utf8.decode(lineaBytes).trim();
            if (rawJson.startsWith('{') && rawJson.endsWith('}')) {
              final map = jsonDecode(rawJson);
              if (map.containsKey('type') && map['type'] == 'ENV') {
                _dataController.add(EnvironmentData.fromJson(map));
              } else {
                _dataController.add(SensorData.fromJson(map));
              }
            }
          } catch (e) {
            debugPrint("Error JSON: $e");
          }
        }
      });
    } catch (e) {
      debugPrint("Error conexión: $e");
      rethrow;
    }
  }

  Future<void> enviarDatos(String datos) async {
    if (_connection != null && _connection!.isConnected) {
      _connection!.output.add(Uint8List.fromList(utf8.encode("$datos\n"))); 
      await _connection!.output.allSent;
    }
  }

  void dispose() {
    _dataController.close();
    _connection?.dispose();
  }
}