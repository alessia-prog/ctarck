import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const ChastityTrackerApp());
}

class ChastityTrackerApp extends StatelessWidget {
  const ChastityTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chastity Tracker',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime? _startTime;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  final List<File> _images = [];
  final List<String> _notes = [];
  final List<String> _openings = [];
  File? _backgroundImage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Lade Startzeit
    final startMillis = prefs.getInt('startTime');
    if (startMillis != null) {
      _startTime = DateTime.fromMillisecondsSinceEpoch(startMillis);
      _startTimer();
    }

    // Lade bisherige Tragedauer
    final elapsedSecs = prefs.getInt('elapsed') ?? 0;
    setState(() {
      _elapsed = Duration(seconds: elapsedSecs);
    });

    // Lade Hintergrundbild
    final bgPath = prefs.getString('background');
    if (bgPath != null && File(bgPath).existsSync()) {
      setState(() => _backgroundImage = File(bgPath));
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();

    // Speichere Startzeit
    if (_startTime != null) {
      await prefs.setInt('startTime', _startTime!.millisecondsSinceEpoch);
    } else {
      await prefs.remove('startTime');
    }

    // Speichere Tragedauer
    await prefs.setInt('elapsed', _elapsed.inSeconds);

    // Speichere Hintergrundbild
    if (_backgroundImage != null) {
      await prefs.setString('background', _backgroundImage!.path);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (_startTime != null) {
          _elapsed = DateTime.now().difference(_startTime!);
        }
      });
      _saveData();
    });
  }

  void _startTracking() {
    setState(() {
      _startTime = DateTime.now();
      _elapsed = Duration.zero;
    });
    _startTimer();
    _saveData();
  }

  void _stopTracking() {
    _timer?.cancel();
    setState(() {
      _startTime = null;
    });
    _saveData();
  }

  Future<void> _setManualStartDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime == null) return;

    final newStart = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      _startTime = newStart;
      _elapsed = DateTime.now().difference(newStart);
    });
    _startTimer();
    _saveData();
  }

  Future<void> _addImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final dir = await getApplicationDocumentsDirectory();
      final saved = await File(
        picked.path,
      ).copy('${dir.path}/${DateTime.now().millisecondsSinceEpoch}.png');
      setState(() {
        _images.add(saved);
      });
    }
  }

  Future<void> _addNote() async {
    String? note = await showDialog<String>(
      context: context,
      builder: (context) {
        String temp = '';
        return AlertDialog(
          title: const Text('Neue Notiz'),
          content: TextField(
            onChanged: (v) => temp = v,
            decoration: const InputDecoration(hintText: 'Notiz hier eingeben'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, temp),
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    );
    if (note != null && note.isNotEmpty) {
      setState(() => _notes.add(note));
    }
  }

  Future<void> _addOpening() async {
    String? opening = await showDialog<String>(
      context: context,
      builder: (context) {
        String temp = '';
        return AlertDialog(
          title: const Text('Neue Öffnung'),
          content: TextField(
            onChanged: (v) => temp = v,
            decoration: const InputDecoration(
              hintText: 'z.B. Reinigung am 21.08.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, temp),
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    );
    if (opening != null && opening.isNotEmpty) {
      setState(() => _openings.add(opening));
    }
  }

  Future<void> _pickBackgroundImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final dir = await getApplicationDocumentsDirectory();
      final saved = await File(picked.path).copy('${dir.path}/background.png');
      setState(() {
        _backgroundImage = saved;
      });
      _saveData();
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _saveData();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chastity Tracker')),
      body: Container(
        decoration: BoxDecoration(
          image: _backgroundImage != null
              ? DecorationImage(
                  image: FileImage(_backgroundImage!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tragedauer: ${_formatDuration(_elapsed)}',
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _startTime == null ? _startTracking : null,
                    child: const Text('Start'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _startTime != null ? _stopTracking : null,
                    child: const Text('Stop'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _setManualStartDate,
                    child: const Text('Startdatum setzen'),
                  ),
                ],
              ),
              const Divider(height: 32, color: Colors.black54),
              ElevatedButton.icon(
                icon: const Icon(Icons.image),
                label: const Text('Bild hinzufügen'),
                onPressed: _addImage,
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _images
                    .map(
                      (img) => Image.file(
                        img,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    )
                    .toList(),
              ),
              const Divider(height: 32, color: Colors.black54),
              ElevatedButton.icon(
                icon: const Icon(Icons.note_add),
                label: const Text('Notiz hinzufügen'),
                onPressed: _addNote,
              ),
              ..._notes.map((n) => ListTile(title: Text(n))).toList(),
              const Divider(height: 32, color: Colors.black54),
              ElevatedButton.icon(
                icon: const Icon(Icons.lock_open),
                label: const Text('Öffnung hinzufügen'),
                onPressed: _addOpening,
              ),
              ..._openings.map((o) => ListTile(title: Text(o))).toList(),
              const Divider(height: 32, color: Colors.black54),
              ElevatedButton.icon(
                icon: const Icon(Icons.wallpaper),
                label: const Text('Hintergrundbild ändern'),
                onPressed: _pickBackgroundImage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
