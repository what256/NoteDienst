import 'package:flutter/material.dart';
import 'models/note.dart';
import 'db/db_helper.dart';

class StatisticsPage extends StatefulWidget {
  @override
  _StatisticsPageState createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  Map<String, int> tagCounts = {};
  int totalNotes = 0;

  @override
  void initState() {
    super.initState();
    loadStatistics();
  }

  Future<void> loadStatistics() async {
    List<Note> notes = await DBHelper.instance.getNotes();
    totalNotes = notes.length;
    Map<String, int> counts = {};
    for (final note in notes) {
      String tag = note.tag.trim();
      if (tag.isEmpty) {
        tag = 'Uncategorized';
      }
      counts[tag] = (counts[tag] ?? 0) + 1;
    }
    setState(() {
      tagCounts = counts;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Statistiken'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gesamtanzahl Notizen: $totalNotes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            Text('Notizen nach Tag:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                itemCount: tagCounts.length,
                itemBuilder: (context, index) {
                  String tag = tagCounts.keys.elementAt(index);
                  int count = tagCounts[tag]!;
                  return ListTile(
                    title: Text('$tag'),
                    trailing: Text('$count'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
} 