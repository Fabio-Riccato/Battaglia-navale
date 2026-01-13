import 'package:flutter/material.dart';

class Griglia extends StatelessWidget {
  final String titolo;
  final List<int> navi;
  final List<int> colpi;
  final Set<int> colpiHit;
  final bool cliccabile;
  final Function(int)? onTap;

  const Griglia({
    super.key,
    required this.titolo,
    this.navi = const [],
    this.colpi = const [],
    this.colpiHit = const {},
    this.cliccabile = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 5),
        Text(
          titolo,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 10,
            ),
            itemCount: 100,
            itemBuilder: (_, index) {
              Widget contenuto = const SizedBox();

              if (colpiHit.contains(index)) {
                contenuto = const Text(
                  '✖',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                );
              } else if (colpi.contains(index)) {
                contenuto = const Text(
                  '●',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black,
                  ),
                );
              }

              return GestureDetector(
                onTap: cliccabile ? () => onTap?.call(index) : null,
                child: Container(
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: navi.contains(index)
                        ? Colors.blue.shade300
                        : Colors.grey.shade200,
                    border: Border.all(color: Colors.black26),
                  ),
                  child: Center(child: contenuto),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
