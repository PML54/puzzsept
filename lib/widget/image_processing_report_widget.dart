import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzsept/puzzle_state.dart';

class ImageProcessingReportWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final puzzleNotifier = ref.read(puzzleProvider.notifier);
    final imageProcessingHistory = puzzleNotifier.imageProcessingHistory;

    return AlertDialog(
      title: Text('Rapport de traitement d\'image'),
      content: Container(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: imageProcessingHistory.length,
          itemBuilder: (context, index) {
            final data = imageProcessingHistory[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Image ${index + 1}', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Dimensions: ${data.imageSize.width.toInt()} x ${data.imageSize.height.toInt()}'),
                    Text('Grille: ${data.columns} x ${data.rows}'),
                    Text('Taille originale: ${(data.originalImageSize / 1024).toStringAsFixed(2)} KB'),
                    Text('Taille optimisée: ${(data.optimizedImageSize / 1024).toStringAsFixed(2)} KB'),
                    Text('Temps de décodage: ${data.decodeImageTime.toStringAsFixed(2)} ms'),
                    Text('Temps de création des pièces: ${data.createPuzzlePiecesTime.toStringAsFixed(2)} ms'),
                    Text('Temps de mélange: ${data.shufflePiecesTime.toStringAsFixed(2)} ms'),
                    Text('Temps de Recadrage: ${data.applyNewDifficultyTime.toStringAsFixed(2)} ms'),
                    Text('processAndInitializePuzzleTime: ${data.processAndInitializePuzzleTime.toStringAsFixed(2)} ms'),
                    Text('pickImageTime: ${data.pickImageTime.toStringAsFixed(2)} ms'),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text('Fermer'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}