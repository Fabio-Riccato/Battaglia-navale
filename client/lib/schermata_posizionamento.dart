import 'package:flutter/material.dart';
import 'servizio_tcp.dart';
import 'nave.dart';

class SchermataPosizionamento extends StatefulWidget {
  final ServizioTCP servizio;

  const SchermataPosizionamento({super.key, required this.servizio});

  @override
  State<SchermataPosizionamento> createState() =>
      _SchermataPosizionamentoState();
}

class _SchermataPosizionamentoState
    extends State<SchermataPosizionamento> {
  final List<Nave> flotta = [
    Nave(4),
    Nave(3),
    Nave(3),
    Nave(2),
    Nave(2),
    Nave(2),
    Nave(1),
    Nave(1),
    Nave(1),
    Nave(1),
  ];

  int naveCorrente = 0;
  bool verticale = false;
  Set<int> celleOccupate = {};

  void ruotaNave() {
    setState(() {
      verticale = !verticale;
    });
  }

  void piazzaNave(int cella) {
    if (naveCorrente >= flotta.length) return;

    int riga = cella ~/ 10;
    int colonna = cella % 10;
    int lunghezza = flotta[naveCorrente].lunghezza;

    List<int> celleDaOccupare = [];

    for (int i = 0; i < lunghezza; i++) {
      int r = verticale ? riga + i : riga;
      int c = verticale ? colonna : colonna + i;

      if (r > 9 || c > 9) return;

      int index = r * 10 + c;
      if (celleOccupate.contains(index)) return;

      celleDaOccupare.add(index);
    }

    setState(() {
      flotta[naveCorrente].celle = celleDaOccupare;
      celleOccupate.addAll(celleDaOccupare);
      naveCorrente++;
    });
  }

  void confermaPosizioni() {
    if (naveCorrente < flotta.length) return;

    widget.servizio.inviaNavi(
      flotta.map((n) => n.celle).toList(),
    );

    Navigator.pop(context, celleOccupate.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Posiziona le navi')),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Text(
            naveCorrente < flotta.length
                ? 'Posiziona nave da ${flotta[naveCorrente].lunghezza}'
                : 'Tutte le navi posizionate',
            style: const TextStyle(fontSize: 18),
          ),
          Expanded(
            child: GridView.builder(
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 10,
              ),
              itemCount: 100,
              itemBuilder: (_, i) {
                return GestureDetector(
                  onTap: () => piazzaNave(i),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: celleOccupate.contains(i)
                          ? Colors.blue
                          : Colors.grey.shade300,
                      border: Border.all(color: Colors.black26),
                    ),
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: ruotaNave,
                child: const Text('Ruota nave'),
              ),
              ElevatedButton(
                onPressed: confermaPosizioni,
                child: const Text('Conferma posizioni'),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}


