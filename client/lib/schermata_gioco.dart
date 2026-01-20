import 'package:flutter/material.dart';
import 'servizio_tcp.dart';

class SchermataGioco extends StatefulWidget {
  final ServizioTCP servizio;
  final List<List<int>> mieNavi;

  const SchermataGioco({
    super.key,
    required this.servizio,
    required this.mieNavi,
  });

  @override
  State<SchermataGioco> createState() => _SchermataGiocoState();
}

class _SchermataGiocoState extends State<SchermataGioco> {
  bool mioTurno = false;
  String stato = 'In attesa...';

  Set<int> colpiFatti = {};
  Set<int> colpiSubiti = {};
  Set<int> acquaFatti = {};
  Set<int> acquaSubiti = {};

  Set<int> naviAffondateAvversario = {};
  Set<int> mieNaviAffondate = {};

  @override
  void initState() {
    super.initState();
    _aggiornaStatoTestuale();

    widget.servizio.onEvento = (msg) {
      if (!mounted) return;
      setState(() {
        switch (msg['tipo']) {
          case 'START_GIOCO':
          case 'TURNO':
            mioTurno = msg['mioTurno'] ?? false;
            _aggiornaStatoTestuale();
            break;

          case 'RISULTATO':
            msg['hit']
                ? colpiFatti.add(msg['cella'])
                : acquaFatti.add(msg['cella']);
            break;

          case 'SUBITO':
            msg['hit']
                ? colpiSubiti.add(msg['cella'])
                : acquaSubiti.add(msg['cella']);
            break;

          case 'AFFONDATA':
            naviAffondateAvversario.addAll((msg['celle'] as List).cast<int>());
            break;

          case 'PERSA':
            mieNaviAffondate.addAll((msg['celle'] as List).cast<int>());
            break;

          case 'VITTORIA':
            _mostraPopupFine("Hai Vinto!", "Hai affondato la flotta nemica!");
            break;

          case 'SCONFITTA':
            _mostraPopupFine("Hai Perso...", "La tua flotta è stata distrutta.");
            break;
        }
      });
    };
  }

  void _aggiornaStatoTestuale() {
    stato = mioTurno
        ? "Tocca a te, ${widget.servizio.mioNickname}!"
        : "Turno di ${widget.servizio.nicknameAvversario}...";
  }

  void _mostraPopupFine(String titolo, String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(titolo),
        content: Text(msg),
        actions: [
          ElevatedButton(
            onPressed: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
            child: const Text("Torna alla home"),
          )
        ],
      ),
    );
  }

  void spara(int cella) {
    if (!mioTurno ||
        colpiFatti.contains(cella) ||
        acquaFatti.contains(cella)) return;
    widget.servizio.spara(cella);
  }

  /// ==========================
  /// GRIGLIA RIDIMENSIONATA
  /// ==========================
  Widget griglia({required bool isDifesa, Function(int)? tap}) {
    const lettere = ['A','B','C','D','E','F','G','H','I','J'];

    return LayoutBuilder(
      builder: (context, constraints) {
        // ⬇ dimensione massima della griglia
        final double lato = (constraints.maxWidth * 0.9).clamp(220, 300);

        return Center(
          child: SizedBox(
            width: lato + 30,
            child: Column(
              children: [
                // Lettere
                Row(
                  children: [
                    const SizedBox(width: 30),
                    ...lettere.map((l) => Expanded(
                      child: Center(
                        child: Text(l, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    )),
                  ],
                ),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Numeri
                    SizedBox(
                      width: 30,
                      child: Column(
                        children: List.generate(10, (i) => SizedBox(
                          height: lato / 10,
                          child: Center(child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                        )),
                      ),
                    ),

                    // Griglia
                    SizedBox(
                      width: lato,
                      height: lato,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 100,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 10,
                        ),
                        itemBuilder: (_, i) {
                          Color colore = Colors.blue.shade50;
                          Widget icona = const SizedBox();

                          if (isDifesa) {
                            if (widget.mieNavi.expand((e) => e).contains(i)) {
                              colore = Colors.grey.shade400;
                            }
                            if (mieNaviAffondate.contains(i)) {
                              colore = Colors.red.shade300;
                            }
                            if (colpiSubiti.contains(i)) {
                              icona = const Icon(Icons.close, size: 18);
                            } else if (acquaSubiti.contains(i)) {
                              icona = const Icon(Icons.circle, size: 6);
                            }
                          } else {
                            if (naviAffondateAvversario.contains(i)) {
                              colore = Colors.green.shade300;
                            }
                            if (colpiFatti.contains(i)) {
                              icona = const Icon(Icons.close, color: Colors.red, size: 18);
                            } else if (acquaFatti.contains(i)) {
                              icona = const Icon(Icons.circle, size: 6);
                            }
                          }

                          return GestureDetector(
                            onTap: tap != null ? () => tap(i) : null,
                            child: Container(
                              margin: const EdgeInsets.all(1),
                              color: colore,
                              child: Center(child: icona),
                            ),
                          );
                        },
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Battaglia in corso')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Text(stato, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            const Text("DIFESA"),
            griglia(isDifesa: true),

            const SizedBox(height: 20),
            const Divider(),

            const Text("ATTACCO"),
            griglia(isDifesa: false, tap: spara),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  widget.servizio.abbandona();
                  Navigator.popUntil(context, (r) => r.isFirst);
                },
                child: const Text(
                  "ABBANDONA PARTITA",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}





