
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'package:pinput/pinput.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'services/contacts_service.dart';

// =============================================================================
// APP ENTRY
// =============================================================================

void main() {
  runApp(const GuardianApp());
}

class GuardianApp extends StatelessWidget {
  const GuardianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ECHO_SOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 194, 194, 194),
          primary: const Color(0xFF6A1B9A),
          secondary: const Color(0xFFFF1744),
        ),
      ),

      // 🔐 ENTRY POINT = LOGIN FLOW
      home: const _RootScreen(),
    );
  }
}

class _RootScreen extends StatefulWidget {
  const _RootScreen();

  @override
  State<_RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<_RootScreen> {
  bool _checking = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final auth = AuthService();
    final loggedIn = await auth.isLoggedIn();
    if (loggedIn) {
      await SafetyController().initializeFromStorage();
    }
    if (!mounted) return;
    setState(() {
      _loggedIn = loggedIn;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_loggedIn) {
      return const MainNavigationHub();
    }
    return const LoginFlowScreen();
  }
}

//
// ============================================================================
// 🔐 LOGIN FLOW (PHONE → OTP → PROFILE)
// ============================================================================
//

class LoginFlowScreen extends StatefulWidget {
  const LoginFlowScreen({super.key});

  @override
  State<LoginFlowScreen> createState() => _LoginFlowScreenState();
}

class _LoginFlowScreenState extends State<LoginFlowScreen>
    with SingleTickerProviderStateMixin {
  List<ContactModel> emergencyContacts = [];
  String? emergencyName, emergencyPhone;
  String? _generatedOtp;
  int _otpAttempts = 0;
  String _generateOtp() {
    final random = DateTime.now().millisecondsSinceEpoch % 1000000;
    return random.toString().padLeft(6, '0');
  }


  int currentStep = 0;
  String? phoneNumber, otp, name, age;
  bool isLoading = false;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
  }

  Widget _otpStep() {
  return Column(
    children: [
      const Text(
        "Enter OTP",
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 20),

      Pinput(
        length: 6,
        keyboardType: TextInputType.number,
        onCompleted: (value) {
          otp = value;
          _verifyOtp();
        },
      ),

      const SizedBox(height: 20),

      TextButton(
        onPressed: _sendOtp,
        child: const Text("Resend OTP"),
      ),
    ],
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFAB47BC), Color(0xFF7B1FA2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),

                Icon(
                  Icons.shield,
                  size: 100,
                  color: Colors.white,
                ),

                const SizedBox(height: 30),
                const Text("EchoSOS",
                    style:
                        TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),

                const SizedBox(height: 40),

                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Column(
                      children: [
                        if (currentStep == 0) _phoneStep(),
                        if (currentStep == 1) _otpStep(),
                        if (currentStep == 2) _profileStep(),
                        if (currentStep == 3) _emergencyContactsStep(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  

  Widget _phoneStep() {
    return Column(
      children: [
        const Text("Enter Phone Number",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 30),
        TextField(
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(prefixText: "+91 "),
          onChanged: (v) => phoneNumber = v,
        ),
        const SizedBox(height: 30),
        _primaryButton("Send OTP", _sendOtp),
      ],
    );
  }

  Future<void> _sendOtp() async {
  if (phoneNumber == null || phoneNumber!.length < 10) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Enter a valid phone number")),
    );
    return;
  }

  setState(() => isLoading = true);

  await Future.delayed(const Duration(seconds: 1));

  _generatedOtp = _generateOtp();
  _otpAttempts = 0;

  // 🔔 SIMULATED SMS
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text("OTP sent to +91 $phoneNumber : $_generatedOtp"),
      duration: const Duration(seconds: 4),
    ),
  );

  setState(() {
    isLoading = false;
    currentStep = 1; // move to OTP screen
  });
}



  Widget _profileStep() {
    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(labelText: "Name"),
          onChanged: (v) => name = v,
        ),
        const SizedBox(height: 20),
        TextField(
          decoration: const InputDecoration(labelText: "Age"),
          keyboardType: TextInputType.number,
          onChanged: (v) => age = v,
        ),
        const SizedBox(height: 40),
        _primaryButton("Activate Guardian", _completeLogin),
      ],
    );
  }


  Widget _emergencyContactsStep() {
  return Column(
    children: [
      const Text(
        "Add Emergency Contact",
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 20),

      TextField(
        decoration: const InputDecoration(labelText: "Contact Name"),
        onChanged: (v) => emergencyName = v,
      ),

      const SizedBox(height: 16),

      TextField(
        decoration: const InputDecoration(labelText: "Contact Phone"),
        keyboardType: TextInputType.phone,
        onChanged: (v) => emergencyPhone = v,
      ),

      const SizedBox(height: 30),

      _primaryButton("Finish Setup", () async {
        if (emergencyName != null &&
            emergencyName!.isNotEmpty &&
            emergencyPhone != null &&
            emergencyPhone!.isNotEmpty) {
          try {
            await SafetyController().addContact(
              name: emergencyName!.trim(),
              phone: emergencyPhone!.trim(),
            );
          } catch (_) {}
        }
        _finishAuth();
      }),
    ],
  );
}


  Widget _primaryButton(String text, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        child: isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(text),
      ),
    );
  }

  Future<void> _verifyOtp() async {
  if (otp == _generatedOtp) {
    setState(() {
      currentStep = 2; // Go to profile step
    });
  } else {
    _otpAttempts++;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Invalid OTP")),
    );

    if (_otpAttempts >= 2) {
      // 🔁 Auto resend OTP after 2 failed attempts
      await _sendOtp();
    }
  }
}


  Future<void> _completeLogin() async {
    setState(() => isLoading = true);
    const backendPassword = 'guardian123';

    try {
      await _authService.register(
        name: (name ?? '').trim(),
        phone: (phoneNumber ?? '').trim(),
        email: '${(phoneNumber ?? '').trim()}@example.com',
        password: backendPassword,
        codeword: SafetyController().userSafeWord,
      );
      await SafetyController().initializeFromStorage();
    } catch (_) {
      try {
        await _authService.login(
          phone: (phoneNumber ?? '').trim(),
          password: backendPassword,
        );
        await SafetyController().initializeFromStorage();
      } catch (_) {}
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          currentStep = 3;
        });
      }
    }
  }
void _finishAuth() {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => const MainNavigationHub()),
  );
}

}

//
// ============================================================================
// 🧠 SAFETY CONTROLLER (UNCHANGED)
// ============================================================================
//

enum ContactType { family, friend, police }

class ContactModel {
  final String id;
  final String name;
  final String phone;
  final ContactType type;

  ContactModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.type,
  });
}


class SafetyController {
  static final SafetyController _instance = SafetyController._internal();
  factory SafetyController() => _instance;
  SafetyController._internal();

  final ContactsService _contactsService = ContactsService();
  final StorageService _storage = StorageService();

  String userSafeWord = "help me";
  final stt.SpeechToText speech = stt.SpeechToText();

  final List<ContactModel> contacts = [];

  void toggleSosMode(bool active) {}

  Future<void> initializeFromStorage() async {
    final userData = await _storage.getUserData();
    final codeword = userData?['codeword'];
    if (codeword is String && codeword.isNotEmpty) {
      userSafeWord = codeword;
    }
  }

  Future<void> loadContacts() async {
    final backendContacts = await _contactsService.getContacts();
    contacts
      ..clear()
      ..addAll(
        backendContacts.map((c) {
          final relation = (c['relation'] as String?) ?? 'family';
          final type = relation == 'police'
              ? ContactType.police
              : relation == 'friend'
                  ? ContactType.friend
                  : ContactType.family;
          return ContactModel(
            id: '${c['id']}',
            name: c['name'] as String? ?? '',
            phone: c['phone'] as String? ?? '',
            type: type,
          );
        }),
      );
  }

  Future<void> addContact({
    required String name,
    required String phone,
    String? email,
    String relation = 'family',
    bool isPrimary = false,
  }) async {
    Map<String, dynamic>? response;
    try {
      response = await _contactsService.createContact(
        name: name,
        phone: phone,
        email: email,
        relation: relation,
        isPrimary: isPrimary,
      );
    } catch (_) {
      response = null;
    }
    contacts.add(
      ContactModel(
        id: response != null && response['id'] != null
            ? '${response['id']}'
            : 'local-${contacts.length + 1}',
        name: response != null && response['name'] is String
            ? response['name'] as String
            : name,
        phone: response != null && response['phone'] is String
            ? response['phone'] as String
            : phone,
        type: relation == 'police'
            ? ContactType.police
            : relation == 'friend'
                ? ContactType.friend
                : ContactType.family,
      ),
    );
  }

  Future<void> removeContact(ContactModel contact) async {
    final idInt = int.tryParse(contact.id);
    if (idInt != null) {
      await _contactsService.deleteContact(idInt);
    }
    contacts.removeWhere((c) => c.id == contact.id);
  }
}

//
// ============================================================================
// 🧭 MAIN NAVIGATION HUB + ALL YOUR SCREENS
// (UNCHANGED FROM YOUR CODE)
// ============================================================================
//

class MainNavigationHub extends StatefulWidget {
  const MainNavigationHub({super.key});

  @override
  State<MainNavigationHub> createState() => _MainNavigationHubState();
}

class _MainNavigationHubState extends State<MainNavigationHub> {
  int _index = 0;

  final pages = const [
    HomeScreen(),
    LiveTrackMapScreen(),
    TrustedContactsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.warning), label: "SOS"),
          NavigationDestination(icon: Icon(Icons.map), label: "Track"),
          NavigationDestination(icon: Icon(Icons.people), label: "Contacts"),
          NavigationDestination(icon: Icon(Icons.settings), label: "Settings"),
        ],
      ),
    );
  }
}

// =============================================================================
// Remaining screens (HomeScreen, Map, Contacts, Settings)
// → keep EXACTLY as you already wrote them
// =============================================================================

// =============================================================================
// SCREEN 1: HOME (THE PANIC BUTTON)
// =============================================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isListening = false;
  stt.SpeechToText speech = stt.SpeechToText();
  bool speechEnabled = false;
  Timer? _listeningTimeout;

  @override
  void initState() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _initSpeech();
    super.initState();
  }

  Future<void> _initSpeech() async {
    await Permission.microphone.request();
    speechEnabled = await speech.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    _listeningTimeout?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // UPDATED LOGIC: Voice Validation -> Trigger SOS
  // ---------------------------------------------------------------------------

  void _startVoiceValidation() async {
  // 1. Haptic Feedback & UI
  HapticFeedback.lightImpact();
  setState(() => _isListening = true);

  final safeWord = SafetyController().userSafeWord.toLowerCase();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text("LISTENING... SAY: '$safeWord'"),
      backgroundColor: Colors.purple,
      duration: const Duration(seconds: 5),
    ),
  );

  // 2. Initialize speech if not already enabled
  if (!speechEnabled) {
    speechEnabled = await speech.initialize(
      onStatus: (status) {
        if (status == "done" || status == "notListening") {
          _stopVoiceValidation();
        }
      },
      onError: (error) {
        _stopVoiceValidation();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Speech recognition error: ${error.errorMsg}")),
        );
      },
    );
    if (!speechEnabled) {
      setState(() => _isListening = false);
      return;
    }
  }

  // 3. Start listening
  await speech.listen(
  onResult: (result) {
    final words = result.recognizedWords.toLowerCase();

    if (words.contains(safeWord)) {
      _stopVoiceValidation();
      _triggerSOSAlert();
    }
  },
  listenOptions: stt.SpeechListenOptions(
    listenMode: stt.ListenMode.confirmation,
    partialResults: true,
    autoPunctuation: false,
    enableHapticFeedback: false,
  ),
);



  // 4. Safety fallback timeout (in case listen doesn't auto-stop)
  _listeningTimeout = Timer(const Duration(seconds: 5), () {
  if (_isListening) {
    _stopVoiceValidation();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Voice match failed. SOS Cancelled.")),
    );
  }
});
}

// Stop listening helper
void _stopVoiceValidation() {
  if (speech.isListening) {
    speech.stop();
  }
  _listeningTimeout?.cancel();
  if (mounted) setState(() => _isListening = false);
}



  // ---------------------------------------------------------------------------
  // ACTUAL ALARM TRIGGER
  // ---------------------------------------------------------------------------

  void _triggerSOSAlert() {
    HapticFeedback.heavyImpact(); // Physical feedback
    SafetyController().toggleSosMode(true);
    
    // Simulate Backend Calls
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.warning, color: Colors.white),
            SizedBox(width: 10),
            Text("SOS SENT! Tracking Started."),
          ],
        ),
        backgroundColor: Colors.red.shade900,
        duration: const Duration(seconds: 5),
      ),
    );

    // Show severity dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("ESCALATION LEVEL"),
        content: const Text("Contacts notified. Call Police now?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("No, Just Contacts")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Calling 112...")));
            }, 
            child: const Text("CALL POLICE (112)", style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text(
        "GUARDIAN",
        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
      ),
      centerTitle: true,
      actions: const [],
    ),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // STATIC TEXT (does not move with ripple)
          const SizedBox(height: 30),

          // RIPPLING SOS BUTTON (independent of text)
          GestureDetector(
  onLongPress: _startVoiceValidation,
  child: AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      return Stack(
        alignment: Alignment.center,
        children: [
          // Ripple Effect
          Container(
            width: 250 + (_controller.value * 50),
            height: 250 + (_controller.value * 50),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isListening
                  ? Colors.purple.withValues(alpha: 0.5 - (_controller.value * 0.5))
                  : Colors.red.withValues(alpha: 0.5 - (_controller.value * 0.5)),
            ),
          ),
          // Solid Center Button with Text
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isListening ? Colors.purple : Colors.red,
              boxShadow: [
                BoxShadow(
                  color: (_isListening ? Colors.purple : Colors.red).withValues(alpha: 0.6),
                  blurRadius: 20,
                  spreadRadius: 5,
                )
              ],
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isListening
                    ? [const Color(0xFFAB47BC), const Color(0xFF7B1FA2)]
                    : [const Color(0xFFFF5252), const Color(0xFFD50000)],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isListening ? Icons.mic : Icons.warning_rounded,
                    size: 60,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isListening ? "LISTENING..." : "HOLD TO ACTIVATE",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  ),
),


          const SizedBox(height: 50),
          // Quick Status removed
        ],
      ),
    ),
  );
}


}

// =============================================================================
// SCREEN 2: LIVE TRACKING (Google Maps Simulation)
// =============================================================================

class LiveTrackMapScreen extends StatelessWidget {
  const LiveTrackMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final LatLng currentLocation = LatLng(19.045244, 72.841928); 

    return Scaffold(
      body: FlutterMap(
        options: MapOptions(
          initialCenter: currentLocation,
          initialZoom: 15,
        ),
        children: [
          // OpenStreetMap tiles
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.guardian.safety',
          ),

          // Marker layer
          MarkerLayer(
            markers: [
              Marker(
                point: currentLocation,
                width: 60,
                height: 60,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SCREEN 3: TRUSTED CONTACTS
// =============================================================================

class TrustedContactsScreen extends StatefulWidget {
  const TrustedContactsScreen({super.key});

  @override
  State<TrustedContactsScreen> createState() => _TrustedContactsScreenState();
}

class _TrustedContactsScreenState extends State<TrustedContactsScreen> {
  final SafetyController controller = SafetyController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await controller.loadContacts();
    } catch (_) {
      _error = 'Failed to load contacts';
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _addContact(String name, String phone) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await controller.addContact(name: name, phone: phone);
    } catch (_) {
      _error = 'Failed to add contact';
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _deleteContact(ContactModel contact) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await controller.removeContact(contact);
    } catch (_) {
      _error = 'Failed to delete contact';
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _showAddContactDialog() async {
    String name = '';
    String phone = '';

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add Contact'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Name'),
                onChanged: (v) => name = v,
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
                onChanged: (v) => phone = v,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (name.isNotEmpty && phone.isNotEmpty) {
                  Navigator.pop(ctx);
                  await _addContact(name, phone);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final familyContacts = controller.contacts
        .where((c) => c.type == ContactType.family)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Trusted Circle")),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const Text(
              "AUTHORITIES",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            Card(
              color: Colors.red.shade50,
              child: ListTile(
                leading: const Icon(
                  Icons.local_police,
                  color: Colors.indigo,
                  size: 30,
                ),
                title: const Text("Police Control Room"),
                subtitle: const Text("Automatic Alert on High Severity"),
                trailing: Switch(
                  value: true,
                  onChanged: (v) {},
                  activeThumbColor: Colors.indigo,
                  activeTrackColor:
                      Colors.indigo.withValues(alpha: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "FAMILY & FRIENDS",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            ...familyContacts.map((contact) {
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple.shade100,
                    child: Text(
                      contact.name.isNotEmpty ? contact.name[0] : '?',
                    ),
                  ),
                  title: Text(contact.name),
                  subtitle: Text(contact.phone),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      _deleteContact(contact);
                    },
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _showAddContactDialog,
              icon: const Icon(Icons.add),
              label: const Text("ADD NEW CONTACT"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(15),
                side: const BorderSide(color: Colors.purple),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SCREEN 4: SETTINGS & VOICE CONFIG
// =============================================================================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _shakeSensitivity = 0.5;
  bool _voiceActive = true;
  late TextEditingController _wordController;

  @override
  void initState() {
    super.initState();
    _wordController = TextEditingController(text: SafetyController().userSafeWord);
  }

  @override
  void dispose() {
    _wordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  title: const Text("Safety Preferences"),
  actions: [
    Padding(
      padding: const EdgeInsets.only(right: 12),
      child: PopupMenuButton<String>(
        onSelected: (value) async {
          if (value == 'logout') {
            final navigator = Navigator.of(context);
            await AuthService().logout();
            navigator.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => const LoginFlowScreen(),
              ),
              (route) => false,
            );
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'logout',
            child: Text('Logout'),
          ),
        ],
        child: const CircleAvatar(
          radius: 18,
          backgroundImage: NetworkImage("https://i.pravatar.cc/150?img=5"),
        ),
      ),
    ),
  ],
),


      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Voice Command Section
            _buildSectionHeader("Voice Activation"),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Hands-free SOS", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Switch(value: _voiceActive, onChanged: (v) => setState(() => _voiceActive = v))
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 10),
                    const Text("Safe Word Configuration", style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 10),
                    // REQUIREMENT 3: Settings-driven Safety Word (Typed)
                    TextField(
                      controller: _wordController,
                      decoration: const InputDecoration(
                        labelText: "Type Safety Word",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.keyboard_voice),
                        helperText: "Speak this word to confirm SOS",
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          SafetyController().userSafeWord = value;
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            _buildSectionHeader("Fall & Shake Detection"),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text("Shake Sensitivity"),

                    Slider(
                      value: _shakeSensitivity,
                      min: 0.0,
                      max: 1.0,
                      divisions: 10, // IMPORTANT: prevents continuous vibration
                      activeColor: Colors.purple,

                      onChanged: (v) async {
                        setState(() => _shakeSensitivity = v);

                        // Vibrate on change
                        if (await Vibration.hasVibrator() ?? false) {
                          Vibration.vibrate(duration: 40);
                        }
                      },
                    ),

                    const Text(
                      "Low -------------------- High",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),


            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
    );
  }
}
