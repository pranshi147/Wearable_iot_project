
import 'dart:async';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (!kIsWeb) {
    await GoogleSignIn.instance.initialize();
  }

  runApp(const SafetyApp());
}

class SafetyApp extends StatelessWidget {
  const SafetyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SafeWear',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B1220),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5796F5),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}


class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const Dashboard();
        }

        return const AuthPage();
      },
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();

  bool isLogin = true;
  bool loading = false;

  Future<void> saveUser(User user, {
    String? name,
    String? phone,
  }) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
      'name': name ?? user.displayName ?? '',
      'email': user.email ?? '',
      'phone': phone ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> emailAuthentication() async {
    setState(() => loading = true);

    try {
      final auth = FirebaseAuth.instance;
      UserCredential result;

      if (isLogin) {
        result = await auth.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
      } else {
        result = await auth.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        await result.user?.updateDisplayName(
          nameController.text.trim(),
        );
      }

      if (result.user != null) {
        await saveUser(
          result.user!,
          name: nameController.text.trim().isEmpty
              ? null
              : nameController.text.trim(),
          phone: phoneController.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      showError(e.message ?? 'Authentication failed');
    } catch (e) {
      showError(e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> googleAuthentication() async {
    setState(() => loading = true);

    try {
      UserCredential result;

      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        result = await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        final account =
            await GoogleSignIn.instance.authenticate();

        final googleAuth = account.authentication;

        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        result = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );
      }

      if (result.user != null) {
        await saveUser(result.user!);
      }
    } catch (e) {
      showError(e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.shield,
                  size: 75,
                  color: Colors.blueAccent,
                ),
                const SizedBox(height: 15),

                const Text(
                  'SafeWear',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  isLogin
                      ? 'Welcome Back!'
                      : 'Create Your Account',
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.white70,
                  ),
                ),

                const SizedBox(height: 30),

                if (!isLogin) ...[
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),

                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                ],

                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 15),

                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: loading
                        ? null
                        : emailAuthentication,
                    child: loading
                        ? const CircularProgressIndicator()
                        : Text(
                            isLogin ? 'LOGIN' : 'SIGN UP',
                          ),
                  ),
                ),

                const SizedBox(height: 15),

                const Text('OR'),

                const SizedBox(height: 15),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: loading
                        ? null
                        : googleAuthentication,
                    icon: const Icon(Icons.g_mobiledata),
                    label: const Text('Continue with Google'),
                  ),
                ),

                const SizedBox(height: 20),

                TextButton(
                  onPressed: () {
                    setState(() {
                      isLogin = !isLogin;
                    });
                  },
                  child: Text(
                    isLogin
                        ? "Don't have an account? Sign Up"
                        : 'Already have an account? Login',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  BluetoothDevice? connectedDevice;
  StreamSubscription<List<ScanResult>>? scanSubscription;
  StreamSubscription<BluetoothConnectionState>? connectionSubscription;
  final List<StreamSubscription<List<int>>> sensorSubscriptions = [];

  bool isScanning = false;
  bool isConnected = false;
  bool sosActive = false;
  bool magneticStatus = false;
  bool vibrationStatus = false;

  int heartRate = 0;
  int countdown = 10;

  String deviceName = 'Not connected';
  String locationText = 'Location not fetched';

  Timer? sosTimer;

  // Search for the ESP32-C3 wearable.
  Future<void> scanForWearable() async {
    try {
      if (!await FlutterBluePlus.isSupported) {
        showMessage('Bluetooth is not supported on this phone.');
        return;
      }
      await Permission.bluetoothScan.request();
      await Permission.bluetoothConnect.request();
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
      );

      setState(() => isScanning = true);

      scanSubscription?.cancel();
      scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          final name = result.device.platformName;

          if (name.toLowerCase().contains('safety') ||
              name.toLowerCase().contains('esp32')) {
            FlutterBluePlus.stopScan();
            connectToWearable(result.device);
            break;
          }
        }
      });

      Future.delayed(const Duration(seconds: 10), () {
        if (mounted && !isConnected) {
          setState(() => isScanning = false);
        }
      });
    } catch (e) {
      showMessage('Bluetooth scan failed: $e');
      setState(() => isScanning = false);
    }
  }

  // Connect to the ESP32-C3.
  Future<void> connectToWearable(BluetoothDevice device) async {
    try {
          await device.connect(
            license: License.nonprofit,
          );

      connectedDevice = device;

      connectionSubscription?.cancel();
      connectionSubscription = device.connectionState.listen((state) {
        if (!mounted) return;

        setState(() {
          isConnected = state == BluetoothConnectionState.connected;
          deviceName = isConnected
              ? device.platformName
              : 'Not connected';
        });
      });

      setState(() {
        isConnected = true;
        isScanning = false;
        deviceName = device.platformName;
      });

      await listenToSensors(device);

      showMessage('Wearable connected successfully!');
    } catch (e) {
      showMessage('Connection failed: $e');
    }
  }

  // Discover characteristics and receive sensor notifications.
  Future<void> listenToSensors(BluetoothDevice device) async {
    final services = await device.discoverServices();

    for (final service in services) {
      for (final characteristic in service.characteristics) {
        if (characteristic.properties.notify ||
            characteristic.properties.indicate) {
          await characteristic.setNotifyValue(true);

          final subscription =
              characteristic.onValueReceived.listen((value) {
            if (value.isEmpty) return;

            final message = utf8.decode(
              value,
              allowMalformed: true,
            );

            processWearableData(message);
          });

          sensorSubscriptions.add(subscription);
          device.cancelWhenDisconnected(subscription);
        }
      }
    }
  }

  // Expected incoming data format: JSON.
  void processWearableData(String message) {
    try {
      final data = jsonDecode(message);

      if (data is! Map<String, dynamic>) return;

      if (!mounted) return;

      switch (data['type']) {
        case 'sos':
          if (data['value'] == 'pressed') {
            startSOSCountdown();
          }
          break;

        case 'ppg':
          setState(() {
            heartRate = (data['bpm'] as num).round();
          });
          break;

        case 'magnetic':
          setState(() {
            magneticStatus = data['state'] == 'detected';
          });
          break;

        case 'vibration':
          setState(() {
            vibrationStatus = data['state'] == 'on';
          });
          break;

        case 'cancel':
          cancelSOS();
          break;
      }
    } catch (e) {
      debugPrint('Invalid wearable message: $message');
    }
  }

  // Start the 10-second cancellation countdown.
  void startSOSCountdown() {
    if (sosActive) return;

    setState(() {
      sosActive = true;
      countdown = 10;
    });

    sosTimer?.cancel();

    sosTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (countdown <= 1) {
          timer.cancel();
          confirmSOS();
        } else {
          setState(() => countdown--);
        }
      },
    );
  }

  // Cancel an SOS before confirmation.
  void cancelSOS() {
    sosTimer?.cancel();

    setState(() {
      sosActive = false;
      countdown = 10;
    });

    showMessage('SOS cancelled.');
  }

  // Confirm SOS.
  Future<void> confirmSOS() async {
    setState(() => sosActive = false);

    await getCurrentLocation();

    // TODO: Save the SOS event in Firebase.
    // TODO: Notify emergency contacts using a secure backend.
    // TODO: Start periodic location trail uploads.

    showMessage('SOS CONFIRMED! Location captured.');
  }

  Future<void> getCurrentLocation() async {
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();

      if (!enabled) {
        setState(() => locationText = 'Location services disabled');
        return;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => locationText = 'Location permission denied');
        return;
      }

      Position position = await Geolocator.getCurrentPosition();

      setState(() {
        locationText =
            '${position.latitude.toStringAsFixed(5)}, '
            '${position.longitude.toStringAsFixed(5)}';
      });
    } catch (e) {
      setState(() => locationText = 'Unable to fetch location');
    }
  }

  Future<void> disconnectWearable() async {
    sosTimer?.cancel();

    await scanSubscription?.cancel();
    await connectionSubscription?.cancel();

    for (final subscription in sensorSubscriptions) {
      await subscription.cancel();
    }

    sensorSubscriptions.clear();

    await connectedDevice?.disconnect();

    if (!mounted) return;

    setState(() {
      connectedDevice = null;
      isConnected = false;
      isScanning = false;
      deviceName = 'Not connected';
    });
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    sosTimer?.cancel();
    scanSubscription?.cancel();
    connectionSubscription?.cancel();

    for (final subscription in sensorSubscriptions) {
      subscription.cancel();
    }

    connectedDevice?.disconnect();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SafeWear',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF111D32),
        actions: [
  IconButton(
    icon: const Icon(Icons.logout),
    tooltip: 'Logout',
    onPressed: () async {
      await FirebaseAuth.instance.signOut();

      if (!kIsWeb) {
        await GoogleSignIn.instance.signOut();
      }
    },
  ),
  const Icon(Icons.shield_outlined, color: Colors.blueAccent),
  const SizedBox(width: 18),
],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              'Your Safety Dashboard',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Stay connected. Stay protected.',
              style: TextStyle(color: Colors.white60),
            ),

            const SizedBox(height: 24),

            // Bluetooth connection card.
            dashboardCard(
              title: 'Wearable Connection',
              icon: Icons.bluetooth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Device: $deviceName'),
                  const SizedBox(height: 8),
                  Text(
                    isConnected ? 'Connected' : 'Disconnected',
                    style: TextStyle(
                      color: isConnected ? Colors.greenAccent : Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isConnected
                              ? disconnectWearable
                              : isScanning
                                  ? null
                                  : scanForWearable,
                          child: Text(
                            isConnected
                                ? 'Disconnect'
                                : isScanning
                                    ? 'Scanning...'
                                    : 'Connect Wearable',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // SOS card.
            dashboardCard(
              title: 'Emergency SOS',
              icon: Icons.warning_amber_rounded,
              child: Column(
                children: [
                  Icon(
                    Icons.sos,
                    size: 65,
                    color: sosActive ? Colors.orange : Colors.redAccent,
                  ),

                  const SizedBox(height: 10),

                  Text(
                    sosActive
                        ? 'SOS ACTIVATION PENDING'
                        : 'System Ready',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  if (sosActive) ...[
                    const SizedBox(height: 10),
                    Text(
                      '$countdown seconds',
                      style: const TextStyle(
                        fontSize: 30,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: cancelSOS,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('CANCEL SOS'),
                    ),
                  ] else
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Waiting for wearable signal',
                        style: TextStyle(color: Colors.white60),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'Live Sensor Monitoring',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: sensorCard(
                    'Heart Rate',
                    '$heartRate BPM',
                    Icons.favorite,
                    Colors.pinkAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: sensorCard(
                    'Magnetic',
                    magneticStatus ? 'Detected' : 'Normal',
                    Icons.sensors,
                    Colors.lightBlueAccent,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            sensorCard(
              'Vibration Feedback',
              vibrationStatus ? 'Active' : 'Inactive',
              Icons.vibration,
              Colors.amber,
            ),

            const SizedBox(height: 20),

            // Location card.
            dashboardCard(
              title: 'Location Tracking',
              icon: Icons.location_on,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(locationText),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: getCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Get Current Location'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Center(
              child: Text(
                'SafeWear • Personal Safety System',
                style: TextStyle(color: Colors.white38),
              ),
            ),

            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }

  Widget dashboardCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF17243A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blueAccent),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget sensorCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF17243A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.white60)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
