import 'dart:convert';
import 'dart:io';

void main() async {
  final server = await ServerSocket.bind(InternetAddress.anyIPv4, 4040);
  print('Server Battaglia Navale avviato sulla porta 4040');

  server.listen((Socket client) {
    print('Nuovo client connesso: ${client.remoteAddress.address}');
    gestisciClient(client);
  });
}

enum StatoPartita { attesaGiocatori, posizionamento, inGioco, terminata }

class Partita {
  Socket giocatore1;
  Socket giocatore2;
  
  String nick1 = "Giocatore 1";
  String nick2 = "Giocatore 2";

  StatoPartita stato = StatoPartita.attesaGiocatori;

  bool g1Confermato = false;
  bool g2Confermato = false;
  bool pos1Pronto = false;
  bool pos2Pronto = false;

  List<List<int>> navi1 = [];
  List<List<int>> navi2 = [];
  Set<int> colpi1 = {};
  Set<int> colpi2 = {};

  int turno = 1; 

  Partita(this.giocatore1, this.giocatore2);

  bool contiene(Socket s) => s == giocatore1 || s == giocatore2;
  Socket avversario(Socket s) => s == giocatore1 ? giocatore2 : giocatore1;
  int indice(Socket s) => s == giocatore1 ? 1 : 2;
}

final List<Socket> codaGiocatori = [];
final List<Partita> partite = [];
final Map<Socket, String> tempNicknames = {}; 

void gestisciClient(Socket socket) {
  socket.listen(
    (data) {
      final messaggioCompleto = utf8.decode(data);
      for (final line in messaggioCompleto.split('\n')) {
        if (line.trim().isEmpty) continue;
        gestisciMessaggio(socket, line.trim());
      }
    },
    onDone: () => gestisciDisconnessione(socket),
    onError: (_) => gestisciDisconnessione(socket),
  );
}

void gestisciMessaggio(Socket socket, String messaggio) {
  print('Ricevuto: $messaggio');
  final parti = messaggio.split('|');
  final comando = parti[0];

  switch (comando) {
    case 'JOIN':
      String nick = parti.length > 1 ? parti[1] : "Sconosciuto";
      gestisciJoin(socket, nick);
      break;

    case 'GIOCA':
      gestisciGioca(socket);
      break;

    case 'POSIZIONI':
      if (parti.length > 1) riceviPosizioni(socket, parti.sublist(1).join('|'));
      break;

    case 'SPARA':
      if (parti.length > 1) spara(socket, int.parse(parti[1]));
      break;

    case 'ESCI':
      gestisciDisconnessione(socket);
      break;
  }
}

void gestisciJoin(Socket socket, String nickname) {
  if (!codaGiocatori.contains(socket)) {
    codaGiocatori.add(socket);
    tempNicknames[socket] = nickname;
    print("Giocatore $nickname aggiunto alla coda.");
  }

  if (codaGiocatori.length >= 2) {
    final g1 = codaGiocatori.removeAt(0);
    final g2 = codaGiocatori.removeAt(0);
    final p = Partita(g1, g2);
    p.nick1 = tempNicknames[g1] ?? "G1";
    p.nick2 = tempNicknames[g2] ?? "G2";
    tempNicknames.remove(g1);
    tempNicknames.remove(g2);
    partite.add(p);

    print("Partita creata: ${p.nick1} vs ${p.nick2}");
    g1.write('ATTESA_GIOCATORE\n');
    g2.write('ATTESA_GIOCATORE\n');
  } else {
    socket.write('ATTESA_GIOCATORE\n');
  }
}

void gestisciGioca(Socket socket) {
  final partita = trovaPartita(socket);
  if (partita == null) {
    socket.write('ATTESA_GIOCATORE\n');
    return;
  }

  if (socket == partita.giocatore1) partita.g1Confermato = true;
  else partita.g2Confermato = true;

  if (partita.g1Confermato && partita.g2Confermato) {
    partita.stato = StatoPartita.posizionamento;
    partita.giocatore1.write('START_POS\n');
    partita.giocatore2.write('START_POS\n');
  } else {
    socket.write('ATTESA_GIOCATORE\n');
  }
}

void riceviPosizioni(Socket socket, String json) {
  final partita = trovaPartita(socket);
  if (partita == null) return;

  try {
    final List<dynamic> dati = jsonDecode(json);
    final navi = dati.map((e) => List<int>.from(e)).toList();

    if (socket == partita.giocatore1) {
      partita.navi1 = navi;
      partita.pos1Pronto = true;
    } else {
      partita.navi2 = navi;
      partita.pos2Pronto = true;
    }

    if (partita.pos1Pronto && partita.pos2Pronto) {
      partita.stato = StatoPartita.inGioco;
      partita.turno = 1;
      
      _inviaJson(partita.giocatore1, {
        "tipo": "START_GIOCO",
        "mioTurno": true,
        "avversario": partita.nick2
      });
      _inviaJson(partita.giocatore2, {
        "tipo": "START_GIOCO",
        "mioTurno": false,
        "avversario": partita.nick1
      });
    }
  } catch (e) {
    print("Errore ricezione posizioni: $e");
  }
}

void spara(Socket socket, int cella) {
  final partita = trovaPartita(socket);
  if (partita == null || partita.stato != StatoPartita.inGioco) return;

  final idx = partita.indice(socket);
  if (partita.turno != idx) return;

  final colpiEffettuati = idx == 1 ? partita.colpi1 : partita.colpi2;
  if (colpiEffettuati.contains(cella)) return;
  colpiEffettuati.add(cella);

  final naviAvversario = idx == 1 ? partita.navi2 : partita.navi1;
  final socketAvversario = partita.avversario(socket);

  bool colpito = false;
  List<int>? naveColpita;

  for (final nave in naviAvversario) {
    if (nave.contains(cella)) {
      colpito = true;
      naveColpita = nave;
      break;
    }
  }

  _inviaJson(socket, {"tipo": "RISULTATO", "hit": colpito, "cella": cella});
  _inviaJson(socketAvversario, {"tipo": "SUBITO", "hit": colpito, "cella": cella});

  if (colpito) {
    final affondata = naveColpita!.every((c) => colpiEffettuati.contains(c));
    if (affondata) {
       naviAvversario.remove(naveColpita);
       _inviaJson(socket, {"tipo": "AFFONDATA", "celle": naveColpita});
       _inviaJson(socketAvversario, {"tipo": "PERSA", "celle": naveColpita});

       if (naviAvversario.isEmpty) {
         partita.stato = StatoPartita.terminata;
         _inviaJson(socket, {"tipo": "VITTORIA"});
         _inviaJson(socketAvversario, {"tipo": "SCONFITTA"});
         return;
       }
    }
    _inviaJson(socket, {"tipo": "TURNO", "mioTurno": true});
    _inviaJson(socketAvversario, {"tipo": "TURNO", "mioTurno": false});
  } else {
    partita.turno = idx == 1 ? 2 : 1;
    _inviaJson(socket, {"tipo": "TURNO", "mioTurno": false});
    _inviaJson(socketAvversario, {"tipo": "TURNO", "mioTurno": true});
  }
}

void gestisciDisconnessione(Socket socket) {
  if (codaGiocatori.contains(socket)) codaGiocatori.remove(socket);
  tempNicknames.remove(socket);

  final partita = trovaPartita(socket);
  if (partita != null) {
    final avv = partita.avversario(socket);
    try {
      _inviaJson(avv, {"tipo": "AVVERSARIO_USCITO"});
    } catch (_) {}
    partite.remove(partita);
  }
  try { socket.close(); } catch (_) {}
}

Partita? trovaPartita(Socket s) {
  for (final p in partite) {
    if (p.contiene(s)) return p;
  }
  return null;
}

void _inviaJson(Socket s, Map<String, dynamic> data) {
  try {
    s.write('${jsonEncode(data)}\n');
  } catch (_) {}
}



