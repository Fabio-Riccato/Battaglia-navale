import 'package:flutter/material.dart';
import 'servizio_tcp.dart';
import 'stati.dart';
import 'griglia.dart';

class SchermataGioco extends StatefulWidget {
  final ServizioTCP servizio;
  final List<int> mieNavi;

  const SchermataGioco({
    super.key,
    required this.servizio,
    required this.mieNavi,
  });

  @override
  State<SchermataGioco> createState() => _SchermataGiocoState();
}

class _SchermataGiocoState extends State<SchermataGioco> {
  StatoPartita stato = StatoPartita.attesaAvversario;

  List<int> colpiMiei = [];
  List<int> colpiSubiti = [];
  Set<int> colpiMieiHit = {};
  Set<int> colpiSubitiHit = {};

  @override
  void initState() {
    super.initState();
    widget.servizio.onMessaggio = gestisciMessaggio;
  }

  void gestisciMessaggio(String msg) {
    setState(() {
      if (msg == 'TURNO') stato = StatoPartita.mioTurno;
      if (msg == 'ATTESA') stato = StatoPartita.turnoAvversario;

      if (msg.startsWith('HIT')) {
        colpiMieiHit.add(int.parse(msg.split(',')[1]));
      }

      if (msg.startsWith('MISS')) {
        colpiMiei.add(int.parse(msg.split(',')[1]));
      }

      if (msg.startsWith('SUBITO_HIT')) {
        colpiSubitiHit.add(int.parse(msg.split(',')[1]));
      }

      if (msg.startsWith('SUBITO_MISS')) {
        colpiSubiti.add(int.parse(msg.split(',')[1]));
      }
    });
  }

  void spara(int cella) {
    if (stato != StatoPartita.mioTurno) return;
    widget.servizio.spara(cella);
  }

  String testoStato() {
    return stato == StatoPartita.mioTurno
        ? 'È il tuo turno'
        : 'Turno dell’altro giocatore';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Battaglia Navale')),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Text(
            testoStato(),
            style: const TextStyle(fontSize: 18),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Griglia(
                    titolo: 'Le tue navi',
                    navi: widget.mieNavi,
                    colpi: colpiSubiti,
                    colpiHit: colpiSubitiHit,
                  ),
                ),
                Expanded(
                  child: Griglia(
                    titolo: 'Attacco',
                    colpi: colpiMiei,
                    colpiHit: colpiMieiHit,
                    cliccabile: stato == StatoPartita.mioTurno,
                    onTap: spara,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


