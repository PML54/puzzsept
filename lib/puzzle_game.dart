
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:puzzsept/utils/profiler.dart';

import 'pmlsoft.dart';
import 'puzzle_board.dart';
import 'puzzle_params.dart';
import 'puzzle_state.dart';
import 'utils/function_counter.dart';
import 'widget/compactage.dart';
import 'widget/image_processing_report_widget.dart';

const bool kDebugMode = false; // Changez en true pour le mode débogage
final FunctionCounter _counter = FunctionCounter();

void debugPrint(String message) {
  if (kDebugMode) {
    print('[DEBUG] $message');
  }
}

class PuzzleGame extends ConsumerStatefulWidget {
  const PuzzleGame({Key? key}) : super(key: key);

  @override
  ConsumerState<PuzzleGame> createState() => _PuzzleGameState();
}

class _PuzzleGameState extends ConsumerState<PuzzleGame> {
  bool _showFullImage = false;
  Timer? _timer;
  String? _saveMessage;
  late Future<void> _initializationFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        } else {
          return _buildPuzzleGame();
        }
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initializationFuture = _loadRandomImage(context);
  }

  // Autres méthodes (_pickImage, _takePhoto, _savePuzzleState, etc.) restent inchangées
  bool isPuzzleImage(String imageName) {
    // Vérifier si le nom du fichier commence par "PUZ" et a au moins 11 caractères
    // (PUZ + 2 chiffres pour les minutes + 2 pour les secondes + 2 pour les colonnes + 2 pour les lignes)
    return imageName.startsWith("PUZ") && imageName.length >= 11;
  }

  // 2. Asset image loading function
  Future<Uint8List> loadAssetImage(String assetPath) async {
    final ByteData data = await rootBundle.load(assetPath);
git    return data.buffer.asUint8List();
  }

  Future<Uint8List?> loadImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    if (image != null) {
      return await image.readAsBytes();
    }
    return null;
  }

  Future<void> processAndInitializePuzzle(Uint8List imageBytes,
      String imageName, bool isAsset, String category) async {
    profiler.reset();
    profiler.start('processAndInitializePuzzle');
    ref.read(puzzleProvider.notifier).setLoading(true);
    ref.read(puzzleProvider.notifier).setImageTitle(imageName);
    ref.read(puzzleProvider.notifier).resetSwapCount();

    try {
      final optimizedImageBytes =
          imageBytes; // Placeholder for optimization logic


      await ref.read(puzzleProvider.notifier).initializePuzzle(
            imageBytes,
            optimizedImageBytes,
            imageName,
            isAsset,
            category,
          );
      profiler.end('processAndInitializePuzzle');
      ref.read(puzzleProvider.notifier).storeImageProcessingData();
      ref.read(puzzleProvider.notifier).shufflePieces();
      ref.read(puzzleProvider.notifier).setPuzzleReady(true);
    } catch (e) {
      debugPrint("Erreur lors du chargement de l'image: $e");
      ref
          .read(puzzleProvider.notifier)
          .setError("Erreur lors du chargement de l'image");
    } finally {
      ref.read(puzzleProvider.notifier).setLoading(false);
    }

  }

  List<Widget> _buildAppBarActions() {
    final puzzleState = ref.watch(puzzleProvider);

    return [
      Tooltip(
        message: '[${puzzleState.swapCount}]',
        child: Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Center(
            child: Text(
              '${ref.read(puzzleProvider.notifier).countCorrectPiecesGeneral()}/${puzzleState.pieces.length}',
              style: const TextStyle(fontSize: 10, color: Colors.black),
            ),
          ),
        ),
      ),
      IconButton(
        icon: const Icon(Icons.play_arrow_sharp,
            color: Colors.blueAccent, size: 30),
        onPressed: () => _loadRandomImage(context),
        tooltip: 'Boite à Images',
      ),
      IconButton(
        icon: const Icon(Icons.lightbulb_outline, color: Colors.greenAccent),
        onPressed: _toggleFullImage,
        tooltip: 'Voir le puzzle',
      ),
      IconButton(
        icon: const Icon(Icons.photo_library_outlined, color: Colors.black),
        onPressed: _pickImage,
        tooltip: 'Choisir une image',
      ),
      IconButton(
        icon: const Icon(Icons.camera_alt, color: Colors.black),
        onPressed: _takePhoto,
        tooltip: 'Prendre une photo',
      ),
      IconButton(
        icon: const Icon(Icons.save, color: Colors.green),
        onPressed: _savePuzzleState,
        tooltip: 'Sauvegarder le puzzle',
      ),
      IconButton(
        icon: const Icon(Icons.settings, color: Colors.red),
        tooltip: 'Paramètres',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const DifficultySettingsScreen()),
          );
        },
      ),
      IconButton(
        icon: const Icon(Icons.info, color: Colors.red),
        tooltip: 'Infos Image',
        onPressed: () {
          // Votre code pour afficher le dialogue d'informations
        },
      ),
      IconButton(
        icon: Icon(Icons.assessment),
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return ImageProcessingReportWidget();
            },
          );
        },
        tooltip: 'Afficher le rapport de traitement d\'image',
      ),
    ];
  }

  Widget _buildPuzzleGame() {
    final puzzleState = ref.watch(puzzleProvider);

    return Scaffold(
      appBar: CompactAppBar(
        isLoading: puzzleState.isLoading,
        loadingText: "Découpage en cours...(V828'))",
        actions: _buildAppBarActions(),
        saveMessage: _saveMessage,
      ),
      body: Stack(
        children: [
          if (_showFullImage)
            Center(
              child: Image.memory(
                puzzleState.fullImage!,
                fit: BoxFit.contain,
              ),
            )
          else if (puzzleState.isInitialized)
            const PuzzleBoard()
          else
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Future<void> _initializeNewPuzzle(
      Uint8List imageBytes, String imageName) async {
    ref.read(puzzleProvider.notifier).setImageTitle(imageName);
    ref.read(puzzleProvider.notifier).resetSwapCount();

    await ref.read(puzzleProvider.notifier).initializePuzzle(
          imageBytes,
          imageBytes,
          imageName,
          false,
          'Custom',
        );

    ref.read(puzzleProvider.notifier).shufflePieces();
    ref.read(puzzleProvider.notifier).setPuzzleReady(true);
  }

  Future<void> _loadCustomImage(Uint8List imageBytes, String imageName) async {
    ref.read(puzzleProvider.notifier).setLoading(true);

    try {
      final isPuzzleImg = isPuzzleImage(imageName);
      if (isPuzzleImg) {
        await _loadSavedPuzzleFromImage(imageBytes, imageName);
      } else {
        await _initializeNewPuzzle(imageBytes, imageName);
      }
    } catch (e) {
      debugPrint("Erreur lors du chargement de l'image: $e");
      ref
          .read(puzzleProvider.notifier)
          .setError("Erreur lors du chargement de l'image");
    } finally {
      ref.read(puzzleProvider.notifier).setLoading(false);
    }
  }

  Future<void> _loadRandomImage(BuildContext context) async {
    final random = Random();
    final randomImage = imageList[random.nextInt(imageList.length)];
    final String assetPath = 'assets/${randomImage['file']}';

    final imageBytes = await loadAssetImage(assetPath);
    await processAndInitializePuzzle(
        imageBytes, randomImage['name']!, true, randomImage['categ']!);
  }

  Future<void> _loadSavedPuzzleFromImage(
      Uint8List imageBytes, String filename) async {
    try {
      await ref
          .read(puzzleProvider.notifier)
          .loadPuzzleFromImage(imageBytes, filename);
      setState(() {}); // Forcez une mise à jour de l'UI
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Puzzle chargé  ')),
      );
    } catch (e) {
      debugPrint("Erreur lors du chargement du puzzle sauvegardé: $e");
      ref
          .read(puzzleProvider.notifier)
          .setError("Erreur lors du chargement du puzzle sauvegardé");
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    profiler.reset();
    profiler.start('pickImage');
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final Uint8List imageBytes = await image.readAsBytes();
      _loadCustomImage(imageBytes, image.name);

      profiler.end('pickImage');
      ref.read(puzzleProvider.notifier).storeImageProcessingData();
    }
  }

  Future<void> _savePuzzleState() async {
    debugPrint("Début de _savePuzzleState: ${DateTime.now()}");
    debugPrint("_saveMessage avant setState: $_saveMessage");

    // Utilisons debugPrint au lieu de setState pour le premier message
    debugPrint("Sauvegarde en cours...");
    _saveMessage = 'Sauvegarde en cours...';

    try {
      debugPrint("Avant savePuzzleStateWithImage: ${DateTime.now()}");
      await ref.read(puzzleProvider.notifier).savePuzzleStateWithImage();
      debugPrint("Après savePuzzleStateWithImage: ${DateTime.now()}");

      debugPrint("Sauvegarde terminée avec succès: ${DateTime.now()}");
      setState(() {
        _saveMessage = 'Puzzle sauvegardé';
        debugPrint("setState: _saveMessage = $_saveMessage");
      });

      debugPrint("Avant Future.delayed: ${DateTime.now()}");
      Future.delayed(const Duration(seconds: 3), () {
        debugPrint("Dans Future.delayed, avant setState: ${DateTime.now()}");
        if (mounted) {
          setState(() {
            _saveMessage = null;
            debugPrint("setState dans Future.delayed: _saveMessage effacé");
          });
        } else {
          debugPrint("Widget non monté dans Future.delayed");
        }
      });

      debugPrint("Avant showSnackBar: ${DateTime.now()}");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Puzzle sauvegardé')),
      );
      debugPrint("Après showSnackBar: ${DateTime.now()}");
    } catch (e) {
      debugPrint('Erreur lors de la sauvegarde: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sauvegarde du puzzle: $e')),
      );
    }
    debugPrint("Fin de _savePuzzleState: ${DateTime.now()}");
  }

  Future<void> _takePhoto() async {
    final imageBytes = await loadImage(ImageSource.camera);
    if (imageBytes != null) {
      final imageName = 'Photo_${DateTime.now().toIso8601String()}.jpg';
      await processAndInitializePuzzle(imageBytes, imageName, false, 'Custom');
    }
  }

  void _toggleFullImage() {
    setState(() {
      _showFullImage = true;
    });

    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 3), () {
      setState(() {
        _showFullImage = false;
      });
    });
  }
}
