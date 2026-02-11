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
            msg['hit'] ? colpiFatti.add(msg['cella']) : acquaFatti.add(msg['cella']);
            break;
          case 'SUBITO':
            msg['hit'] ? colpiSubiti.add(msg['cella']) : acquaSubiti.add(msg['cella']);
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
          case 'AVVERSARIO_USCITO':
            _mostraPopupFine("Vittoria a tavolino", "L'avversario ha abbandonato la partita.");
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

  // Popup per vittoria, sconfitta o avversario uscito
  void _mostraPopupFine(String titolo, String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(titolo),
        content: Text(msg),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
            child: const Text("Torna alla home"),
          )
        ],
      ),
    );
  }

  // Popup di conferma uscita (tasto indietro)
  Future<void> _confermaUscita() async {
    final esci = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Sei sicuro di voler uscire?"),
        content: const Text("Se esci ora perderai la partita."),
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

  void spara(int cella) {
    if (!mioTurno || colpiFatti.contains(cella) || acquaFatti.contains(cella)) return;
    widget.servizio.spara(cella);
  }

  Widget griglia({required bool isDifesa, Function(int)? tap}) {
    const lettere = ['A','B','C','D','E','F','G','H','I','J'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final double lato = (constraints.maxWidth * 0.9).clamp(220, 300);

        return Center(
          child: SizedBox(
            width: lato + 30,
            child: Column(
              children: [
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
                    SizedBox(
                      width: 30,
                      child: Column(
                        children: List.generate(10, (i) => SizedBox(
                          height: lato / 10,
                          child: Center(child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                        )),
                      ),
                    ),
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
    // FIX PROBLEMA 1: PopScope intercetta il tasto indietro
    return PopScope(
      canPop: false, // Disabilita l'uscita automatica
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _confermaUscita();
      },
      child: Scaffold(
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
                  onPressed: _confermaUscita,
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
      ),
    );
  }
}





