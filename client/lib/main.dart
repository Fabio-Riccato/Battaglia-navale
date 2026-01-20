import 'package:flutter/material.dart';
import 'pagina_iniziale.dart';


void main() {
  runApp(const BattagliaNavaleApp());
}

class BattagliaNavaleApp extends StatelessWidget {
  const BattagliaNavaleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Battaglia Navale',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const PaginaIniziale(),
    );
  }
}