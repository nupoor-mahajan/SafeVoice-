import 'dart:async';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart' as ph;

// Backend Integration Services
import 'services/auth_service.dart';
import 'services/sos_service.dart';
import 'services/contacts_service.dart';
import 'services/location_service.dart';
import 'services/storage_service.dart';

// =============================================================================
// HACKATHON APP: GUARDIAN (WOMEN SAFETY)
// ALL CODE IN ONE FILE: main.dart
// INTEGRATED WITH BACKEND API
// =============================================================================

void main() {
  runApp(const GuardianApp());
}

class GuardianApp extends StatelessWidget {
  const GuardianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guardian Safety',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        // High urgency color scheme: Guardian Purple & Alert Red
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6A1B9A), // Deep Purple
          primary: const Color(0xFF6A1B9A),
          secondary: const Color(0xFFFF1744), // Accent Red
          error: const Color(0xFFD32F2F),
        ),
        scaffoldBackgroundColor: Colors.grey[50],
        textTheme: const TextTheme(
          displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
          headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
          bodyLarge: TextStyle(fontSize: 16, color: Colors.black87),
        ),
      ),
      home: const MainNavigationHub(),
    );
  }
}

// =============================================================================
// DATA MODELS
// =============================================================================

enum ContactType { family, friend, police, ambulance }
enum SecurityLevel { safe, caution, danger }

class ContactModel {
  String id;
  String name;
  String phone;
  ContactType type;
  bool isTrusted;

  ContactModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.type,
    this.isTrusted = true,
  });

  // Convert from backend response
  factory ContactModel.fromJson(Map<String, dynamic> json) {
    ContactType type = ContactType.family;
    if (json['relation'] == 'friend') type = ContactType.friend;
    if (json['relation'] == 'authority') type = ContactType.police;

    return ContactModel(
      id: json['id'].toString(),
      name: json['name'],
      phone: json['phone'],
      type: type,
      isTrusted: json['is_primary'] ?? false,
    );
  }
}

class SosSmsSender {
  static Future<void> send(String phone, String message) async {
    print('Sending SOS SMS to $phone: $message');
  }
}

// =============================================================================
// CONTROLLER (State & Logic with Backend Integration)
// =============================================================================

class SafetyController {
  static final SafetyController _instance = SafetyController._internal();
  factory SafetyController() => _instance;
  SafetyController._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  final AuthService _authService = AuthService();
  final SosService _sosService = SosService();
  final ContactsService _contactsService = ContactsService();
  final LocationService _locationService = LocationService();
  final StorageService _storageService = StorageService();
  final Location _locationServicePlatform = Location();

  // Settings: User Safe Word (Mutable) - Loaded from backend
  String userSafeWord = "HELP ME";
  bool isListening = false;
  bool _isInitialized = false;
  int? _currentAlertId;
  Timer? _locationUpdateTimer;
  Timer? _sosSmsTimer;

  // Battery and contacts
  final ValueNotifier<double> batteryLevel = ValueNotifier(0.85);
  List<ContactModel> contacts = [];

  // Initialize controller - load data from backend
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load user data and codeword
      final userData = await _storageService.getUserData();
      if (userData != null) {
        userSafeWord = userData['codeword'] ?? "HELP ME";
      }

      // Load contacts from backend
      await loadContacts();

      _isInitialized = true;
    } catch (e) {
      print('Error initializing SafetyController: $e');
    }
  }

  // Load contacts from backend
  Future<void> loadContacts() async {
    try {
      final contactsData = await _contactsService.getContacts();
      contacts = contactsData.map((json) => ContactModel.fromJson(json)).toList();
    } catch (e) {
      print('Error loading contacts: $e');
      // Keep mock data as fallback
      if (contacts.isEmpty) {
        contacts = [
          ContactModel(id: '1', name: 'Mom', phone: '9876543210', type: ContactType.family),
          ContactModel(id: '2', name: 'Rahul', phone: '9123456780', type: ContactType.friend),
        ];
      }
    }
  }

  Future<bool> startListening(Function(String) onResult) async {
    bool available = await _speech.initialize();
    if (!available) return false;

    isListening = true;

    _speech.listen(
      onResult: (result) {
        final spoken = result.recognizedWords.toUpperCase();
        onResult(spoken);
      },
      listenMode: stt.ListenMode.confirmation,
    );

    return true;
  }

  void stopListening() {
    _speech.stop();
    isListening = false;
  }

  // Trigger SOS with backend integration
  Future<void> triggerSosMode({
    required double latitude,
    required double longitude,
    required String detectedWord,
    required double confidence,
    String severity = 'critical',
  }) async {
    try {
      // Trigger SOS via voice
      final response = await _sosService.triggerSosByVoice(
        latitude: latitude,
        longitude: longitude,
        detectedWord: detectedWord,
        confidence: confidence,
        severity: severity,
      );

      _currentAlertId = response['id'];
      
      // Start continuous location tracking
      _startLocationTracking(_currentAlertId!);

      _startSosSmsTimer();

      print('SOS triggered successfully: ${response['id']}');
    } catch (e) {
      print('Error triggering SOS: $e');
      rethrow;
    }
  }

  // Start continuous location tracking for active alert
  void _startLocationTracking(int alertId) {
    _locationUpdateTimer?.cancel();
    
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        final locationData = await _locationServicePlatform.getLocation();
        await _sosService.updateAlertLocation(
          alertId: alertId,
          latitude: locationData.latitude!,
          longitude: locationData.longitude!,
          accuracy: locationData.accuracy,
          speed: locationData.speed,
          heading: locationData.heading,
        );
      } catch (e) {
        print('Error updating alert location: $e');
      }
    });
  }

  ContactModel? _getPrimaryContact() {
    try {
      return contacts.firstWhere((c) => c.isTrusted);
    } catch (_) {
      return null;
    }
  }

  Future<void> _sendSosSmsToPrimaryContact() async {
    final primary = _getPrimaryContact();
    if (primary == null) return;

    final locationData = await _locationServicePlatform.getLocation();
    final latitude = locationData.latitude;
    final longitude = locationData.longitude;

    String message = 'SOS. I need help.';
    if (latitude != null && longitude != null) {
      final link = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
      message = '$message My location: $link';
    }

    await SosSmsSender.send(primary.phone, message);
  }

  void _startSosSmsTimer() {
    _sosSmsTimer?.cancel();
    _sosSmsTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      await _sendSosSmsToPrimaryContact();
    });
  }

  void _stopSosSmsTimer() {
    _sosSmsTimer?.cancel();
    _sosSmsTimer = null;
  }

  // Stop location tracking
  void stopLocationTracking() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
    _stopSosSmsTimer();
  }

  // Resolve alert
  Future<void> resolveAlert() async {
    if (_currentAlertId != null) {
      try {
        await _sosService.resolveAlert(_currentAlertId!);
        stopLocationTracking();
        _currentAlertId = null;
      } catch (e) {
        print('Error resolving alert: $e');
      }
    }
  }

  // Escalate alert to authorities
  Future<void> escalateToAuthorities() async {
    if (_currentAlertId != null) {
      try {
        await _sosService.escalateAlert(
          alertId: _currentAlertId!,
          escalatedTo: 'police_112',
          severity: 'critical',
        );
      } catch (e) {
        print('Error escalating alert: $e');
      }
    }
  }

  // Update codeword in backend
  Future<void> updateCodeword(String newCodeword) async {
    try {
      await _authService.updateProfile(codeword: newCodeword);
      userSafeWord = newCodeword;
    } catch (e) {
      print('Error updating codeword: $e');
    }
  }

  // Add contact to backend
  Future<void> addContact({
    required String name,
    required String phone,
    String? email,
    ContactType type = ContactType.family,
    bool isPrimary = false,
  }) async {
    try {
      final response = await _contactsService.createContact(
        name: name,
        phone: phone,
        email: email,
        relation: type == ContactType.family ? 'family' : 'friend',
        isPrimary: isPrimary,
      );
      
      contacts.add(ContactModel.fromJson(response));
    } catch (e) {
      print('Error adding contact: $e');
      rethrow;
    }
  }

  // Delete contact from backend
  Future<void> deleteContact(String contactId) async {
    try {
      await _contactsService.deleteContact(int.parse(contactId));
      contacts.removeWhere((c) => c.id == contactId);
    } catch (e) {
      print('Error deleting contact: $e');
      rethrow;
    }
  }

  // Helper to toggle internal state (logic simulation)
  void toggleSosMode(bool isActive) {
    // Backend logic handled in triggerSosMode
  }
}

// =============================================================================
// NAVIGATION HUB
// =============================================================================

class MainNavigationHub extends StatefulWidget {
  const MainNavigationHub({super.key});

  @override
  State<MainNavigationHub> createState() => _MainNavigationHubState();
}

class _MainNavigationHubState extends State<MainNavigationHub> {
  int _currentIndex = 0;
  final bool _isSosActive = false;

  final List<Widget> _pages = [
    const HomeScreen(),
    const LiveTrackMapScreen(),
    const TrustedContactsScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    SafetyController().initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          // RED OVERLAY FLASH when SOS is active
          if (_isSosActive)
            IgnorePointer(
              child: Container(
                color: Colors.red.withValues(alpha: 0.1),
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        indicatorColor: _isSosActive ? Colors.red.shade100 : Colors.purple.shade100,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield),
            label: "SOS",
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on_outlined),
            selectedIcon: Icon(Icons.location_on),
            label: "Track Me",
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: "Contacts",
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_voice_outlined),
            selectedIcon: Icon(Icons.settings_voice),
            label: "Settings",
          ),
        ],
      ),
    );
  }
}

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
  final Location _location = Location();
  LocationData? _currentLocation;

  @override
  void initState() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _initSpeech();
    _getCurrentLocation();
    super.initState();
  }

  Future<void> _initSpeech() async {
    await ph.Permission.microphone.request();
    speechEnabled = await speech.initialize();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) return;
      }

      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) return;
      }

      _currentLocation = await _location.getLocation();
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _listeningTimeout?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // UPDATED LOGIC: Voice Validation -> Trigger SOS with Backend
  // ---------------------------------------------------------------------------

  void _startVoiceValidation() async {
    // 1. Visual Feedback
    HapticFeedback.lightImpact();
    setState(() => _isListening = true);
    
    final safeWord = SafetyController().userSafeWord;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("LISTENING... SAY: '$safeWord'"),
        backgroundColor: Colors.purple,
        duration: const Duration(seconds: 5),
      ),
    );

    if (!speechEnabled) {
      bool available = await speech.initialize();
      if (!available) {
        setState(() => _isListening = false);
        return;
      }
    }

    // Get current location
    await _getCurrentLocation();
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location not available. Please enable GPS.")),
      );
      setState(() => _isListening = false);
      return;
    }

    // 2. Start Listening
    speech.listen(
      onResult: (result) {
        final words = result.recognizedWords.toLowerCase();
        final target = safeWord.toLowerCase();

        // 3. Validation
        if (words.contains(target)) {
          _stopVoiceValidation();
          _triggerSOSAlert(); // Success!
        }
      },
      listenMode: stt.ListenMode.confirmation,
      cancelOnError: true,
      partialResults: true,
    );

    // 4. Timeout Logic (5 seconds)
    _listeningTimeout = Timer(const Duration(seconds: 5), () {
      if (_isListening) {
        _stopVoiceValidation();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Voice match failed. SOS Cancelled.")),
        );
      }
    });
  }

  void _stopVoiceValidation() {
    speech.stop();
    _listeningTimeout?.cancel();
    if (mounted) setState(() => _isListening = false);
  }

  // ---------------------------------------------------------------------------
  // ACTUAL ALARM TRIGGER with Backend Integration
  // ---------------------------------------------------------------------------

  void _triggerSOSAlert() async {
    HapticFeedback.heavyImpact(); // Physical feedback
    
    if (_currentLocation == null) {
      await _getCurrentLocation();
      if (_currentLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cannot trigger SOS: Location unavailable")),
        );
        return;
      }
    }

    try {
      // Trigger SOS via backend
      await SafetyController().triggerSosMode(
        latitude: _currentLocation!.latitude!,
        longitude: _currentLocation!.longitude!,
        detectedWord: SafetyController().userSafeWord,
        confidence: 0.95,
        severity: 'critical',
      );

      // Show success message
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
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("No, Just Contacts"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await SafetyController().escalateToAuthorities();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Alert escalated to Police (112)")),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e")),
                  );
                }
              },
              child: const Text("CALL POLICE (112)", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error triggering SOS: $e")),
      );
    }
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

class LiveTrackMapScreen extends StatefulWidget {
  const LiveTrackMapScreen({super.key});

  @override
  State<LiveTrackMapScreen> createState() => _LiveTrackMapScreenState();
}

class _LiveTrackMapScreenState extends State<LiveTrackMapScreen> {
  final Location _location = Location();
  LatLng? _currentLocation;
  Timer? _locationUpdateTimer;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _startLocationTracking();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) return;
      }

      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) return;
      }

      final locationData = await _location.getLocation();
      setState(() {
        _currentLocation = LatLng(locationData.latitude!, locationData.longitude!);
      });

      // Update location in backend
      try {
        final locationService = LocationService();
        await locationService.updateLocation(
          latitude: locationData.latitude!,
          longitude: locationData.longitude!,
          accuracy: locationData.accuracy,
          speed: locationData.speed,
          heading: locationData.heading,
        );
      } catch (e) {
        print('Error updating location in backend: $e');
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  void _startLocationTracking() {
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _getCurrentLocation();
    });
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentLocation = _currentLocation ?? const LatLng(19.1197, 72.8468); // Default: Andheri

    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Tracking"),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
            tooltip: 'Update Location',
          ),
        ],
      ),
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
  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    await SafetyController().loadContacts();
    setState(() {});
  }

  Future<void> _deleteContact(String contactId) async {
    try {
      await SafetyController().deleteContact(contactId);
      await _loadContacts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Contact deleted")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting contact: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = SafetyController();
    
    return Scaffold(
      appBar: AppBar(title: const Text("Trusted Circle")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section: Authorities
          const Text("AUTHORITIES", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          Card(
            color: Colors.red.shade50,
            child: ListTile(
              leading: const Icon(Icons.local_police, color: Colors.indigo, size: 30),
              title: const Text("Police Control Room"),
              subtitle: const Text("Automatic Alert on High Severity"),
              trailing: Switch(value: true,onChanged: (v) {},activeThumbColor: Colors.indigo,activeTrackColor: Colors.indigo.withValues(alpha: 0.5),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          // Section: Family & Friends
          const Text("FAMILY & FRIENDS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          ...controller.contacts.where((c) => c.type == ContactType.family || c.type == ContactType.friend).map((contact) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple.shade100,
                  child: Text(contact.name[0]),
                ),
                title: Text(contact.name),
                subtitle: Text(contact.phone),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteContact(contact.id),
                ),
              ),
            );
          }),

          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () {
              // Show add contact dialog
              showDialog(
                context: context,
                builder: (ctx) => _AddContactDialog(
                  onContactAdded: () {
                    _loadContacts();
                    Navigator.pop(ctx);
                  },
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text("ADD NEW CONTACT"),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(15),
              side: const BorderSide(color: Colors.purple),
            ),
          )
        ],
      ),
    );
  }
}

// Add Contact Dialog
class _AddContactDialog extends StatefulWidget {
  final VoidCallback onContactAdded;

  const _AddContactDialog({required this.onContactAdded});

  @override
  State<_AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<_AddContactDialog> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  ContactType _selectedType = ContactType.family;
  bool _isPrimary = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _addContact() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Name and phone are required")),
      );
      return;
    }

    try {
      await SafetyController().addContact(
        name: _nameController.text,
        phone: _phoneController.text,
        email: _emailController.text.isEmpty ? null : _emailController.text,
        type: _selectedType,
        isPrimary: _isPrimary,
      );
      widget.onContactAdded();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error adding contact: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Add Contact"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Name"),
            ),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: "Phone"),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email (optional)"),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),
            DropdownButton<ContactType>(
              value: _selectedType,
              items: const [
                DropdownMenuItem(value: ContactType.family, child: Text("Family")),
                DropdownMenuItem(value: ContactType.friend, child: Text("Friend")),
              ],
              onChanged: (value) => setState(() => _selectedType = value!),
            ),
            CheckboxListTile(
              title: const Text("Primary Contact"),
              value: _isPrimary,
              onChanged: (value) => setState(() => _isPrimary = value ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _addContact,
          child: const Text("Add"),
        ),
      ],
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

  Future<void> _updateCodeword() async {
    if (_wordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Codeword cannot be empty")),
      );
      return;
    }

    try {
      await SafetyController().updateCodeword(_wordController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Codeword updated successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating codeword: $e")),
        );
      }
    }
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
            try {
              await SafetyController()._authService.logout();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Logged out successfully!")),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error logging out: $e")),
                );
              }
            }
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
                        // Update in real-time
                        if (value.isNotEmpty) {
                          SafetyController().userSafeWord = value;
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _updateCodeword,
                      child: const Text("Save Codeword"),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Sensitivity
            _buildSectionHeader("Fall & Shake Detection"),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text("Shake Sensitivity"),
                    Slider(
                      value: _shakeSensitivity, 
                      onChanged: (v) => setState(() => _shakeSensitivity = v),
                      activeColor: Colors.purple,
                    ),
                    const Text("Low -------------------- High", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Profile
            // _buildSectionHeader("My Profile"),
            // ListTile(
            //   contentPadding: EdgeInsets.zero,
            //   leading: const CircleAvatar(radius: 30, backgroundImage: NetworkImage("https://i.pravatar.cc/150?img=5")), // Demo Image
            //   title: const Text("Anjali Sharma"),
            //   subtitle: const Text("+91 98765 43210"),
            //   trailing: IconButton(icon: const Icon(Icons.edit), onPressed: (){}),
            // ),
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
