import 'package:flutter/material.dart';
import 'servizio_tcp.dart';
import 'schermata_posizionamento.dart';
import 'schermata_gioco.dart';

class PaginaIniziale extends StatefulWidget {
  const PaginaIniziale({super.key});

  @override
  State<PaginaIniziale> createState() => _PaginaInizialeState();
}

class _PaginaInizialeState extends State<PaginaIniziale> {
  final ServizioTCP servizio = ServizioTCP();
  bool inAttesa = false;

  Future<void> avviaPartita() async {
    bool connesso = await servizio.connetti();

    if (!connesso) {
      mostraErrore();
      return;
    }

    // Vai alla schermata di posizionamento
    final List<int>? naviPosizionate = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SchermataPosizionamento(servizio: servizio),
      ),
    );

    // Se l'utente torna indietro senza confermare
    if (naviPosizionate == null) return;

    // Vai alla schermata di gioco
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SchermataGioco(
          servizio: servizio,
          mieNavi: naviPosizionate,
        ),
      ),
    );
  }

  void mostraErrore() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Errore'),
        content: const Text('Connessione al server non riuscita'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.black
          : Colors.white,
      appBar: AppBar(
        title: const Text('Battaglia Navale'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(
              horizontal: 30,
              vertical: 15,
            ),
          ),
          onPressed: avviaPartita,
          child: const Text(
            'Inizia la partita',
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}

