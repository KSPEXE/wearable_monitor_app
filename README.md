# Wearable Monitor App - Salud & Domótica 🚀

Este proyecto consiste en una aplicación móvil multiplataforma desarrollada en **Flutter** para el monitoreo de signos vitales y control domótico mediante comunicación Bluetooth con microcontroladores ESP32.

##  Características Principales
* **Monitoreo de Salud:** Visualización en tiempo real de frecuencia cardíaca (BPM), temperatura corporal y detección de caídas mediante acelerometría.
* **Control de Entorno:** Gestión de sensores de seguridad (puerta, luz, vibración) y accionamiento de relés para domótica.
* **Comunicación Robusta:** Intercambio de datos estructurados mediante el formato **JSON** con clasificación dinámica de tramas.
* **Arquitectura Limpia:** Implementación basada en **Clean Architecture** (Domain, Data & Presentation) para asegurar la escalabilidad del software.

##  Tecnologías Utilizadas
* **Lenguaje:** Dart 3.0 .
* **Framework:** Flutter .
* **Comunicación:** Bluetooth Serial (SPP) mediante la librería `flutter_bluetooth_serial` .
* **Gráficas:** `fl_chart` para renderizado pletismográfico en tiempo real.

##  Estructura del Proyecto
El código se organiza siguiendo principios de arquitectura limpia:
* [cite_start]`lib/domain`: Entidades de negocio (`SensorData`, `EnvironmentData`).
* [cite_start]`lib/data`: Repositorios y lógica de comunicación (`BluetoothRepository`).
* [cite_start]`lib/presentation`: Pantallas de usuario y widgets reactivos (`Dashboard`, `EnvironmentScreen`).

##  Configuración
Para replicar este proyecto:
1. Asegúrese de tener instalado el SDK de Flutter.
2. Ejecute `flutter pub get` para instalar las dependencias.
3. Conecte un dispositivo Android para la comunicación Bluetooth Serial.
