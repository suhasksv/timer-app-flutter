import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter
import 'package:intl/intl.dart'; // For date formatting

void main() {
  runApp(const TimerApp());
}

class TimerApp extends StatelessWidget {
  const TimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calm Timer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light, // Starting with light theme
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark, // Define a dark theme
      ),
      themeMode: ThemeMode.system,
      home: const TimerHomePage(),
    );
  }
}

class TimerHomePage extends StatefulWidget {
  const TimerHomePage({super.key});

  @override
  State<TimerHomePage> createState() => _TimerHomePageState();
}

class _TimerHomePageState extends State<TimerHomePage> {
  // --- Timers ---
  Timer? _mainTimer; // For countdown
  Timer? _clockTimer; // For the top clock and date display
  Timer? _colonBlinkTimer; // For blinking colons in the top clock
  Timer? _backgroundTimer; // For changing background color

  // --- Timer State ---
  Duration _initialDuration = const Duration(minutes: 5);
  Duration _timeRemaining = const Duration(minutes: 5);
  bool _isRunning = false;
  final List<Duration> _laps = [];

  // --- Clock & Date State ---
  DateTime _currentTime = DateTime.now();
  bool _showColons = true;

  // --- Background State ---
  final List<Color> _calmColors = [
    Colors.blue.shade100,
    Colors.green.shade100,
    Colors.purple.shade100,
    Colors.orange.shade100,
    Colors.teal.shade100,
  ];
  int _currentColorIndex = 0;
  Color _backgroundColor = Colors.blue.shade100;
  final Duration _backgroundChangeInterval = const Duration(seconds: 10);

  // --- Input Controller ---
  final TextEditingController _timeInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _backgroundColor = _calmColors[0]; // Initialize background
    _timeRemaining = _initialDuration; // Initialize remaining time

    // Start the clock/date timer (updates every second)
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) { // Check if the widget is still in the tree
        setState(() {
          _currentTime = DateTime.now();
        });
      } else {
        timer.cancel();
      }
    });

    // Start the colon blink timer (updates twice a second)
    _colonBlinkTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
       if (mounted) {
        setState(() {
          _showColons = !_showColons;
        });
      } else {
        timer.cancel();
      }
    });

    // Start the background color change timer
    _backgroundTimer = Timer.periodic(_backgroundChangeInterval, (timer) {
      if (mounted) {
        _changeBackgroundColor();
      } else {
        timer.cancel();
      }
    });

     _timeInputController.text = _initialDuration.inMinutes.toString(); // Init input field
  }

  @override
  void dispose() {
    // CRITICAL: Cancel all timers to prevent memory leaks
    _mainTimer?.cancel();
    _clockTimer?.cancel();
    _colonBlinkTimer?.cancel();
    _backgroundTimer?.cancel();
    _timeInputController.dispose();
    super.dispose();
  }

  // --- Timer Controls ---
  void _startTimer() {
    if (_isRunning || _timeRemaining.inSeconds <= 0) return;

    setState(() {
      _isRunning = true;
    });

    _mainTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { // Check again inside the periodic timer
        timer.cancel();
        return;
      }
      setState(() {
        if (_timeRemaining.inSeconds > 0) {
          _timeRemaining = _timeRemaining - const Duration(seconds: 1);
        } else {
          _mainTimer?.cancel();
          _isRunning = false;
          _onTimerFinished(); // Handle completion
        }
      });
    });
  }

  void _pauseTimer() {
    if (!_isRunning) return;
    _mainTimer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _resetTimer() {
    _mainTimer?.cancel();
    setState(() {
      _isRunning = false;
      _timeRemaining = _initialDuration; // Reset to the set duration
      _laps.clear(); // Clear laps on reset
    });
  }

  void _addLap() {
    if (!_isRunning) return;
    setState(() {
      // Calculate lap time relative to the start
      final lapTime = _initialDuration - _timeRemaining;
      _laps.add(lapTime);
    });
  }

  void _onTimerFinished() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Time's Up!"),
        content: Text("Timer for ${_formatDuration(_initialDuration, showMs: false)} finished."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
     _resetTimer(); // Example: Reset after showing dialog
  }

  // --- Background Color Change ---
  void _changeBackgroundColor() {
    setState(() {
      _currentColorIndex = (_currentColorIndex + 1) % _calmColors.length;
      _backgroundColor = _calmColors[_currentColorIndex];
    });
  }

  // --- Time Setting ---
  void _showSetTimeDialog() {
     _timeInputController.text = _initialDuration.inMinutes.toString(); // Set initial value

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Set Timer Duration (Minutes)"),
        content: TextField(
          controller: _timeInputController,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly // Only allow digits
          ],
          decoration: const InputDecoration(labelText: 'Minutes'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              final minutes = int.tryParse(_timeInputController.text);
              if (minutes != null && minutes > 0) {
                setState(() {
                  _initialDuration = Duration(minutes: minutes);
                  _resetTimer();
                });
                Navigator.of(context).pop(); // Close dialog
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text("Please enter a valid positive number of minutes.")),
                );
              }
            },
            child: const Text("Set"),
          ),
        ],
      ),
    );
  }

  // --- Formatting Helpers ---
  String _formatDuration(Duration duration, {bool showMs = true}) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String threeDigits(int n) => n.toString().padLeft(3, '0'); // For milliseconds

    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final milliseconds = threeDigits(duration.inMilliseconds.remainder(1000));

    String formatted = "$minutes:$seconds";
    if (duration.inHours > 0) {
      formatted = "$hours:$formatted";
    }
    if (showMs) {
        // formatted = "$formatted.$milliseconds";
    }

    return formatted;
  }

    String _formatDateTime(DateTime dateTime) {
    // HH:MM:SS format with blinking colons
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(dateTime.hour);
    final minutes = twoDigits(dateTime.minute);
    final seconds = twoDigits(dateTime.second);
    final colon = _showColons ? ':' : ' ';
    return "$hours$colon$minutes$colon$seconds";
  }

  String _formatDate(DateTime dateTime) {
    // YYYY MM DD
    final DateFormat formatterDate = DateFormat('yyyy MM dd');
    // Day Name
    final DateFormat formatterDay = DateFormat('EEEE'); // E.g., Monday
    return "${formatterDate.format(dateTime)}\n${formatterDay.format(dateTime)}";
  }

  @override
  Widget build(BuildContext context) {
    final Brightness backgroundBrightness = ThemeData.estimateBrightnessForColor(_backgroundColor);
    final Color textColor = backgroundBrightness == Brightness.dark ? Colors.white : Colors.black;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(seconds: 2), // Background transition speed
        color: _backgroundColor,
        padding: const EdgeInsets.all(16.0),
        child: SafeArea(
          child: Column(
            children: [
              // Top Row: Date/Day and Time
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start, // Align top
                children: [
                  Text(
                    _formatDate(_currentTime),
                    textAlign: TextAlign.left,
                    style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.8)),
                  ),
                  Text(
                    _formatDateTime(_currentTime),
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 16, color: textColor, fontWeight: FontWeight.bold, fontFamily: 'monospace'), // Monospace for consistent spacing
                  ),
                ],
              ),

              const Spacer(flex: 1), // Push timer display down a bit

              // Main Timer Display
              Text(
                _formatDuration(_timeRemaining, showMs: false),
                style: TextStyle(
                  fontSize: 72, // Make timer prominent
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  fontFamily: 'monospace', // Consistent width for numbers
                ),
              ),
              Text(
                "Set: ${_formatDuration(_initialDuration, showMs: false)}",
                 style: TextStyle(fontSize: 16, color: textColor.withOpacity(0.7)),
              ),

              const SizedBox(height: 30),

              // Control Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Start/Pause Button
                  FloatingActionButton(
                    onPressed: _isRunning ? _pauseTimer : _startTimer,
                    tooltip: _isRunning ? 'Pause' : 'Start',
                    backgroundColor: textColor.withOpacity(0.1),
                     foregroundColor: textColor,
                    child: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                  ),
                   // Lap Button
                  FloatingActionButton(
                    onPressed: _isRunning ? _addLap : null, // Only enable when running
                    tooltip: 'Lap',
                     backgroundColor: _isRunning ? textColor.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                     foregroundColor: _isRunning ? textColor : Colors.grey,
                    child: const Icon(Icons.flag),
                  ),
                  // Reset Button
                   FloatingActionButton(
                    onPressed: (_timeRemaining != _initialDuration || _isRunning || _laps.isNotEmpty) ? _resetTimer : null, // Enable if not pristine
                    tooltip: 'Reset',
                    backgroundColor: (_timeRemaining != _initialDuration || _isRunning || _laps.isNotEmpty) ? textColor.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                    foregroundColor: (_timeRemaining != _initialDuration || _isRunning || _laps.isNotEmpty) ? textColor : Colors.grey,
                    child: const Icon(Icons.refresh),
                  ),
                  // Set Time Button
                  FloatingActionButton(
                    onPressed: _isRunning ? null : _showSetTimeDialog, // Disable while running
                    tooltip: 'Set Time',
                     backgroundColor: !_isRunning ? textColor.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                     foregroundColor: !_isRunning ? textColor : Colors.grey,
                    child: const Icon(Icons.timer_outlined),
                  ),
                ],
              ),

              const Spacer(flex: 1), // Push laps down

              // Laps Display
              Expanded(
                flex: 3, // Give more space to laps if needed
                child: _laps.isEmpty
                    ? Center(child: Text('No laps yet.', style: TextStyle(color: textColor.withOpacity(0.6))))
                    : ListView.builder(
                        itemCount: _laps.length,
                        itemBuilder: (context, index) {
                          final lapNumber = _laps.length - index; // Show newest first
                          final lapTime = _laps[lapNumber - 1];
                          Duration difference = Duration.zero;
                          if (lapNumber > 1) {
                            difference = lapTime - _laps[lapNumber - 2];
                          } else {
                             difference = lapTime; // First lap difference is the lap time itself
                          }

                          return ListTile(
                             dense: true,
                             leading: Text(
                              'Lap $lapNumber',
                               style: TextStyle(color: textColor.withOpacity(0.8)),
                            ),
                             title: Text(
                              _formatDuration(lapTime, showMs: true), // Show MS for laps
                               style: TextStyle(color: textColor, fontWeight: FontWeight.w500, fontFamily: 'monospace'),
                            ),
                             trailing: Text(
                              '+${_formatDuration(difference, showMs: true)}', // Show difference from previous
                               style: TextStyle(color: textColor.withOpacity(0.7), fontFamily: 'monospace'),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
