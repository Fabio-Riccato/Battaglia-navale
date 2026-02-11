import 'package:flutter/material.dart';
import 'servizio_tcp.dart';
import 'schermata_gioco.dart';

class SchermataPosizionamento extends StatefulWidget {
  final ServizioTCP servizio;
  const SchermataPosizionamento({super.key, required this.servizio});

  @override
  State<SchermataPosizionamento> createState() =>
      _SchermataPosizionamentoState();
}

class _SchermataPosizionamentoState extends State<SchermataPosizionamento> {
  final flotta = [4, 3, 3, 2, 2, 2, 1, 1, 1, 1];
  int indice = 0;
  bool verticale = false;

  List<List<int>> navi = [];
  List<int> anteprima = [];

  void seleziona(int cella) {
    if (indice >= flotta.length) return;
    int r = cella ~/ 10;
    int c = cella % 10;
    final size = flotta[indice];

    if (verticale) {
      if (r + size > 10) r = 10 - size;
    } else {
      if (c + size > 10) c = 10 - size;
    }

    List<int> nuova = [];
    for (int i = 0; i < size; i++) {
      int nr = r + (verticale ? i : 0);
      int nc = c + (verticale ? 0 : i);
      nuova.add(nr * 10 + nc);
    }

    if (navi.expand((e) => e).any((pos) => nuova.contains(pos))) return;
    setState(() => anteprima = nuova);
  }

  void confermaNave() {
    if (anteprima.isEmpty) return;
    setState(() {
      navi.add(List.from(anteprima));
      anteprima.clear();
      indice++;
    });
  }

  void confermaTutto() {
    widget.servizio.inviaNavi(navi);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SchermataGioco(
          servizio: widget.servizio,
          mieNavi: navi,
        ),
      ),
    );
  }

  Future<void> _confermaUscita() async {
    final esci = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Uscire dal posizionamento?"),
        content: const Text("Se esci ora perderai la connessione alla partita."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("No"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Sì, esci", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (esci == true) {
      widget.servizio.abbandona();
      if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final finito = indice >= flotta.length;

    // FIX PROBLEMA 1: Anche qui preveniamo uscite accidentali
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _confermaUscita();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Posiziona le Navi')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Text(finito
                  ? 'Tutte le navi posizionate!'
                  : 'Posiziona nave da ${flotta[indice]} caselle'),
              const SizedBox(height: 10),
              SizedBox(
                width: 300,
                height: 300,
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 100,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 10),
                    itemBuilder: (_, i) {
                      Color colore = Colors.blue.shade50;
                      if (navi.expand((e) => e).contains(i)) colore = Colors.grey.shade700;
                      if (anteprima.contains(i)) colore = Colors.orange;

                      return GestureDetector(
                        onTap: () => seleziona(i),
                        child: Container(
                          margin: const EdgeInsets.all(1),
                          color: colore,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (!finito)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.rotate_right),
                      label: Text(verticale ? 'Verticale' : 'Orizzontale'),
                      onPressed: () => setState(() => verticale = !verticale),
                    ),
                    const SizedBox(width: 20),
                    ElevatedButton(
                      onPressed: anteprima.isEmpty ? null : confermaNave,
                      child: const Text('Conferma'),
                    ),
                  ],
                ),
              if (finito)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  onPressed: confermaTutto,
                  child: const Text('AVVIA PARTITA'),
                )
            ],
          ),
        ),
      ),
    );
  }
}



