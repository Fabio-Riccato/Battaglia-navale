import 'dart:convert';
import 'dart:io';

void main() async {
  final server = await ServerSocket.bind('0.0.0.0', 3000);
  print('Server avviato sulla porta 3000');

  List<Socket> giocatori = [];
  Map<Socket, List<List<int>>> navi = {};

  server.listen((client) {
    giocatori.add(client);
    print('Giocatore connesso (${giocatori.length}/2)');

    if (giocatori.length == 1) {
      client.write('ATTESA_GIOCATORE\n');
    }

    if (giocatori.length == 2) {
      giocatori[0].write('ATTESA\n');
      giocatori[1].write('ATTESA\n');
    }

    client.listen((data) {
      String msg = utf8.decode(data).trim();

      final json = jsonDecode(msg);

      if (json['tipo'] == 'navi') {
        navi[client] = List<List<int>>.from(
          json['dati'].map((e) => List<int>.from(e)),
        );

        if (navi.length == 2) {
          giocatori[0].write('TURNO\n');
          giocatori[1].write('ATTESA\n');
        }
      }

      if (json['tipo'] == 'sparo') {
        Socket attaccante = client;
        Socket difensore = giocatori.firstWhere((g) => g != client);

        int cella = json['dati'];
        bool colpito = false;

        for (var nave in navi[difensore]!) {
          if (nave.contains(cella)) {
            nave.remove(cella);
            colpito = true;

            if (nave.isEmpty) {
              attaccante.write('AFFONDATA\n');
              difensore.write('NAVE_PERSA\n');
            }
            break;
          }
        }

        if (colpito) {
          attaccante.write('HIT,$cella\n');
          difensore.write('SUBITO_HIT,$cella\n');
        } else {
          attaccante.write('MISS,$cella\n');
          difensore.write('SUBITO_MISS,$cella\n');
        }
        attaccante.write('ATTESA\n');
        difensore.write('TURNO\n');
      }
    });
  });
}
