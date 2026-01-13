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
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
        ),
      ),
      home: const PaginaIniziale(),
    );
  }
}
