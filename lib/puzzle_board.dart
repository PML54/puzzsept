

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'puzzle_state.dart';
import 'utils/function_counter.dart';
const bool kDebugMode = false; // Changez en true pour le mode débogage

void debugPrint(String message) {
  if (kDebugMode) {
    print('[DEBUG] $message');
  }
}
final FunctionCounter _counter = FunctionCounter();
class PuzzleBoard extends ConsumerWidget {
  const PuzzleBoard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final puzzleState = ref.watch(puzzleProvider);
    final correctPieces =
    ref.read(puzzleProvider.notifier).countCorrectPiecesGeneral();
    final isComplete = correctPieces == puzzleState.pieces.length;
    _counter.increment('build PuzzleBoard');

    if (!puzzleState.isInitialized || puzzleState.columns == 0) {
      return const Center(child: CircularProgressIndicator());
    }

    final screenSize = MediaQuery.of(context).size;
    final appBarHeight = AppBar().preferredSize.height;
    final availableHeight = screenSize.height - appBarHeight;
    final imageAspectRatio =
        puzzleState.imageSize.width / puzzleState.imageSize.height;

    double puzzleWidth, puzzleHeight;
    if (imageAspectRatio > screenSize.width / availableHeight) {
      puzzleWidth = screenSize.width;
      puzzleHeight = screenSize.width / imageAspectRatio;
    } else {
      puzzleHeight = availableHeight;
      puzzleWidth = availableHeight * imageAspectRatio;
    }

    double pieceWidth = puzzleWidth / puzzleState.columns;
    double pieceHeight = puzzleHeight / puzzleState.rows;

    Widget buildCompletionText(PuzzleState puzzleState) {
      return AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 2000),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                puzzleState.currentImageTitle,
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Center(
          child: SizedBox(
            width: puzzleWidth,
            height: puzzleHeight,
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: puzzleState.columns,
                childAspectRatio: pieceWidth / pieceHeight,
              ),
              itemCount: puzzleState.pieces.length,
              itemBuilder: (context, index) {
                final pieceIndex = puzzleState.currentArrangement[index];
                return DragTarget<int>(
                  onAcceptWithDetails: (details) {
                    ref
                        .read(puzzleProvider.notifier)
                        .swapPieces(details.data, index);
                  },
                  builder: (context, candidateData, rejectedData) {
                    return Draggable<int>(
                      data: index,
                      feedback: Image.memory(
                        puzzleState.pieces[pieceIndex],
                        width: pieceWidth,
                        height: pieceHeight,
                        fit: BoxFit.cover,
                      ),
                      childWhenDragging: Container(
                        width: pieceWidth,
                        height: pieceHeight,
                        color: Colors.grey.withOpacity(0.5),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: 0.5),
                        ),
                        child: Image.memory(
                          puzzleState.pieces[pieceIndex],
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
        if (isComplete)
          Positioned(
            left: 20,
            top: 20,
            child: Draggable<String>(
              feedback: buildCompletionText(puzzleState),
              childWhenDragging: Container(),
              child: buildCompletionText(puzzleState),
            ),
          ),
      ],
    );
  }
}