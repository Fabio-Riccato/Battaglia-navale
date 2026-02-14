import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'servizio_tcp.dart';
import 'schermata_posizionamento.dart';

class PaginaIniziale extends StatefulWidget {
  const PaginaIniziale({super.key});
  @override
  State<PaginaIniziale> createState() => _PaginaInizialeState();
}

class _PaginaInizialeState extends State<PaginaIniziale> with SingleTickerProviderStateMixin {
  final ServizioTCP servizio = ServizioTCP();
  final TextEditingController ipController = TextEditingController();
  final TextEditingController nickController = TextEditingController();

  bool serverConnesso = false;
  bool inAttesa = false;
  bool ipValido = false;

  late AnimationController _animController;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _waveAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _validaIP(String val) {
    final regExp = RegExp(r'^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$');
    setState(() {
      ipValido = regExp.hasMatch(val);
    });
  }

  void connetti() async {
    if (nickController.text.trim().isEmpty) {
      _mostraSnackBar("Inserisci un Nickname per giocare!", Icons.warning_amber);
      return;
    }

    setState(() => inAttesa = true);

    bool connesso = await servizio.connetti(ipController.text, nickController.text);

    if (mounted) {
      setState(() {
        inAttesa = false;
        serverConnesso = connesso;
      });

      if (connesso) {
        _mostraSnackBar("Connesso al server!", Icons.check_circle, Colors.green);
      } else {
        mostraErrore();
      }
    }
  }

  void _mostraSnackBar(String msg, IconData icon, [Color? color]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const Gap(12),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: color ?? Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void mostraErrore() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const Gap(12),
            const Text('Errore di Connessione'),
          ],
        ),
        content: const Text(
          'Non è stato possibile raggiungere il server.\n\n'
              'Controlla l\'IP e assicurati che il server sia avviato.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
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
          MaterialPageRoute(
            builder: (_) => SchermataPosizionamento(servizio: servizio),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D47A1),
              Color(0xFF1976D2),
              Color(0xFF42A5F5),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Gap(20),
                AnimatedBuilder(
                  animation: _waveAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _waveAnimation.value),
                      child: child,
                    );
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.explore,
                          size: 80,
                          color: Colors.white,
                        ),
                      ),
                      const Gap(16),
                      const Text(
                        'BATTAGLIA NAVALE',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2,
                          shadows: [
                            Shadow(
                              blurRadius: 10,
                              color: Colors.black26,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(40),

                Card(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: nickController,
                          label: 'Il tuo Nickname',
                          hint: 'Es: Ammiraglio',
                          icon: Icons.person,
                        ),
                        const Gap(20),

                        _buildTextField(
                          controller: ipController,
                          label: 'Indirizzo IP Server',
                          hint: '10.0.2.2',
                          icon: Icons.computer,
                          onChanged: _validaIP,
                          errorText: ipController.text.isNotEmpty && !ipValido
                              ? 'Indirizzo IP non valido'
                              : null,
                          borderColor: ipController.text.isNotEmpty
                              ? (ipValido ? Colors.green : Colors.red)
                              : null,
                        ),
                        const Gap(30),

                        if (inAttesa)
                          Column(
                            children: [
                              CircularProgressIndicator(
                                color: Theme.of(context).primaryColor,
                              ),
                              const Gap(16),
                              Text(
                                serverConnesso
                                    ? 'Ricerca avversario...'
                                    : 'Connessione in corso...',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          )
                        else if (!serverConnesso)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ipValido
                                    ? const Color(0xFF1565C0)
                                    : Colors.grey,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: ipValido ? connetti : null,
                              icon: const Icon(Icons.wifi),
                              label: const Text(
                                'CONNETTI',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                        else ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green.shade200,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green.shade700),
                                  const Gap(12),
                                  Text(
                                    'Server Connesso!',
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Gap(20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                ),
                                onPressed: gioca,
                                icon: const Icon(Icons.play_arrow, size: 28),
                                label: const Text(
                                  'TROVA PARTITA',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                      ],
                    ),
                  ),
                ),
                const Gap(20),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.white.withOpacity(0.9)),
                      const Gap(12),
                      Expanded(
                        child: Text(
                          'Assicurati di essere sulla stessa rete del server',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? errorText,
    Color? borderColor,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: borderColor ?? Colors.grey.shade300,
            width: 2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: borderColor ?? const Color(0xFF1565C0),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }
}



