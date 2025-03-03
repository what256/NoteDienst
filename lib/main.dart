import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

import 'models/note.dart';
import 'db/db_helper.dart';
import 'statistics_page.dart';
import 'calendar_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DBHelper.instance.initDB();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FieldLog',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: NotesTimeline(),
    );
  }
}

class NotesTimeline extends StatefulWidget {
  @override
  _NotesTimelineState createState() => _NotesTimelineState();
}

class _NotesTimelineState extends State<NotesTimeline> {
  List<Note> notes = [];
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _voiceText = '';
  String _searchQuery = '';

  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
    _loadNotes();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  void _initSpeech() async {
    await _speech.initialize();
  }

  Future<void> _loadNotes() async {
    notes = await DBHelper.instance.getNotes();
    setState(() {});
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(onStatus: (status) {}, onError: (error) {});
      if (available) {
        setState(() {
          _isListening = true;
        });
        _speech.listen(onResult: (result) async {
          setState(() {
            _voiceText = result.recognizedWords;
          });
          if (result.finalResult) {
            setState(() {
              _isListening = false;
            });
            // Speichere die transkribierte Notiz in der Datenbank
            Note newNote = Note(
              content: _voiceText,
              timestamp: DateTime.now(),
              latitude: 0.0,
              longitude: 0.0,
            );
            await DBHelper.instance.insertNote(newNote);
            _loadNotes();
          }
        });
      }
    } else {
      setState(() {
        _isListening = false;
      });
      _speech.stop();
    }
  }

  void _editNote(Note note) {
    TextEditingController contentController = TextEditingController(text: note.content);
    TextEditingController tagController = TextEditingController(text: note.tag);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Notiz bearbeiten'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: contentController,
                decoration: InputDecoration(hintText: 'Inhalt der Notiz'),
              ),
              SizedBox(height: 8),
              TextField(
                controller: tagController,
                decoration: InputDecoration(hintText: 'Tag / Farbcodierung'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () async {
                note.content = contentController.text;
                note.tag = tagController.text;
                await DBHelper.instance.updateNote(note);
                _loadNotes();
                Navigator.of(context).pop();
              },
              child: Text('Speichern'),
            ),
          ],
        );
      },
    );
  }

  void _deleteNote(Note note) async {
    if (note.id != null) {
      await DBHelper.instance.deleteNote(note.id!);
      _loadNotes();
    }
  }

  Future<void> _backupNotes() async {
    List<Note> allNotes = await DBHelper.instance.getNotes();
    List<Map<String, dynamic>> notesMap = allNotes.map((n) => n.toMap()).toList();
    String jsonString = jsonEncode(notesMap);
    Directory directory = await getApplicationDocumentsDirectory();
    File file = File('${directory.path}/backup.json');
    await file.writeAsString(jsonString);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup erstellt!')));
  }

  Future<void> _restoreNotes() async {
    Directory directory = await getApplicationDocumentsDirectory();
    File file = File('${directory.path}/backup.json');
    if (await file.exists()) {
      String jsonString = await file.readAsString();
      List<dynamic> notesData = jsonDecode(jsonString);
      for (final noteData in notesData) {
        Note note = Note.fromMap(Map<String, dynamic>.from(noteData));
        await DBHelper.instance.insertNote(note);
      }
      _loadNotes();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Wiederherstellung abgeschlossen!')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kein Backup gefunden!')));
    }
  }

  // Hilfsfunktion, um basierend auf dem Tag eine Farbe zuzuordnen
  Color getTagColor(String tag) {
    String lowerTag = tag.toLowerCase();
    if (lowerTag.contains('wichtig') || lowerTag.contains('dringend')) return Colors.red;
    if (lowerTag.contains('arbeit')) return Colors.blue;
    if (lowerTag.contains('privat')) return Colors.green;
    return Colors.grey;
  }

  // Automatische Standorterfassung alle 30 Minuten
  void _startLocationTracking() {
    // Setze Timer auf 30 Minuten Intervall
    _locationTimer = Timer.periodic(Duration(minutes: 30), (Timer timer) async {
      try {
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        // Erstelle eine Notiz mit Standortdaten
        Note locationNote = Note(
          content: 'Automatisches Standort-Update',
          timestamp: DateTime.now(),
          latitude: position.latitude,
          longitude: position.longitude,
          tag: 'Standort',
        );
        await DBHelper.instance.insertNote(locationNote);
        _loadNotes();
      } catch (e) {
        print('Fehler beim Abrufen des Standorts: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Note> filteredNotes = notes.where((note) => note.content.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('FieldLog Timeline'),
        actions: [
          IconButton(
            icon: Icon(Icons.backup),
            onPressed: _backupNotes,
          ),
          IconButton(
            icon: Icon(Icons.restore),
            onPressed: _restoreNotes,
          ),
          IconButton(
            icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
            onPressed: _listen,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              child: Text('FieldLog Menü', style: TextStyle(color: Colors.white, fontSize: 24)),
              decoration: BoxDecoration(color: Colors.blue),
            ),
            ListTile(
              leading: Icon(Icons.list),
              title: Text('Notizen'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.calendar_today),
              title: Text('Kalender'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => CalendarPage(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                  transitionDuration: Duration(milliseconds: 500),
                ));
              },
            ),
            ListTile(
              leading: Icon(Icons.insert_chart),
              title: Text('Statistiken'),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => StatisticsPage()));
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Suche',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredNotes.length,
              itemBuilder: (context, index) {
                Note note = filteredNotes[index];
                return Dismissible(
                  key: ValueKey(note.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    _deleteNote(note);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Notiz gelöscht')));
                  },
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: getTagColor(note.tag),
                      child: Text(note.tag.isNotEmpty ? note.tag[0].toUpperCase() : '?', style: TextStyle(color: Colors.white)),
                    ),
                    title: Text(note.content),
                    subtitle: Text(note.timestamp.toIso8601String()),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(note.isFavorite ? Icons.star : Icons.star_border),
                          color: note.isFavorite ? Colors.amber : null,
                          onPressed: () async {
                            note.isFavorite = !note.isFavorite;
                            await DBHelper.instance.updateNote(note);
                            _loadNotes();
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.edit),
                          onPressed: () {
                            _editNote(note);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Dummy-Note zum Hinzufügen
          Note newNote = Note(
            content: 'Neue Notiz',
            timestamp: DateTime.now(),
            latitude: 0.0,
            longitude: 0.0,
          );
          await DBHelper.instance.insertNote(newNote);
          _loadNotes();
        },
        child: Icon(Icons.add),
      ),
    );
  }
} 