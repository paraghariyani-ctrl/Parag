import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const PHFApp());
}

class PHFApp extends StatelessWidget {
  const PHFApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PHF',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const HomeScreen(),
    );
  }
}

class TeamMember {
  String name;
  String phone;

  TeamMember({required this.name, required this.phone});

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
      };

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
    );
  }
}

const List<String> roles = [
  'Candid',
  'Cinematographer',
  'T. Photo',
  'T. Video',
  'Drone',
  'Helper',
];

class EventData {
  String id;
  DateTime date;
  String client;
  String phone;
  String venue;
  String time;
  String notes;
  Map<String, TeamMember?> crew;

  EventData({
    required this.id,
    required this.date,
    required this.client,
    required this.phone,
    required this.venue,
    required this.time,
    required this.notes,
    required this.crew,
  });

  Map<String, dynamic> toJson() {
    final crewJson = <String, dynamic>{};
    for (final role in roles) {
      final member = crew[role];
      crewJson[role] = member?.toJson();
    }

    return {
      'id': id,
      'date': date.toIso8601String(),
      'client': client,
      'phone': phone,
      'venue': venue,
      'time': time,
      'notes': notes,
      'crew': crewJson,
    };
  }

  factory EventData.fromJson(Map<String, dynamic> json) {
    final rawCrew = Map<String, dynamic>.from(json['crew'] ?? {});
    final crew = <String, TeamMember?>{};

    for (final role in roles) {
      final value = rawCrew[role];
      if (value is Map) {
        crew[role] =
            TeamMember.fromJson(Map<String, dynamic>.from(value));
      } else {
        crew[role] = null;
      }
    }

    return EventData(
      id: json['id']?.toString() ?? '',
      date: DateTime.parse(json['date'].toString()),
      client: json['client']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      venue: json['venue']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      crew: crew,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime selectedDate = DateTime.now();
  DateTime displayedMonth =
      DateTime(DateTime.now().year, DateTime.now().month);

  List<EventData> events = [];
  List<TeamMember> team = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final savedEvents = prefs.getStringList('events') ?? [];
    final savedTeam = prefs.getStringList('team') ?? [];

    final loadedEvents = <EventData>[];
    for (final item in savedEvents) {
      try {
        loadedEvents.add(
          EventData.fromJson(jsonDecode(item)),
        );
      } catch (_) {}
    }

    final loadedTeam = <TeamMember>[];
    for (final item in savedTeam) {
      try {
        loadedTeam.add(
          TeamMember.fromJson(jsonDecode(item)),
        );
      } catch (_) {}
    }

    if (!mounted) return;

    setState(() {
      events = loadedEvents;
      team = loadedTeam;
    });
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      'events',
      events.map((e) => jsonEncode(e.toJson())).toList(),
    );

    await prefs.setStringList(
      'team',
      team.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  List<EventData> eventsForDay(DateTime date) {
    return events.where((event) {
      return event.date.year == date.year &&
          event.date.month == date.month &&
          event.date.day == date.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final firstDay =
        DateTime(displayedMonth.year, displayedMonth.month, 1);
    final numberOfDays =
        DateTime(displayedMonth.year, displayedMonth.month + 1, 0).day;
    final firstWeekday = firstDay.weekday % 7;
    final totalCells =
        ((firstWeekday + numberOfDays + 6) ~/ 7) * 7;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PHF',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Team',
            icon: const Icon(Icons.people_outline),
            onPressed: openTeam,
          ),
          IconButton(
            tooltip: 'Today',
            icon: const Icon(Icons.today_outlined),
            onPressed: () {
              final now = DateTime.now();
              setState(() {
                selectedDate = now;
                displayedMonth = DateTime(now.year, now.month);
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          monthHeader(),
          weekdayHeader(),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: totalCells,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.82,
              ),
              itemBuilder: (context, index) {
                if (index < firstWeekday ||
                    index >= firstWeekday + numberOfDays) {
                  return const SizedBox.shrink();
                }

                final day = DateTime(
                  displayedMonth.year,
                  displayedMonth.month,
                  index - firstWeekday + 1,
                );

                final dayEvents = eventsForDay(day);
                final isSelected = sameDay(day, selectedDate);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedDate = day;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.all(3),
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context)
                              .colorScheme
                              .primaryContainer
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.black12,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${day.day}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (dayEvents.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dayEvents.first.client,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          selectedDayPanel(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openEventForm(selectedDate),
        icon: const Icon(Icons.add),
        label: const Text('Event'),
      ),
    );
  }

  Widget monthHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                displayedMonth = DateTime(
                  displayedMonth.year,
                  displayedMonth.month - 1,
                );
              });
            },
          ),
          Expanded(
            child: Center(
              child: Text(
                '${monthName(displayedMonth.month)} ${displayedMonth.year}',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                displayedMonth = DateTime(
                  displayedMonth.year,
                  displayedMonth.month + 1,
                );
              });
            },
          ),
        ],
      ),
    );
  }

  Widget weekdayHeader() {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Row(
      children: days
          .map(
            (day) => Expanded(
              child: Center(
                child: Text(
                  day,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget selectedDayPanel() {
    final dayEvents = eventsForDay(selectedDate);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            color: Colors.black12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${selectedDate.day} ${monthName(selectedDate.month)} ${selectedDate.year}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (dayEvents.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Text('No event booked. Tap + Event to add.'),
            )
          else
            ...dayEvents.map(
              (event) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  event.client,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${event.venue} • ${event.time}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openEventForm(event.date, existing: event),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> openEventForm(
    DateTime date, {
    EventData? existing,
  }) async {
    final result = await Navigator.push<EventData>(
      context,
      MaterialPageRoute(
        builder: (_) => EventFormScreen(
          date: date,
          existing: existing,
          team: team,
        ),
      ),
    );

    if (result == null) return;

    setState(() {
      final index =
          events.indexWhere((event) => event.id == result.id);

      if (index == -1) {
        events.add(result);
      } else {
        events[index] = result;
      }

      selectedDate = result.date;
      displayedMonth =
          DateTime(result.date.year, result.date.month);
    });

    await saveData();
  }

  Future<void> openTeam() async {
    final result = await Navigator.push<List<TeamMember>>(
      context,
      MaterialPageRoute(
        builder: (_) => TeamScreen(team: List.of(team)),
      ),
    );

    if (result == null) return;

    setState(() {
      team = result;
    });

    await saveData();
  }

  bool sameDay(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  String monthName(int month) {
    const names = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return names[month];
  }
}

class EventFormScreen extends StatefulWidget {
  final DateTime date;
  final EventData? existing;
  final List<TeamMember> team;

  const EventFormScreen({
    super.key,
    required this.date,
    required this.existing,
    required this.team,
  });

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final clientController = TextEditingController();
  final phoneController = TextEditingController();
  final venueController = TextEditingController();
  final timeController = TextEditingController();
  final notesController = TextEditingController();

  late DateTime eventDate;
  late Map<String, TeamMember?> assignments;

  @override
  void initState() {
    super.initState();

    eventDate = widget.existing?.date ?? widget.date;

    assignments = {
      for (final role in roles) role: null,
    };

    final event = widget.existing;

    if (event != null) {
      clientController.text = event.client;
      phoneController.text = event.phone;
      venueController.text = event.venue;
      timeController.text = event.time;
      notesController.text = event.notes;
      assignments.addAll(event.crew);
    }
  }

  @override
  void dispose() {
    clientController.dispose();
    phoneController.dispose();
    venueController.dispose();
    timeController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: eventDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      setState(() {
        eventDate = picked;
      });
    }
  }

  void saveEvent() {
    if (clientController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Client / couple name is required'),
        ),
      );
      return;
    }

    final result = EventData(
      id: widget.existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      date: eventDate,
      client: clientController.text.trim(),
      phone: phoneController.text.trim(),
      venue: venueController.text.trim(),
      time: timeController.text.trim(),
      notes: notesController.text.trim(),
      crew: assignments,
    );

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'Add Event' : 'Edit Event',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: saveEvent,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Event date'),
              subtitle: Text(
                '${eventDate.day}/${eventDate.month}/${eventDate.year}',
              ),
              onTap: chooseDate,
            ),
          ),
          const SizedBox(height: 12),
          inputField(
            controller: clientController,
            label: 'Client / Couple name',
            icon: Icons.person,
          ),
          inputField(
            controller: phoneController,
            label: 'Client contact number',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
          ),
          inputField(
            controller: venueController,
            label: 'Venue',
            icon: Icons.location_on,
          ),
          inputField(
            controller: timeController,
            label: 'Time',
            icon: Icons.schedule,
          ),
          inputField(
            controller: notesController,
            label: 'Notes',
            icon: Icons.notes,
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          const Text(
            'TEAM ASSIGNMENT',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          for (final role in roles) assignmentCard(role),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          prefixIcon: Icon(icon),
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget assignmentCard(String role) {
    final selected = assignments[role];

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(iconForRole(role)),
        ),
        title: Text(role),
        subtitle: selected == null
            ? const Text('Not assigned')
            : Text('${selected.name} • ${selected.phone}'),
        trailing: SizedBox(
          width: 125,
          child: DropdownButton<TeamMember>(
            isExpanded: true,
            value: selected,
            hint: const Text('Assign'),
            items: widget.team.map((member) {
              return DropdownMenuItem<TeamMember>(
                value: member,
                child: Text(
                  member.name,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (member) {
              setState(() {
                assignments[role] = member;
              });
            },
          ),
        ),
      ),
    );
  }

  IconData iconForRole(String role) {
    switch (role) {
      case 'Candid':
        return Icons.camera_alt;
      case 'Cinematographer':
        return Icons.movie_creation_outlined;
      case 'T. Photo':
        return Icons.photo_camera;
      case 'T. Video':
        return Icons.videocam;
      case 'Drone':
        return Icons.flight;
      default:
        return Icons.handyman;
    }
  }
}

class TeamScreen extends StatefulWidget {
  final List<TeamMember> team;

  const TeamScreen({
    super.key,
    required this.team,
  });

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  late List<TeamMember> team;

  @override
  void initState() {
    super.initState();
    team = widget.team;
  }

  Future<void> addMember() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add team member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                ),
              ),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Contact number',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (shouldAdd == true &&
        nameController.text.trim().isNotEmpty) {
      setState(() {
        team.add(
          TeamMember(
            name: nameController.text.trim(),
            phone: phoneController.text.trim(),
          ),
        );
      });
    }

    nameController.dispose();
    phoneController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PHF Team'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () => Navigator.pop(context, team),
          ),
        ],
      ),
      body: team.isEmpty
          ? const Center(
              child: Text(
                'No team members yet.\nTap + to add someone.',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: team.length,
              itemBuilder: (context, index) {
                final member = team[index];

                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person),
                    ),
                    title: Text(
                      member.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(member.phone),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        setState(() {
                          team.removeAt(index);
                        });
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: addMember,
        child: const Icon(Icons.add),
      ),
    );
  }
}
