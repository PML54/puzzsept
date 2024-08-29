import 'dart:collection';

class Profiler {
  final Map<String, _ProfilePoint> _points = {};
  final Queue<String> _activePoints = Queue();
  Map<String, double> _timings = {};
  void start(String name) {
    if (_activePoints.isNotEmpty) {
      _points[_activePoints.last]!.children[name] = _ProfilePoint(name);
    } else {
      _points[name] = _ProfilePoint(name);
    }
    _activePoints.addLast(name);
    _points[name]!.start();
  }

  void end(String name) {
    if (_activePoints.last != name) {
      throw Exception('Profiler: Trying to end "$name" but "${_activePoints.last}" is active');
    }
    _points[name]!.end();
    _activePoints.removeLast();
  }

  String report() {
    StringBuffer buffer = StringBuffer();
    _points.values.where((point) => point.parent == null).forEach((point) {
      _addReportLine(buffer, point, 0);
    });
    return buffer.toString();
  }

  void _addReportLine(StringBuffer buffer, _ProfilePoint point, int depth) {
    buffer.writeln('${' ' * depth * 2}${point.name}: ${point.duration.inMilliseconds}ms');
    point.children.values.forEach((child) {
      _addReportLine(buffer, child, depth + 1);
    });
  }
  void reset() {
    // Réinitialiser toutes les mesures
    _timings.clear();
    print('Profiler has been reset');
  }
}

class _ProfilePoint {
  final String name;
  final Map<String, _ProfilePoint> children = {};
  _ProfilePoint? parent;
  Stopwatch _stopwatch = Stopwatch();
  Duration duration = Duration.zero;

  _ProfilePoint(this.name);

  void start() {
    _stopwatch.start();
  }

  void end() {
    _stopwatch.stop();
    duration = _stopwatch.elapsed;
  }
}

// Instance globale du Profiler
final profiler = Profiler();