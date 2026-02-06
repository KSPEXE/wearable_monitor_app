import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

// TUS IMPORTS DE ARQUITECTURA (Asegúrate que el nombre 'wearable_monitor' sea correcto según tu pubspec.yaml)
import 'package:wearable_monitor_app/domain/entities/sensor_data.dart';
import 'package:wearable_monitor_app/data/repositories/bluetooth_repository.dart';
// ... otros imports ...
import 'package:wearable_monitor_app/presentation/widgets/live_chart_widget.dart'; // <--- AGREGAR ESTO
import 'package:wearable_monitor_app/presentation/environment_screen.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {

  // --- SISTEMA ---
  final BluetoothRepository _bluetoothRepo = BluetoothRepository(); // NUEVO
  bool isConnecting = false;
  // --- CONFIGURACIÓN DE ALERTAS ---
  String nombreUsuario = "Cargando...";
  bool modoNocturno = false;
  double umbralFiebre = 38.0; // Se envía al ESP32
  double umbralCaida = 3.0;   // Se procesa en la App

  // --- SENSORES ---
  String estado = "Desconectado";
  String ultimoEstado = "Desconectado"; 
  double temperatura = 0.0;
  double aceleracion = 0.0;
  double promedioIR = 0.0; 
  int pasos = 0;
  int bpm = 0;

  // --- LÓGICA DE DETECCIÓN Y FLAGS ---
  DateTime? lastBeat;
  bool _posiblePaso = false;
  
  // Caída
  bool posibleCaida = false;
  DateTime? tiempoImpacto;
  
  // Inactividad
  DateTime ultimaActividad = DateTime.now();
  bool alertaInactividadEnviada = false;
  bool alertaFiebreMostrada = false;

  // --- CLIMA ---
  double tempQuito = 15.0;
  double presionQuito = 720.0;
  String sugerenciaClima = "Analizando entorno...";

  

  // --- CONTROLADORES TEXTO ---
  final TextEditingController _controllerNombre = TextEditingController();
  final TextEditingController _controllerEdad = TextEditingController();
  final TextEditingController _controllerTutor = TextEditingController();
  final TextEditingController _controllerTelefono = TextEditingController();

  @override
  void initState() {
    super.initState();
    _solicitarPermisos();
    _cargarPerfil();
    _comprobarRegistro();
    _obtenerClima();
    
    // Timer: Revisa inactividad cada 10 segundos
    Timer.periodic(const Duration(seconds: 10), (timer) {
      _verificarInactividad();
    });
  }

  // -----------------------------------------------------------------------
  //                        BLUETOOTH & CONEXIÓN
  // -----------------------------------------------------------------------

  Future<void> _solicitarPermisos() async {
    await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();
  }

  void _abrirSelectorDispositivos() async {
    List<BluetoothDevice> bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Conectar Pulsera"),
          content: SizedBox(
            width: double.maxFinite,
            child: bondedDevices.isEmpty 
              ? const Text("No hay dispositivos vinculados. Ve a los ajustes de Bluetooth y vincula 'PSL_V1'.")
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: bondedDevices.length,
                  itemBuilder: (context, index) {
                    BluetoothDevice device = bondedDevices[index];
                    return ListTile(
                      title: Text(device.name ?? "Desconocido"),
                      subtitle: Text(device.address),
                      leading: const Icon(Icons.watch),
                      trailing: const Icon(Icons.link),
                      onTap: () {
                        Navigator.pop(context);
                        _conectar(device);
                      },
                    );
                  },
                ),
          ),
        );
      },
    );
  }

  void _conectar(BluetoothDevice device) async {
    setState(() => isConnecting = true);
    
    try {
      // 1. Intentar conectar usando el repositorio
      await _bluetoothRepo.connect(device.address);
      
      setState(() {
        estado = "Conectado";
        isConnecting = false;
      });

      // 2. Escuchamos el flujo de datos dinámico
      _bluetoothRepo.dataStream.listen((data) {
        if (!mounted) return;

        // FILTRO DE SEGURIDAD: Solo procesamos si es dato de la Pulsera
        // ... dentro de _bluetoothRepo.dataStream.listen((data) { ...

          if (data is SensorData) {
            setState(() {
              estado = data.estado;
              temperatura = data.temperatura;
              aceleracion = data.aceleracion;
              
              // --- AQUÍ DEBES AGREGAR LA LLAMADA ---
              // Le pasamos el objeto 'data' para que calcule BPM y alertas
              _procesarDatosSensor(data); 
              // -------------------------------------
              
              if (temperatura >= umbralFiebre) {
                if (!alertaFiebreMostrada) {
                  alertaFiebreMostrada = true;
                  _mostrarAlertaFiebre();
                }
              } else {
                alertaFiebreMostrada = false;
              }
            });
          }
      }, onError: (error) {
        debugPrint("Error en el flujo de datos: $error");
        setState(() {
          estado = "Error de datos";
          isConnecting = false;
        });
      });

    } catch (e) {
      debugPrint("Error al conectar: $e");
      setState(() {
        estado = "Error de conexión";
        isConnecting = false;
      });
      // Mostrar SnackBar de error si deseas
    }
  } // Aquí termina la función _conectar

  // -----------------------------------------------------------------------
  //                  LÓGICA DE SENSORES Y ALERTAS (CEREBRO)
  // -----------------------------------------------------------------------

  // Esta función reemplaza a _procesarCSV
  void _procesarDatosSensor(SensorData data) {
    setState(() {
      ultimoEstado = estado;
      
      // Asignamos directamente desde el objeto (¡Ya no hay que parsear texto!)
      String estadoRecibido = data.estado;
      temperatura = data.temperatura;
      double rawIR = data.irValue;
      aceleracion = data.aceleracion;

      // --- A PARTIR DE AQUÍ ES TU MISMA LÓGICA ORIGINAL ---

      // 1. REDUNDANCIA DE FIEBRE
      bool fiebreDetectadaLocal = temperatura >= umbralFiebre;
      if (fiebreDetectadaLocal) {
        estado = "ALERTA";
        if (!alertaFiebreMostrada) {
          alertaFiebreMostrada = true;
          _mostrarAlertaFiebre();
        }
      } else {
         alertaFiebreMostrada = false;
         estado = estadoRecibido;
      }

      // 2. PÁNICO
      if (estado == "PANICO" && ultimoEstado != "PANICO") {
         _llamarTutor();
      }

      // 3. INACTIVIDAD
      if ((aceleracion - 1.0).abs() > 0.1) {
        ultimaActividad = DateTime.now();
        alertaInactividadEnviada = false; 
      }

      // 4. LÓGICA DE CAÍDAS
      if (aceleracion > umbralCaida && !posibleCaida) {
        posibleCaida = true;
        tiempoImpacto = DateTime.now();
      }
      if (posibleCaida && tiempoImpacto != null && DateTime.now().difference(tiempoImpacto!).inSeconds > 5) {
        if (aceleracion > 0.9 && aceleracion < 1.1) {
          _mostrarAlertaCaida();
          posibleCaida = false; 
        } else {
          posibleCaida = false;
        }
      }

      // 5. GRÁFICA & BPM
      if (promedioIR == 0) promedioIR = rawIR;
      promedioIR = (promedioIR * 0.95) + (rawIR * 0.05);
      double valorFiltrado = rawIR - promedioIR;

      if (valorFiltrado > 50 && rawIR > 40000) {
         DateTime ahora = DateTime.now();
         if (lastBeat != null) {
           int diferencia = ahora.difference(lastBeat!).inMilliseconds;
           if (diferencia > 240 && diferencia < 1500) {
             int nuevoBPM = 60000 ~/ diferencia;
             bpm = ((bpm * 0.7) + (nuevoBPM * 0.3)).toInt();
           }
         }
         if (lastBeat == null || ahora.difference(lastBeat!).inMilliseconds > 200) {
            lastBeat = ahora;
         }
      }

      if (rawIR < 40000) { 
        bpm = 0; promedioIR = 0;
      } else {
        
      }
      
      // 6. PASOS
      if (aceleracion > 1.25 && !_posiblePaso) {
        pasos++; _posiblePaso = true;
      } else if (aceleracion < 1.10) {
        _posiblePaso = false;
      }
    });
  }

  void _verificarInactividad() {
    if (DateTime.now().difference(ultimaActividad).inSeconds > 60 && !alertaInactividadEnviada) {
      if (estado != "Desconectado" && estado != "SIN_PULSO") {
        alertaInactividadEnviada = true;
        _mostrarNotificacionLocal("🟡 Inactividad Detectada", "El paciente no se ha movido en 1 minuto.");
      }
    }
  }

  // -----------------------------------------------------------------------
  //                        ALERTAS Y POP-UPS
  // -----------------------------------------------------------------------

  void _mostrarAlertaFiebre() {
    HapticFeedback.mediumImpact();
    // WidgetsBinding asegura que el diálogo se abra sin romper el ciclo de dibujo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.orange.shade900,
          title: const Row(children: [Icon(Icons.local_fire_department, color: Colors.white), SizedBox(width: 10), Text("ALERTA DE FIEBRE", style: TextStyle(color: Colors.white))]),
          content: Text("La temperatura ($temperatura°C) superó el límite de $umbralFiebre°C.", style: const TextStyle(color: Colors.white)),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("ENTENDIDO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))],
        ),
      );
    });
  }

  void _mostrarAlertaCaida() {
    HapticFeedback.heavyImpact();
    _llamarTutor(); 
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red.shade900,
        title: const Row(children: [Icon(Icons.warning, color: Colors.yellow), SizedBox(width: 10), Text("¡CAÍDA DETECTADA!", style: TextStyle(color: Colors.white))]),
        content: const Text("Impacto fuerte e inmovilidad detectada.", style: TextStyle(color: Colors.white)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("CERRAR", style: TextStyle(color: Colors.white)))],
      ),
    );
  }

  void _mostrarNotificacionLocal(String titulo, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [const Icon(Icons.info_outline, color: Colors.black), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(titulo, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), Text(mensaje, style: const TextStyle(color: Colors.black87))]))]),
        backgroundColor: Colors.yellowAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      )
    );
  }

  void _mostrarConfiguracionUmbrales() {
    showDialog(
      context: context,
      builder: (context) {
        double tempSel = umbralFiebre;
        double caidaSel = umbralCaida;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Configuración de Alertas"),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Row(children: [Icon(Icons.thermostat, color: Colors.orange), SizedBox(width: 5), Text("Fiebre (>C)")]),
                  Slider(value: tempSel, min: 20.0, max: 40.0, divisions: 20, label: "${tempSel.toStringAsFixed(1)}°C", activeColor: Colors.orange, onChanged: (val) => setStateDialog(() => tempSel = val)),
                  const Divider(),
                  const Row(children: [Icon(Icons.personal_injury, color: Colors.red), SizedBox(width: 5), Text("Sensibilidad Caída (>G)")]),
                  Slider(value: caidaSel, min: 2.0, max: 5.0, divisions: 6, label: "${caidaSel.toStringAsFixed(1)}G", activeColor: Colors.red, onChanged: (val) => setStateDialog(() => caidaSel = val)),
                  const Text("2.0G = Muy Sensible | 5.0G = Poco Sensible", style: TextStyle(fontSize: 10, color: Colors.grey)),
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
                ElevatedButton(onPressed: () {
                    setState(() { umbralFiebre = tempSel; umbralCaida = caidaSel; });
                    // --- ESTO ES LO NUEVO ---
                    // Enviamos "T38.5" (o el valor que sea) usando el método que acabamos de crear
                    _bluetoothRepo.enviarDatos("T${tempSel.toStringAsFixed(1)}");
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Configuración guardada")));
                }, child: const Text("Guardar")),
              ],
            );
          },
        );
      },
    );
  }

  // -----------------------------------------------------------------------
  //                        UI PRINCIPAL
  // -----------------------------------------------------------------------
@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: modoNocturno ? Colors.black : const Color(0xFF0F172A),
      // 1. DRAWER
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(nombreUsuario),
              accountEmail: const Text("Monitor Activo"),
              currentAccountPicture: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, color: Colors.black)),
              decoration: BoxDecoration(color: Colors.blue.shade900),
            ),
            ListTile(leading: const Icon(Icons.edit), title: const Text("Editar Perfil"), onTap: _mostrarDialogoPerfil),
            ListTile(leading: const Icon(Icons.bluetooth), title: const Text("Conectar"), onTap: () { Navigator.pop(context); _abrirSelectorDispositivos(); }),
            ListTile(leading: const Icon(Icons.settings, color: Colors.orange), title: const Text("Alertas"), onTap: () { Navigator.pop(context); _mostrarConfiguracionUmbrales(); }),
            ListTile(
        leading: const Icon(Icons.description, color: Colors.green),
        title: const Text("Exportar Reporte CSV"),
        onTap: () {
          Navigator.pop(context); // Cierra el menú
          _exportarDatos();       // LLAMADA A LA FUNCIÓN
        },
      ),
          ],
        ),
      ),
      // 2. APPBAR
      appBar: AppBar(
        title: Text(nombreUsuario),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: Icon(isConnecting ? Icons.bluetooth_audio : Icons.bluetooth_searching, color: Colors.blueAccent), onPressed: _abrirSelectorDispositivos),
        ],
      ),
      // 3. BODY
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Estado
            Container(
              margin: const EdgeInsets.all(15),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: (estado == "PANICO" ? Colors.red : estado == "ALERTA" ? Colors.orange : Colors.green).withOpacity(0.2),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("ESTADO", style: TextStyle(color: Colors.white54, fontSize: 10)), Text(estado, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))]),
                  Icon(estado == "PANICO" ? Icons.warning : Icons.check_circle, color: Colors.white, size: 40),
                ],
              ),
            ),
            // Gráfica
            _buildGraficaSeccion(),
            // Grid de Sensores
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _sensorTileMedico("FRECUENCIA", "$bpm", "BPM", Icons.favorite),
                  _sensorTile("Temperatura", "${temperatura.toStringAsFixed(1)}°C", Icons.thermostat, Colors.orangeAccent),
                  _sensorTile("Pasos", "$pasos", Icons.directions_walk, Colors.blueAccent),
                  _sensorTile("Impacto", "${aceleracion.toStringAsFixed(2)}G", Icons.bolt, Colors.yellowAccent),
                ],
              ),
            ),
            // Botón SOS
            Padding(
              padding: const EdgeInsets.all(15),
              child: ElevatedButton.icon(
                onPressed: _llamarTutor,
                icon: const Icon(Icons.emergency, color: Colors.white),
                label: const Text("SOS - LLAMAR"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, minimumSize: const Size(double.infinity, 50)),
              ),
            ),
          ],
        ),
      ),
      // 4. BOTÓN FLOTANTE (ESTA ES LA PROPIEDAD QUE DEBE IR AQUÍ)
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EnvironmentScreen(repository: _bluetoothRepo),
            ),
          );
        },
        label: const Text("Controles Cuarto"),
        icon: const Icon(Icons.home_work),
        backgroundColor: Colors.cyanAccent,
        foregroundColor: Colors.black,
      ),
    ); // <--- ESTE ES EL CIERRE DEL SCAFFOLD
  }

  // -----------------------------------------------------------------------
  //                        WIDGETS Y UTILIDADES
  // -----------------------------------------------------------------------

  Widget _sensorTileMedico(String l, String v, String u, IconData i) { return Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 4))]), child: Stack(children: [Positioned(right: -10, top: -10, child: Icon(i, size: 80, color: Colors.red.withOpacity(0.05))), Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(i, color: Colors.redAccent, size: 20), const SizedBox(width: 5), Text(l, style: const TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.bold))]), const Spacer(), Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(v, style: const TextStyle(color: Colors.black87, fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'Courier')), const SizedBox(width: 5), Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(u, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)))])]))])); }
  
  Widget _sensorTile(String t, String v, IconData i, Color c) { return Container(decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.1))), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(i, color: c, size: 28), const SizedBox(height: 8), Text(t, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)), Text(v, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))])); }
  
  Widget _buildGraficaSeccion() {
    return Container(
      height: 250,
      margin: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white24),
        boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.1), blurRadius: 15)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Encabezado (Título y LIVE)
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(Icons.monitor_heart_outlined, color: Colors.white70, size: 20),
                    SizedBox(width: 8),
                    Text("GRÁFICA DE PPM", style: TextStyle(color: Colors.white, fontSize: 12))
                  ]),
                  Text("LIVE", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold))
                ],
              ),
              const SizedBox(height: 15),

              // AQUÍ ESTÁ EL CAMBIO IMPORTANTE:
              // Usamos el widget optimizado y le pasamos el stream del repo
              Expanded(
                child: LiveChartWidget(
                  stream: _bluetoothRepo.dataStream
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _obtenerClima() async { try { final r = await http.get(Uri.parse("https://api.openweathermap.org/data/2.5/weather?lat=-0.1807&lon=-78.4678&appid=bd5e378503939ddaee76f12ad7a97608&units=metric")); if (r.statusCode == 200) { final d = json.decode(r.body); if(mounted) setState(() { tempQuito = (d['main']['temp'] as num).toDouble(); presionQuito = (d['main']['pressure'] as num).toDouble(); if(presionQuito < 715) sugerenciaClima = "Presión baja"; else if(tempQuito < 14) sugerenciaClima = "Frío: Riesgo hipotermia"; else sugerenciaClima = "Estable"; }); } } catch (e) { debugPrint("Clima error: $e"); } }
  
  Future<void> _cargarPerfil() async { final p = await SharedPreferences.getInstance(); if(mounted) setState(() => nombreUsuario = p.getString('nombre') ?? "Nuevo Usuario"); }
  Future<void> _comprobarRegistro() async { final p = await SharedPreferences.getInstance(); if (p.getString('nombre') == null) WidgetsBinding.instance.addPostFrameCallback((_) => _mostrarDialogoPerfil()); }
  void _mostrarDialogoPerfil() async { final p = await SharedPreferences.getInstance(); if (!mounted) return; _controllerNombre.text = p.getString('nombre') ?? ""; _controllerEdad.text = p.getString('edad') ?? ""; _controllerTutor.text = p.getString('tutor') ?? ""; _controllerTelefono.text = p.getString('telefono') ?? ""; showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Perfil"), content: SingleChildScrollView(child: Column(children: [TextField(controller: _controllerNombre, decoration: const InputDecoration(labelText: "Paciente")), TextField(controller: _controllerEdad, decoration: const InputDecoration(labelText: "Edad")), TextField(controller: _controllerTutor, decoration: const InputDecoration(labelText: "Tutor")), TextField(controller: _controllerTelefono, decoration: const InputDecoration(labelText: "Teléfono"))])), actions: [ElevatedButton(onPressed: () async { await p.setString('nombre', _controllerNombre.text); await p.setString('edad', _controllerEdad.text); await p.setString('tutor', _controllerTutor.text); await p.setString('telefono', _controllerTelefono.text); if(mounted) setState(() => nombreUsuario = _controllerNombre.text); Navigator.pop(context); }, child: const Text("Guardar"))])); }
  
  Future<void> _llamarTutor() async { final p = await SharedPreferences.getInstance(); String? t = p.getString('telefono'); if (t != null) launchUrl(Uri(scheme: 'tel', path: t)); }
  Future<void> _exportarDatos() async { try { final d = await getExternalStorageDirectory(); final f = File('${d?.path}/reporte.csv'); await f.writeAsString("Fecha,Estado,Temp,BPM,Pasos\\n${DateTime.now()},$estado,$temperatura,$bpm,$pasos"); if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Guardado: ${f.path}"))); } catch(e) { debugPrint("Error export: $e"); } }



@override
  void dispose() {
    // 1. Cerramos la conexión Bluetooth y el Stream limpiamente
    _bluetoothRepo.dispose(); 
    
    // 2. Liberamos la memoria de los controladores de texto
    _controllerNombre.dispose();
    _controllerEdad.dispose();
    _controllerTutor.dispose();
    _controllerTelefono.dispose();
    
    // 3. Llamamos al dispose del padre (obligatorio)
    super.dispose();
  }


}