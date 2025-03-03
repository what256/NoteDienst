import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'dart:async';

import 'models/note.dart';
import 'db/db_helper.dart';

class CalendarPage extends StatefulWidget {
  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Note> _notes = [];
  List<Note> _filteredNotes = [];
  String _connectivityStatus = 'Unbekannt';
  List<String> _bluetoothDevices = [];
  StreamSubscription? _connectivitySubscription;
  FlutterBlue _flutterBlue = FlutterBlue.instance;
  StreamSubscription? _bluetoothSubscription;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadNotes();
    _initConnectivity();
    _startBluetoothScan();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _bluetoothSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    List<Note> notes = await DBHelper.instance.getNotes();
    setState(() {
      _notes = notes;
      _filterNotes();
    });
  }

  void _filterNotes() {
    if (_selectedDay != null) {
      _filteredNotes = _notes.where((note) {
        return note.timestamp.year == _selectedDay!.year &&
            note.timestamp.month == _selectedDay!.month &&
            note.timestamp.day == _selectedDay!.day;
      }).toList();
    } else {
      _filteredNotes = _notes;
    }
  }

  void _initConnectivity() {
    Connectivity().checkConnectivity().then((result) {
      _updateConnectivityStatus(result);
    });
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      _updateConnectivityStatus(result);
    });
  }

  void _updateConnectivityStatus(ConnectivityResult result) {
    setState(() {
      switch (result) {
        case ConnectivityResult.wifi:
          _connectivityStatus = 'WLAN';
          break;
        case ConnectivityResult.mobile:
          _connectivityStatus = 'Mobile Daten';
          break;
        case ConnectivityResult.none:
          _connectivityStatus = 'Keine Verbindung';
          break;
        default:
          _connectivityStatus = 'Unbekannt';
          break;
      }
    });
  }

  void _startBluetoothScan() {
    _bluetoothDevices.clear();
    _bluetoothSubscription = _flutterBlue.scan(timeout: Duration(seconds: 5)).listen((result) {
      setState(() {
        String deviceName = result.device.name;
        if (deviceName.isEmpty) deviceName = result.device.id.toString();
        if (!_bluetoothDevices.contains(deviceName)) {
          _bluetoothDevices.add(deviceName);
        }
      });
    }, onDone: () {
      _flutterBlue.stopScan();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kalender & Geräte'),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime(2000, 1, 1),
            lastDay: DateTime(2100, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
                _filterNotes();
              });
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aktuelle Verbindung: $_connectivityStatus', style: TextStyle(fontSize: 16)),
                SizedBox(height: 8),
                Text('Bluetooth Geräte:', style: TextStyle(fontSize: 16)),
                Container(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _bluetoothDevices.length,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: EdgeInsets.symmetric(horizontal: 8),
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(_bluetoothDevices[index], style: TextStyle(color: Colors.white)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: 500),
              child: _filteredNotes.isEmpty
                  ? Center(child: Text('Keine Notizen für diesen Tag'))
                  : ListView.builder(
                      key: ValueKey(_filteredNotes.length),
                      itemCount: _filteredNotes.length,
                      itemBuilder: (context, index) {
                        Note note = _filteredNotes[index];
                        return ListTile(
                          title: Text(note.content),
                          subtitle: Text(note.timestamp.toIso8601String()),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
} 