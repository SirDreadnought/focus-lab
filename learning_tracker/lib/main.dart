import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('study_logs');

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const LearningTrackerApp());
}

class LearningTrackerApp extends StatelessWidget {
  const LearningTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FOCUS LAB',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF000000), // Pure Obsidian Black
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      ),
      home: const TrackerHomeScreen(),
    );
  }
}

class TrackerHomeScreen extends StatefulWidget {
  const TrackerHomeScreen({super.key});

  @override
  State<TrackerHomeScreen> createState() => _TrackerHomeScreenState();
}

enum TimerState { stopped, running, paused }

class _TrackerHomeScreenState extends State<TrackerHomeScreen> {
  Timer? _timer;
  int _seconds = 0;
  TimerState _timerState = TimerState.stopped;
  bool _showStats = false; // Toggled via top-right menu
  late Box _box;

  @override
  void initState() {
    super.initState();
    _box = Hive.box('study_logs');
    _requestNotificationPermission();
  }

  void _requestNotificationPermission() {
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  void _updateNotification(String timeStr) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'timer_channel',
      'Focus Lab Timer',
      channelDescription: 'Live timer notification counter',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      onlyAlertOnce: true,
      showWhen: false,
    );
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      888,
      'Focus Lab Session in Progress',
      'Elapsed Time: $timeStr',
      notificationDetails,
    );
  }

  void _clearNotification() async {
    await flutterLocalNotificationsPlugin.cancel(888);
  }

  void _startTimer() {
    setState(() {
      _timerState = TimerState.running;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
      _updateNotification(_formatTimeSimple(_seconds));
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _timerState = TimerState.paused;
    });
    _updateNotification('PAUSED - ${_formatTimeSimple(_seconds)}');
  }

  void _saveAndStopTimer() {
    _timer?.cancel();
    if (_seconds > 0) {
      String todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
      double currentHours = _box.get(todayKey, defaultValue: 0.0);
      double newHours = currentHours + (_seconds / 3600.0);
      _box.put(todayKey, newHours);
    }

    setState(() {
      _seconds = 0;
      _timerState = TimerState.stopped;
    });

    _clearNotification();
  }

  double _getWeeklyTotal() {
    DateTime now = DateTime.now();
    double total = 0.0;
    for (int i = 0; i < 7; i++) {
      String key =
          DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: i)));
      total += _box.get(key, defaultValue: 0.0);
    }
    return total;
  }

  double _getMonthlyTotal() {
    DateTime now = DateTime.now();
    double total = 0.0;
    for (int i = 0; i < 30; i++) {
      String key =
          DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: i)));
      total += _box.get(key, defaultValue: 0.0);
    }
    return total;
  }

  List<String> _formatTimeIntoSegments(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;
    return [
      hours.toString().padLeft(2, '0'),
      minutes.toString().padLeft(2, '0'),
      seconds.toString().padLeft(2, '0'),
    ];
  }

  String _formatTimeSimple(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    String todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    double todaySavedHours = _box.get(todayKey, defaultValue: 0.0);
    List<String> timeSegments = _formatTimeIntoSegments(_seconds);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              // Header Row with Title and Top-Right Menu
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48), // Spacer for centering
                  const Text(
                    'FOCUS LAB',
                    style: TextStyle(
                      fontSize: 14,
                      letterSpacing: 4,
                      color: Colors.white54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white70),
                    color: const Color(0xFF141418),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    onSelected: (value) {
                      if (value == 'stats') {
                        setState(() {
                          _showStats = !_showStats;
                        });
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      PopupMenuItem<String>(
                        value: 'stats',
                        child: Row(
                          children: [
                            Icon(
                              _showStats
                                  ? Icons.bar_chart
                                  : Icons.bar_chart_outlined,
                              color: const Color(0xFF00FFCC),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _showStats ? 'Hide Statistics' : 'Statistics',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Middle Timer Section (Centered vertically in the remaining space)
              Expanded(
                child: Center(
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(
                        vertical: 48, horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Enlarged Segmented Digit Counter Display
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _SegmentedDigitPair(value: timeSegments[0]),
                            const _TimeSeparator(),
                            _SegmentedDigitPair(value: timeSegments[1]),
                            const _TimeSeparator(),
                            _SegmentedDigitPair(value: timeSegments[2]),
                          ],
                        ),

                        const SizedBox(height: 40),

                        // Glassmorphic Control Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_timerState == TimerState.stopped) ...[
                              _GlassControlButton(
                                label: 'START SESSION',
                                accentColor: const Color(0xFF00FFCC),
                                onTap: _startTimer,
                              ),
                            ] else if (_timerState == TimerState.running) ...[
                              _GlassControlButton(
                                label: 'PAUSE',
                                accentColor: const Color(0xFFFFB703),
                                onTap: _pauseTimer,
                              ),
                              const SizedBox(width: 16),
                              _GlassControlButton(
                                label: 'STOP & SAVE',
                                accentColor: const Color(0xFFFF007F),
                                onTap: _saveAndStopTimer,
                              ),
                            ] else if (_timerState == TimerState.paused) ...[
                              _GlassControlButton(
                                label: 'RESUME',
                                accentColor: const Color(0xFF00FFCC),
                                onTap: _startTimer,
                              ),
                              const SizedBox(width: 16),
                              _GlassControlButton(
                                label: 'STOP & SAVE',
                                accentColor: const Color(0xFFFF007F),
                                onTap: _saveAndStopTimer,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Toggleable Statistics Section
              if (_showStats) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'TOTAL HOURS',
                    style: TextStyle(
                        fontSize: 12, letterSpacing: 2, color: Colors.white38),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GlassCard(
                        child: StatWidget(
                          title: 'Today',
                          value: todaySavedHours.toStringAsFixed(1),
                          unit: 'hrs',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlassCard(
                        child: StatWidget(
                          title: 'This Week',
                          value: _getWeeklyTotal().toStringAsFixed(1),
                          unit: 'hrs',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlassCard(
                        child: StatWidget(
                          title: 'This Month',
                          value: _getMonthlyTotal().toStringAsFixed(1),
                          unit: 'hrs',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Universal Glassmorphic Card Container
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const GlassCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding ?? const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color:
                Colors.white.withValues(alpha: 0.04), // Frosted glass overlay
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.2,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class StatWidget extends StatelessWidget {
  final String title;
  final String value;
  final String unit;

  const StatWidget(
      {super.key,
      required this.title,
      required this.value,
      required this.unit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(width: 3),
              const Text(
                'hrs',
                style: TextStyle(fontSize: 10, color: Color(0xFF00FFCC)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimeSeparator extends StatelessWidget {
  const _TimeSeparator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        ':',
        style: TextStyle(
            fontSize: 42, color: Colors.white24, fontWeight: FontWeight.w300),
      ),
    );
  }
}

// Enlarged Segmented Digit Pair Display
class _SegmentedDigitPair extends StatelessWidget {
  final String value;

  const _SegmentedDigitPair({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 84,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 42,
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.robotoMono(
              textStyle: const TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w400,
                color: Color(0xFFC0FFF4),
                height: 1.0,
                shadows: [
                  Shadow(color: Color(0xFF00FFCC), blurRadius: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Fully Glassmorphic Control Button
class _GlassControlButton extends StatelessWidget {
  final String label;
  final Color accentColor;
  final VoidCallback onTap;

  const _GlassControlButton({
    required this.label,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: BoxDecoration(
              color: accentColor.withValues(
                  alpha: 0.12), // Glass color accent tint
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.2),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: accentColor,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
