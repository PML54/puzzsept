import 'dart:convert';
import 'dart:html' as html;
import 'dart:io';
import 'dart:math';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:puzzsept/utils/profiler.dart';

import 'utils/function_counter.dart';

const bool kDebugMode = false; // Changez en true pour le mode débogage
const bool kProfilerMode = false; // Changez en true pour le mode débogage
final puzzleProvider = StateNotifierProvider<PuzzleNotifier, PuzzleState>(
    (ref) => PuzzleNotifier());

void debugPrint(String message) {
  if (kDebugMode) {
    print('[DEBUG] $message');
  }
}

class ImageProcessingData {
  final int columns;
  final int rows;
  final Size imageSize;
  final int originalImageSize;
  final int optimizedImageSize;
  final Size originalImageDimensions;
  final Size optimizedImageDimensions;
  final double decodeImageTime;
  final double createPuzzlePiecesTime;
  final double shufflePiecesTime;
  final double applyNewDifficultyTime;
  final double pickImageTime;

  final double processAndInitializePuzzleTime;

  ImageProcessingData({
    required this.columns,
    required this.rows,
    required this.imageSize,
    required this.originalImageSize,
    required this.optimizedImageSize,
    required this.originalImageDimensions,
    required this.optimizedImageDimensions,
    required this.decodeImageTime,
    required this.createPuzzlePiecesTime,
    required this.shufflePiecesTime,
    required this.applyNewDifficultyTime,
    required this.processAndInitializePuzzleTime,
    required this.pickImageTime,
  });

  @override
  String toString() {
    return 'ImageProcessingData(columns: $columns, rows: $rows, imageSize: $imageSize, '
        'originalImageSize: $originalImageSize, optimizedImageSize: $optimizedImageSize, '
        'originalImageDimensions: $originalImageDimensions, optimizedImageDimensions: $optimizedImageDimensions, '
        'decodeImageTime: $decodeImageTime, createPuzzlePiecesTime: $createPuzzlePiecesTime, '
        'shufflePiecesTime: $shufflePiecesTime,'
        'processAndInitializePuzzleTime: $processAndInitializePuzzleTime,'
        'pickImageTime: $pickImageTime,'
        'applyNewDifficultyTime: $applyNewDifficultyTime )';
  }
}

///Riverpod : Facilite les tests unitaires et d'intégration en permettant
/// de remplacer facilement les providers par des mocks.
class PuzzleConfiguration {
  final int nbLines;
  final int nbCols;
  final double ratio;
  final int nbPieces;

  PuzzleConfiguration(this.nbLines, this.nbCols, this.ratio, this.nbPieces);
}

class PuzzleNotifier extends StateNotifier<PuzzleState> {
  static const String VERSION_KEY = 'puzzle_resources_version';
  static const String CURRENT_VERSION = '1.0.0';
  static final List<PuzzleConfiguration> configurations = [
    PuzzleConfiguration(3, 5, 0.60, 16),
    PuzzleConfiguration(4, 5, 0.80, 16),
    PuzzleConfiguration(5, 4, 1.25, 20),
    PuzzleConfiguration(4, 3, 1.33, 12),
    PuzzleConfiguration(3, 2, 1.50, 6),
    PuzzleConfiguration(5, 3, 1.67, 15),
    PuzzleConfiguration(9, 5, 1.8, 45),
    PuzzleConfiguration(4, 2, 2.00, 8),
    PuzzleConfiguration(5, 2, 2.50, 10),
    PuzzleConfiguration(4, 4, 1.00, 16),
    PuzzleConfiguration(5, 4, 1.25, 20),
    PuzzleConfiguration(4, 3, 1.33, 12),
    PuzzleConfiguration(3, 2, 1.50, 6),
    PuzzleConfiguration(5, 3, 1.67, 15),
    PuzzleConfiguration(4, 2, 2.00, 8),
    PuzzleConfiguration(5, 2, 2.50, 10),
  ];

  static const String METADATA_TAG = 'PuzzleAppMetadata';

  final Map<TurboOperation, bool> turbo = {
    TurboOperation.decodeImage: true,
    TurboOperation.createPuzzlePieces: false,
    TurboOperation.optimizeImage: true,
    TurboOperation.decodeImageForReconstruction: true,
    TurboOperation.createPiecesForReconstruction: true,
    TurboOperation.embedMetadata: true,
  };
  final FunctionCounter _counter = FunctionCounter();
  final List<ImageProcessingData> imageProcessingHistory = [];

  PuzzleNotifier()
      : super(PuzzleState(
          isInitialized: false,
          pieces: [],
          columns: 0,
          rows: 0,
          imageSize: Size.zero,
          currentArrangement: [],
          initialArrangement: [],
          hasSeenDocumentation: false,
        ));

  Future<void> applyNewDifficulty() async {
    if (state.fullImage != null) {
      await initializePuzzle(
        state.fullImage!,
        state.fullImage!,
        state.currentImageName ?? '',
        true,
        state.category,
      );
    }
  }

  // Garder l'ancienne méthode pour la compatibilité
  int countCorrectPieces() {
    _counter.increment('countCorrectPieces');
    return state.currentArrangement
        .asMap()
        .entries
        .where((entry) => entry.value == state.initialArrangement[entry.key])
        .length;
  }

  // Méthode pour choisir quelle fonction de comptage utiliser
  int countCorrectPiecesGeneral() {
    _counter.increment('countCorrectPiecesGeneral');
    if (state.isPUZType) {
      return countCorrectPiecesPUZ();
    } else {
      return countCorrectPieces();
    }
  }

  int countCorrectPiecesPUZ() {
    _counter.increment('countCorrectPiecesPUZ');

    int correctCount = 0;
    final current = state.currentArrangement;
    final initial = state.initialArrangement;

    for (int i = 0; i < current.length; i++) {
      if (initial[current[i]] == i) {
        correctCount++;
      }
    }

    debugPrint('Nombre de pièces correctes (PUZ): $correctCount');
    return correctCount;
  }

  Future<Uint8List> generateCurrentImage() async {
    _counter.increment('generateCurrentImage');
    final image = img.Image(
      width: state.imageSize.width.toInt(),
      height: state.imageSize.height.toInt(),
    );
    final pieceWidth = state.imageSize.width ~/ state.columns;
    final pieceHeight = state.imageSize.height ~/ state.rows;

    for (int i = 0; i < state.currentArrangement.length; i++) {
      final pieceIndex = state.currentArrangement[i];
      final pieceImageBytes = state.pieces[pieceIndex];
      final pieceImage = img.decodeJpg(pieceImageBytes);
      if (pieceImage != null) {
        final x = (i % state.columns) * pieceWidth;
        final y = (i ~/ state.columns) * pieceHeight;
        img.compositeImage(
          image,
          pieceImage,
          dstX: x.toInt(),
          dstY: y.toInt(),
        );
      }
    }

    // Encoder l'image finale en JPG
    final jpgImage = Uint8List.fromList(img.encodeJpg(image, quality: 70));
    debugPrint('Taille de limage complète JPG: ${jpgImage.length} bytes');
    return jpgImage;
  }

  String generateImageProcessingReport() {
    if (imageProcessingHistory.isEmpty) {
      return "Aucune donnée de traitement d'image disponible.";
    }

    StringBuffer report = StringBuffer();
    report.writeln("Données de traitement d'image :");
    report.writeln(
        "Nombre total d'images traitées : ${imageProcessingHistory.length}");
    report.writeln("");

    for (int i = 0; i < imageProcessingHistory.length; i++) {
      var data = imageProcessingHistory[i];
      report.writeln("Image ${i + 1} :");
      report.writeln(
          "Dimensions : ${data.imageSize.width.toInt()} x ${data.imageSize.height.toInt()}");
      report.writeln("Grille : ${data.columns} x ${data.rows}");
      report.writeln("Taille originale : ${data.originalImageSize} octets");
      report.writeln("Taille optimisée : ${data.optimizedImageSize} octets");
      report.writeln(
          "Temps de décodage : ${data.decodeImageTime.toStringAsFixed(2)} ms");
      report.writeln(
          "Temps de création des pièces : ${data.createPuzzlePiecesTime.toStringAsFixed(2)} ms");
      report.writeln(
          "Temps de mélange : ${data.shufflePiecesTime.toStringAsFixed(2)} ms");
      report.writeln(
          "applyNewDifficultyTime : ${data.applyNewDifficultyTime.toStringAsFixed(2)} ms");
      report.writeln(
          "processAndInitializePuzzleTime : ${data.processAndInitializePuzzleTime.toStringAsFixed(2)} ms");
      report.writeln(
          "pickImageTime : ${data.pickImageTime.toStringAsFixed(2)} ms");

      report.writeln("");
    }

    return report.toString();
  }

  // Ajoutez cette méthode pour accéder aux compteurs
  Map<String, int> getFunctionCounts() {
    return _counter.getAllCounts();
  }

  Map<String, dynamic> getMetaData(String filename) {
    _counter.increment('getMetaData');
    final name = filename.split('.').first;

    if (name.length < 11) {
      // PUZ + 2 (minutes) + 2 (secondes) + 2 (colonnes) + 2 (lignes) = 11
      throw Exception('Nom de fichier invalide');
    }

    final columns = int.parse(name.substring(7, 9));
    final rows = int.parse(name.substring(9, 11));
    final arrangement = name.substring(11);

    if (arrangement.length != columns * rows * 2) {
      throw Exception('Arrangement invalide dans le nom de fichier');
    }

    List<int> currentArrangement = [];
    for (int i = 0; i < arrangement.length; i += 2) {
      currentArrangement.add(int.parse(arrangement.substring(i, i + 2)));
    }

    return {
      'columns': columns,
      'rows': rows,
      'currentArrangement': currentArrangement,
      // Nous n'avons pas d'information sur l'arrangement initial dans le nom de fichier,
      // donc nous utiliserons l'arrangement actuel comme arrangement initial
      'initialArrangement':
          List<int>.generate(currentArrangement.length, (index) => index),
      'swapCount': 0,
      // Nous n'avons pas cette information dans le nom de fichier
      'imageTitle': 'Bingo'
    };
  }

  Future<void> initialize() async {
    _counter.increment('initialize');
  }

  Future<void> initializePuzzle(
    Uint8List originalImageBytes,
    Uint8List optimizedImageBytes,
    String imageName,
    bool isAssetImage,
    String category,
  ) async {
    _counter.increment('initializePuzzle');

    try {
      final imageToUse =
          isAssetImage ? originalImageBytes : optimizedImageBytes;

      if (imageToUse.isEmpty) {
        throw Exception("Image bytes are empty");
      }

      final image = turbo[TurboOperation.decodeImage]!
          ? await compute(img.decodeImage, imageToUse)
          : img.decodeImage(imageToUse);

      if (image == null) throw Exception("Impossible de décoder l'image");

      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final aspectRatio = image.width / image.height;

      final (columns, rows) = state.useCustomGridSize
          ? (state.difficultyCols, state.difficultyRows)
          : _determineOptimalGridSize(aspectRatio, 3, 5);

      final pieceHeight = image.height ~/ rows;
      final pieceWidth = image.width ~/ columns;

      final pieces = turbo[TurboOperation.createPuzzlePieces]!
          ? await compute(_createPuzzlePieces, {
              'image': image,
              'rows': rows,
              'columns': columns,
              'pieceheight': pieceHeight,
              'piecewidth': pieceWidth,
            })
          : _createPuzzlePieces({
              'image': image,
              'rows': rows,
              'columns': columns,
              'pieceheight': pieceHeight,
              'piecewidth': pieceWidth,
            });

      final initialArrangement = List.generate(pieces.length, (index) => index);
      final shuffledArrangement = List<int>.from(initialArrangement)..shuffle();

      state = state.copyWith(
        isInitialized: true,
        pieces: pieces,
        columns: columns,
        rows: rows,
        imageSize: imageSize,
        initialArrangement: initialArrangement,
        currentArrangement: shuffledArrangement,
        currentImageName: imageName,
        currentImageTitle: imageName,
        fullImage: imageToUse,
        swapCount: 0,
        minimalMoves: 0,
        originalImageSize: originalImageBytes.length,
        optimizedImageSize: isAssetImage
            ? originalImageBytes.length
            : optimizedImageBytes.length,
        originalImageDimensions: imageSize,
        optimizedImageDimensions: imageSize,
        category: category,
      );
    } catch (e) {
      debugPrint('Error during puzzle initialization: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  bool isGameComplete() {
    _counter.increment('isGameComplete');
    for (int i = 0; i < state.currentArrangement.length; i++) {
      if (state.currentArrangement[i] != i) {
        return false;
      }
    }
    return true;
  }

  bool isPuzzleComplete() {
    return state.currentArrangement
        .asMap()
        .entries
        .every((entry) => entry.key == entry.value);
  }

  Future<Map<String, dynamic>?> loadMetadata() async {
    _counter.increment('loadMetadata');
    return null;

    // ... (le code de loadMetadata reste ici)
  }

  Future<void> loadPuzzleFromImage(
      Uint8List imageBytes, String filename) async {
    _counter.increment('loadPuzzleFromImage');
    try {
      debugPrint(
          'Début du chargement du puzzle à partir de l\'image: $filename');
      final metadata = getMetaData(filename);
      debugPrint('Métadonnées extraites avec succès:');
      debugPrint('Colonnes: ${metadata['columns']}');
      debugPrint('Lignes: ${metadata['rows']}');
      debugPrint('Titre de l\'image: ${metadata['imageTitle']}');

      final initialArrangement =
          List<int>.from(metadata['initialArrangement'] as List<dynamic>);
      final currentArrangement =
          List<int>.from(metadata['currentArrangement'] as List<dynamic>);

      debugPrint('Début de la reconstruction du puzzle...');
      await reconstructPuzzle(
        metadata['columns'] as int,
        metadata['rows'] as int,
        // Ici J'inverse
        currentArrangement,
        initialArrangement,

        metadata['swapCount'] as int,
        imageBytes,
        metadata['imageTitle'] as String,
      );
      state = state.copyWith(isPUZType: true);
      debugPrint('Reconstruction du puzzle terminée');
      debugPrint('Nombre de coups: ${metadata['swapCount']}');
      debugPrint('Taille de l\'image: ${imageBytes.length} octets');
      debugPrint('Puzzle chargé avec succès');
    } catch (e) {
      debugPrint('Erreur lors du chargement de l\'image: $e');
      throw Exception('Erreur lors du chargement de l\'image: $e');
    }
  }

  Future<Uint8List> optimizeImage(Uint8List imageBytes,
      {int quality = 75}) async {
    _counter.increment('optimizeImage');
    return turbo[TurboOperation.optimizeImage]!
        ? await compute(
            (Map<String, dynamic> args) =>
                _optimizeImage(args['imageBytes'], args['quality']),
            {'imageBytes': imageBytes, 'quality': quality})
        : _optimizeImage(imageBytes, quality);
  }

  Future<void> reconstructPuzzle(
    int columns,
    int rows,
    List<int> initialArrangement,
    List<int> currentArrangement,
    int swapCount,
    Uint8List imageBytes,
    String imageTitle,
  ) async {
    _counter.increment('reconstructPuzzle');
    setLoading(true);

    try {
      final image = turbo[TurboOperation.decodeImageForReconstruction]!
          ? await compute(img.decodeImage, imageBytes)
          : img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception("Impossible de décoder l'image");
      }

      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      int pieceHeight = image.height ~/ rows;
      int pieceWidth = image.width ~/ columns;

      final pieces = turbo[TurboOperation.createPiecesForReconstruction]!
          ? await compute(_createPuzzlePieces, {
              'image': image,
              'rows': rows,
              'columns': columns,
              'pieceheight': pieceHeight,
              'piecewidth': pieceWidth,
            })
          : _createPuzzlePieces({
              'image': image,
              'rows': rows,
              'columns': columns,
              'pieceheight': pieceHeight,
              'piecewidth': pieceWidth,
            });

      state = state.copyWith(
        isInitialized: true,
        pieces: pieces,
        columns: columns,
        rows: rows,
        imageSize: imageSize,
        initialArrangement: initialArrangement,
        currentArrangement: currentArrangement,
        currentImageName: imageTitle,
        currentImageTitle: imageTitle,
        fullImage: imageBytes,
        swapCount: swapCount,
      );

      setLoading(false);
    } catch (e) {
      debugPrint("Erreur lors de la reconstruction du puzzle: $e");
      setError("Erreur lors de la reconstruction du puzzle");
      setLoading(false);
    }
  }

  img.Image removeColumnsAndRows(
      img.Image source, int columnsToRemove, int rowsToRemove,
      {RemoveDirection columnDirection = RemoveDirection.fromEnd,
      RemoveDirection rowDirection = RemoveDirection.fromEnd}) {
    _counter.increment('removeColumnsAndRows');
    int newWidth = source.width - columnsToRemove;
    int newHeight = source.height - rowsToRemove;

    img.Image result = img.Image(width: newWidth, height: newHeight);

    int xOffset =
        columnDirection == RemoveDirection.fromStart ? columnsToRemove : 0;
    int yOffset = rowDirection == RemoveDirection.fromStart ? rowsToRemove : 0;

    for (int y = 0; y < newHeight; y++) {
      for (int x = 0; x < newWidth; x++) {
        result.setPixel(x, y, source.getPixel(x + xOffset, y + yOffset));
      }
    }

    return result;
  }

  img.Image removeExcessPixels(img.Image image, int columns, int rows) {
    int baseWidth = image.width ~/ columns;
    int baseHeight = image.height ~/ rows;

    int newWidth = baseWidth * columns;
    int newHeight = baseHeight * rows;

    // Créer une nouvelle image avec les dimensions ajustées
    img.Image adjustedImage = img.Image(width: newWidth, height: newHeight);

    // Copier les pixels de l'image originale vers la nouvelle image
    for (int y = 0; y < newHeight; y++) {
      for (int x = 0; x < newWidth; x++) {
        adjustedImage.setPixel(
            x, y, image.getPixel(x, image.height - newHeight + y));
      }
    }

    return adjustedImage;
  }

  void resetSwapCount() {
    state = state.copyWith(swapCount: 0);
  }

  void resetToOptimalGridSize() {
    state = state.copyWith(useCustomGridSize: false);
  }

  Future<void> saveMetadata(String imageName) async {
    _counter.increment('saveMetadata');
  }

  Future<void> savePuzzleState([String? imageName]) async {
    _counter.increment('savePuzzleState');
  }

  Future<void> savePuzzleStateWithImage() async {
    try {
      final currentImage = await generateCurrentImage();
      final metadata = {
        'timestamp': DateTime.now().toIso8601String(),
        'imageTitle': state.currentImageTitle,
        'columns': state.columns,
        'rows': state.rows,
        'initialArrangement': state.initialArrangement,
        'currentArrangement': state.currentArrangement,
        'swapCount': state.swapCount,
        'minimalMoves': state.minimalMoves,
      };
      final metadataJson = jsonEncode(metadata);
      final imageWithMetadata = turbo[TurboOperation.embedMetadata]!
          ? await compute(_embedMetadataInImage, {
              'image': currentImage,
              'metadata': metadataJson,
            })
          : await _embedMetadataInImage({
              'image': currentImage,
              'metadata': metadataJson,
            });

      final fileName = _generateFileName();
      if (kIsWeb) {
        _saveImageToDownloads(imageWithMetadata, '$fileName.jpg');
      } else {
        await _saveImageLocally(imageWithMetadata, '$fileName.jpg');
      }
      debugPrint('Puzzle sauvegardé avec succès sous le nom: $fileName.jpg');
    } catch (e) {
      debugPrint('Erreur lors de la sauvegarde du puzzle: $e');
    }
  }

  void setCategory(String category) {
    _counter.increment('setCategory');
    state = state.copyWith(category: category);
  }

  // Dans la classe PuzzleNotifier, ajoutez ces méthodes :
  void setColumns(int columns) {
    _counter.increment('setColumns');
    state = state.copyWith(columns: columns);
  }

  void setDifficulty(int cols, int rows) {
    _counter.increment('setDifficulty');
    state = state.copyWith(
      difficultyCols: cols,
      difficultyRows: rows,
      useCustomGridSize: true,
    );
  }

  void setDocumentationSeen() {
    _counter.increment('setDocumentationSeen');
    // ... (le code de setDocumentationSeen reste ici)
  }

  void setError(String errorMessage) {
    _counter.increment('setError');
    state = state.copyWith(error: errorMessage);
  }

  void setImageTitle(String title) {
    _counter.increment('setImageTitle');
    state = state.copyWith(currentImageTitle: title);
  }

  void setLoading(bool isLoading) {
    _counter.increment('setLoading');
    if (state.isLoading != isLoading) {
      state = state.copyWith(isLoading: isLoading);
    }
  }

  void setPuzzleReady(bool ready) {
    _counter.increment('setPuzzleReady');
    state = state.copyWith(isInitialized: ready);
  }

  void setRows(int rows) {
    state = state.copyWith(rows: rows);
  }

  void shufflePieces() {
    _counter.increment('shufflePieces');

    final random = Random();
    final n = state.pieces.length;
    final swapCount = n + random.nextInt((n / 4).round() + 1);

    final newArrangement = List.generate(n, (index) => index);
    for (int i = 0; i < swapCount; i++) {
      final index1 = random.nextInt(n);
      int index2;
      do {
        index2 = random.nextInt(n);
      } while (index2 == index1);

      final temp = newArrangement[index1];
      newArrangement[index1] = newArrangement[index2];
      newArrangement[index2] = temp;
    }

    state = state.copyWith(
      currentArrangement: newArrangement,
      minimalMoves: swapCount,
      swapCount: 0,
    );
  }

  void storeImageProcessingData() {

    final report = profiler.report();
    print("_storeImageProcessingData-**>" + report);

    // Extraire les temps du rapport
    double decodeImageTime = 0.0;
    double createPuzzlePiecesTime = 0.0;
    double shufflePiecesTime = 0.0;
    double applyNewDifficultyTime = 0.0;
    double processAndInitializePuzzleTime = 0.0;
    double pickImageTime = 0.0;
    final lines = report.split('\n');
    for (var line in lines) {
      print("line = $line");
      final parts = line.split(':');
      if (parts.length == 2) {
        final name = parts[0].trim();
        final timeString = parts[1].trim();
        final timeValue = double.tryParse(timeString.split('ms')[0].trim());

        if (timeValue != null) {
          print("name = $name, time = $timeValue");

          if (name == 'initializePuzzle-decodeImage') {
            decodeImageTime = timeValue;
          } else if (name == 'createPuzzlePieces') {
            createPuzzlePiecesTime = timeValue;
          } else if (name == 'shufflePieces') {
            shufflePiecesTime = timeValue;
          }
          //applyNewDifficulty
          else if (name == 'applyNewDifficulty') {
            applyNewDifficultyTime = timeValue;
          } else if (name == 'pickImage') {
            pickImageTime = timeValue;
          } else if (name == 'processAndInitializePuzzle') {
            processAndInitializePuzzleTime = timeValue;
          }
        }
      }
    }

    final data = ImageProcessingData(
        columns: state.columns,
        rows: state.rows,
        imageSize: state.imageSize,
        originalImageSize: state.originalImageSize,
        optimizedImageSize: state.optimizedImageSize,
        originalImageDimensions: state.originalImageDimensions,
        optimizedImageDimensions: state.optimizedImageDimensions,
        decodeImageTime: decodeImageTime,
        createPuzzlePiecesTime: createPuzzlePiecesTime,
        shufflePiecesTime: shufflePiecesTime,
        applyNewDifficultyTime: applyNewDifficultyTime,
        pickImageTime: pickImageTime,
        processAndInitializePuzzleTime: processAndInitializePuzzleTime);
    imageProcessingHistory.add(data);
    debugPrint('Stored image processing data: $data');

    // Réinitialiser le profileur après avoir stocké les données
  }

  void swapPieces(int index1, int index2) {
    _counter.increment('swapPieces');
    final newArrangement = List<int>.from(state.currentArrangement);
    final temp = newArrangement[index1];
    newArrangement[index1] = newArrangement[index2];
    newArrangement[index2] = temp;

    //debugPrint('Arrangement current: $newArrangement');
    state = state.copyWith(
      currentArrangement: newArrangement,
      swapCount: state.swapCount + 1,
    );
  }

  void updatePuzzleState() {
    _counter.increment('updatePuzzleState');
    savePuzzleState();
  }

  List<Uint8List> _createPuzzlePieces(Map<String, dynamic> params) {
    final img.Image image = params['image'];
    final int rows = params['rows'];
    final int columns = params['columns'];
    final int pieceHeight = params['pieceheight'];
    final int pieceWidth = params['piecewidth'];

    final pieces = <Uint8List>[];
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < columns; x++) {
        final piece = img.copyCrop(
          image,
          x: x * pieceWidth,
          y: y * pieceHeight,
          width: pieceWidth,
          height: pieceHeight,
        );
        // Encoder en JPG au lieu de PNG
        final jpgPiece = Uint8List.fromList(img.encodeJpg(piece, quality: 70));

        pieces.add(jpgPiece);
      }
    }
    return pieces;
  }

  (int columns, int rows) _determineOptimalGridSize(
      double aspectRatio, int minColumns, int maxColumns) {
    int bestColumns = minColumns;
    int bestRows = (minColumns / aspectRatio).round();
    double bestError = double.infinity;

    for (int testColumns = minColumns;
        testColumns <= maxColumns;
        testColumns++) {
      int testRows = (testColumns / aspectRatio).round();

      // Assurer un minimum de 3 lignes
      testRows = testRows < 3 ? 3 : testRows;

      double currentRatio = testColumns / testRows;
      double error = (currentRatio - aspectRatio).abs();

      if (error < bestError) {
        bestError = error;
        bestColumns = testColumns;
        bestRows = testRows;
      }
    }

    // Ajuster pour éviter les grilles 3x3 et 5x5 si nécessaire
    if (bestRows == 5 && bestColumns == 5) {
      bestRows = 4;
      bestColumns = 4;
    }
    if (bestRows == 3 && bestColumns == 3) {
      bestRows = 4;
      bestColumns = 4;
    }
    if (bestRows > 5) bestRows = 5;
    if (bestColumns > 5) bestColumns = 5;
    return (bestColumns, bestRows);
  }

  String _generateFileName() {
    final now = DateTime.now();
    final minutes = now.minute.toString().padLeft(2, '0');
    final seconds = now.second.toString().padLeft(2, '0');
    final columns = state.columns.toString().padLeft(2, '0');
    final rows = state.rows.toString().padLeft(2, '0');

    String arrangement = state.currentArrangement
        .map((e) => e.toString().padLeft(2, '0'))
        .join();

    return 'PUZ$minutes$seconds$columns$rows$arrangement';
  }

  Uint8List _optimizeImage(Uint8List imageBytes, int quality) {
    _counter.increment('_optimizeImage');

    final originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) {
      throw Exception("Impossible de décoder l'image originale");
    }

    originalImage.exif.clear();

    // Réencoder l'image avec la qualité spécifiée
    final optimizedBytes = img.encodeJpg(originalImage, quality: quality);
    debugPrint("Taille après optimisation: ${optimizedBytes.length} bytes");

    return Uint8List.fromList(optimizedBytes);
  }

  Future<String> _saveImageLocally(
      Uint8List imageBytes, String fileName) async {
    if (kIsWeb) {
      final base64Image = base64Encode(imageBytes);
      html.window.localStorage[fileName] = base64Image;
      return 'localStorage://$fileName';
    } else {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      debugPrint('Image sauvegardée sur l\'appareil : $filePath');
      await file.writeAsBytes(imageBytes);
      return filePath;
    }
  }

  void _saveImageToDownloads(Uint8List imageBytes, String fileName) {
    final blob = html.Blob([imageBytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = fileName;
    html.document.body!.children.add(anchor);

    // Déclencher le téléchargement
    anchor.click();

    // Nettoyer
    html.document.body!.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
  }

  static Future<Uint8List> _embedMetadataInImage(
      Map<String, dynamic> params) async {
    final imageBytes = params['image'] as Uint8List;
    final metadata = params['metadata'] as String;

    final image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception("Impossible de décoder l'image");
    }

    img.drawString(
      image,
      'PUZZLE_METADATA:$metadata',
      font: img.arial14,
      x: 10,
      y: 10,
      color: img.ColorRgba8(255, 255, 255, 100),
    );

    return Uint8List.fromList(img.encodeJpg(image));
  }
}

///Définition :
///StateNotifier est une classe qui gère un état mutable de manière immutable.
/// Elle est conçue pour être utilisée avec Riverpod,
///Elle contient un état (state) qui peut être mis à jour.
///Chaque mise à jour de l'état crée une nouvelle instance de létat,
///respectant ainsi le principe d'immutabilité.

class PuzzleState {
  final bool isInitialized;
  final List<Uint8List> pieces;
  final int columns;
  final int rows;
  final int difficultyCols;
  final int difficultyRows;
  final bool useCustomGridSize;
  final Size imageSize;
  final Uint8List? shuffledImage;
  final Uint8List? fullImage;
  final String? currentImageName;
  final String currentImageTitle;
  final bool hasSeenDocumentation;
  final String? error;
  final int swapCount;
  final int minimalMoves;
  final int originalImageSize;
  final int optimizedImageSize;
  final Size originalImageDimensions;
  final Size optimizedImageDimensions;
  final bool isLoading;
  final String category;

  final List<int> initialArrangement;
  final List<int> currentArrangement;
  final bool isPUZType;

  const PuzzleState({
    this.isInitialized = false,
    this.pieces = const [],
    this.columns = 1,
    this.rows = 1,
    this.difficultyCols = 4,
    this.difficultyRows = 4,
    this.useCustomGridSize = false,
    this.imageSize = Size.zero,
    this.currentArrangement = const [],
    this.shuffledImage,
    this.fullImage,
    this.currentImageName,
    this.currentImageTitle = '',
    this.hasSeenDocumentation = false,
    this.error,
    this.swapCount = 0,
    this.minimalMoves = 0,
    this.originalImageSize = 0,
    this.optimizedImageSize = 0,
    this.originalImageDimensions = Size.zero,
    this.optimizedImageDimensions = Size.zero,
    this.isLoading = false,
    this.category = '',
    this.isPUZType = false,
    this.initialArrangement = const [],
  });

  PuzzleState copyWith({
    bool? isInitialized,
    List<Uint8List>? pieces,
    int? columns,
    int? rows,
    int? difficultyCols,
    int? difficultyRows,
    bool? useCustomGridSize,
    Size? imageSize,
    List<int>? currentArrangement,
    Uint8List? shuffledImage,
    Uint8List? fullImage,
    String? currentImageName,
    String? currentImageTitle,
    bool? hasSeenDocumentation,
    String? error,
    int? swapCount,
    int? minimalMoves,
    int? originalImageSize,
    int? optimizedImageSize,
    Size? originalImageDimensions,
    Size? optimizedImageDimensions,
    bool? isLoading,
    String? category,
    List<int>? initialArrangement,
    bool? isPUZType,
  }) {
    return PuzzleState(
      isInitialized: isInitialized ?? this.isInitialized,
      pieces: pieces ?? this.pieces,
      columns: columns ?? this.columns,
      rows: rows ?? this.rows,
      difficultyCols: difficultyCols ?? this.difficultyCols,
      difficultyRows: difficultyRows ?? this.difficultyRows,
      useCustomGridSize: useCustomGridSize ?? this.useCustomGridSize,
      imageSize: imageSize ?? this.imageSize,
      currentArrangement: currentArrangement ?? this.currentArrangement,
      shuffledImage: shuffledImage ?? this.shuffledImage,
      fullImage: fullImage ?? this.fullImage,
      currentImageName: currentImageName ?? this.currentImageName,
      currentImageTitle: currentImageTitle ?? this.currentImageTitle,
      hasSeenDocumentation: hasSeenDocumentation ?? this.hasSeenDocumentation,
      error: error ?? this.error,
      swapCount: swapCount ?? this.swapCount,
      minimalMoves: minimalMoves ?? this.minimalMoves,
      originalImageSize: originalImageSize ?? this.originalImageSize,
      optimizedImageSize: optimizedImageSize ?? this.optimizedImageSize,
      originalImageDimensions:
          originalImageDimensions ?? this.originalImageDimensions,
      optimizedImageDimensions:
          optimizedImageDimensions ?? this.optimizedImageDimensions,
      isLoading: isLoading ?? this.isLoading,
      category: category ?? this.category,
      initialArrangement: initialArrangement ?? this.initialArrangement,
      isPUZType: isPUZType ?? this.isPUZType,
    );
  }
}

///StateNotifierProvider :
/// Utilisé pour des états plus complexes avec une logique de mise à jour encapsulée.
enum RemoveDirection { fromStart, fromEnd }

///Encapsulation : Le notifier encapsule toute la logique de gestion de l'état du puzzle.
/// Séparation des préoccupations : L'état (PuzzleState) est séparé de la logique qui le modifie (PuzzleNotifier).
/// Accès aux méthodes : .notifier permet d'accéder aux méthodes qui ne sont pas directement dans l'état,
/// comme countCorrectPieces().

/// En résumé, le notifier du puzzleProvider est l'objet qui contient toute la logique pour manipuler et
/// interroger l'état du puzzle. C'est le "cerveau" derrière la gestion de l'état de votre puzzle dans
/// le contexte de Riverpod.

enum TurboOperation {
  decodeImage,
  createPuzzlePieces,
  optimizeImage,
  decodeImageForReconstruction,
  createPiecesForReconstruction,
  embedMetadata,
}
