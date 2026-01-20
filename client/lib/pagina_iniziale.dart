import 'package:flutter/material.dart';
import 'servizio_tcp.dart';
import 'schermata_posizionamento.dart';

class PaginaIniziale extends StatefulWidget {
  const PaginaIniziale({super.key});
  @override
  State<PaginaIniziale> createState() => _PaginaInizialeState();
}

class _PaginaInizialeState extends State<PaginaIniziale> {
  final ServizioTCP servizio = ServizioTCP();
  final TextEditingController ipController = TextEditingController();
  final TextEditingController nickController = TextEditingController();

  bool serverConnesso = false;
  bool inAttesa = false;
  bool ipValido = false;

  void _validaIP(String val) {
    final regExp = RegExp(r'^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$');
    setState(() {
      ipValido = regExp.hasMatch(val);
    });
  }

  void connetti() async {
    if (nickController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Inserisci un Nickname per giocare!"))
      );
      return;
    }

    setState(() => inAttesa = true);

    bool connesso = await servizio.connetti(ipController.text, nickController.text);

    if (mounted) {
      setState(() {
        inAttesa = false;
        serverConnesso = connesso;
      });

      if (!connesso) {
        mostraErrore();
      }
    }
  }

  void mostraErrore() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Errore di Connessione'),
        content: const Text(
            'Non è stato possibile raggiungere il server.\n'
                'Controlla l\'IP e assicurati che il server sia avviato.'
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))
        ],
      ),
    );
  }

  void gioca() async {
    setState(() => inAttesa = true);
    servizio.gioca();

    final pronto = await servizio.attendiStart();

    if (mounted) {
      setState(() => inAttesa = false);
      if (pronto) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SchermataPosizionamento(servizio: servizio)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Battaglia Navale')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.directions_boat, size: 80, color: Colors.blue),
            const SizedBox(height: 30),

            TextField(
              controller: nickController,
              decoration: const InputDecoration(
                labelText: 'Il tuo Nickname',
                hintText: 'Es: Ammiraglio',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: ipController,
              onChanged: _validaIP,
              decoration: InputDecoration(
                labelText: 'Indirizzo IP Server',
                hintText: '10.0.2.2',
                errorText: ipController.text.isNotEmpty && !ipValido
                    ? 'Indirizzo IP non valido'
                    : null,
                prefixIcon: const Icon(Icons.computer),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: ipValido ? Colors.green : Colors.red,
                        width: 2.0
                    )
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),

            if (inAttesa)
              const CircularProgressIndicator()
            else if (!serverConnesso)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                  onPressed: ipValido ? connetti : null,
                  child: const Text('CONNETTI'),
                ),
              )
            else ...[
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Server Connesso!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16)
                    ),
                    onPressed: gioca,
                    child: const Text('TROVA PARTITA'),
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }
}



