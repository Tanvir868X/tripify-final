import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'models/trip.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';
import 'widgets/weather_widget.dart';
import 'services/weather_service.dart';
import 'services/route_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme_service.dart';
import 'login_page.dart';
import 'services/auth_service.dart';
import 'services/hotel_service.dart';
import 'cloud_chat_page.dart';
import 'services/trip_service.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyAQXpL5TCRyAli-C3bdL2XnVsT3GE_1f_A",
        authDomain: "tripify-af9d7.firebaseapp.com",
        projectId: "tripify-af9d7",
        storageBucket: "tripify-af9d7.firebasestorage.app",
        messagingSenderId: "259390620824",
        appId: "1:259390620824:web:cccf099d0f024b9eed3ced",
        measurementId: "G-BJBWQV7BKZ",
      ),
    );
    print('Firebase initialized successfully');
  } catch (error) {
    print('Firebase initialization error: $error');
    // Continue without Firebase for now
  }
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeService(),
      child: const TripifyRoot(),
    ),
  );
}

class TripifyRoot extends StatefulWidget {
  const TripifyRoot({super.key});

  @override
  State<TripifyRoot> createState() => _TripifyRootState();
}

class _TripifyRootState extends State<TripifyRoot> {
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    print('TripifyRoot initState called');
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    print('Checking authentication...');
    try {
      final isSignedIn = await AuthService.isSignedIn();
      print('Authentication check result: $isSignedIn');
      setState(() {
        _isAuthenticated = isSignedIn;
        _isLoading = false;
      });
      print('State updated - isLoading: $_isLoading, isAuthenticated: $_isAuthenticated');
    } catch (error) {
      print('Authentication check error: $error');
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print('TripifyRoot build called - isLoading: $_isLoading, isAuthenticated: $_isAuthenticated');
    return Consumer<ThemeService>(
      builder: (context, themeService, _) {
        return MaterialApp(
          title: 'Tripify',
          theme: themeService.lightTheme,
          darkTheme: themeService.darkTheme,
          themeMode: themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: _isLoading 
            ? const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            : _isAuthenticated 
              ? const MainScreen() 
              : const LoginPage(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // In-memory favorites list
  static final List<Place> _favorites = [];
  // In-memory trips list (shared for adding places)
  static final List<Trip> _trips = [];
  // In-memory favorite trips list
  static final List<Trip> _favoriteTrips = [];

  static final List<Widget> _pages = <Widget>[
    HomePage(),
    MyTripsPage(trips: _trips, favoriteTrips: _favoriteTrips),
    PlacesPage(favorites: _favorites, trips: _trips),
    CloudChatPage(),
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tripify'),
        centerTitle: true,
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        elevation: 8,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.card_travel),
            label: 'Trips',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.place),
            label: 'Places',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cloud),
            label: 'Cloud Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  final TextEditingController _destinationController = TextEditingController(text: 'Paris');
  String _currentDestination = 'Paris';
  String? _username;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final userData = await AuthService.getUserData();
    String? name = userData['name'];
    String? email = userData['email'];
    if (name == null || name.isEmpty) {
      if (email != null && email.contains('@')) {
        name = email.split('@')[0];
      } else {
        name = 'User';
      }
    }
    setState(() {
      _username = name;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Mock data for popular destinations
    final List<Map<String, String>> popularDestinations = [
      {
        'image': 'https://images.unsplash.com/photo-1467269204594-9661b134dd2b?auto=format&fit=crop&w=600&q=80',
        'name': 'Eiffel Tower',
        'location': 'Paris',
        'type': 'Attraction',
        'desc': 'Iconic wrought-iron lattice tower on the Champ de Mars in Paris. A global cultural icon of France.'
      },
      {
        'image': 'https://images.unsplash.com/photo-1464983953574-0892a716854b?auto=format&fit=crop&w=600&q=80',
        'name': 'Shibuya Crossing',
        'location': 'Tokyo',
        'type': 'Attraction',
        'desc': "The world's busiest intersection, famous for its scramble crossing and vibrant city life."
      },
    ];

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App bar/header with logo and app name
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  ScaleTransition(
                    scale: _animation,
                    child: Icon(Icons.location_on, color: Colors.teal, size: 32),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Tripify',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
            ),
            // Welcome and New Trip button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, ${_username ?? 'User'}!',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Your next adventure starts here. Let's get planning.",
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: Icon(Icons.add),
                    label: Text('New Trip'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    onPressed: () async {
                      final tripImages = [
                        'assets/images/trips/trip1.jpg',
                        'assets/images/trips/trip2.jpeg',
                        'assets/images/trips/trip3.webp',
                        'assets/images/trips/trip4.jpeg',
                        'assets/images/trips/trip5.jpeg',
                      ];
                      final random = Random();
                      final imagePath = tripImages[random.nextInt(tripImages.length)];
                      final newTrip = await showDialog<Trip>(
                        context: context,
                        builder: (context) => AddTripDialog(initialImagePath: imagePath),
                      );
                      if (newTrip != null) {
                        try {
                          await TripService.addTrip(newTrip);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Trip added!'), backgroundColor: Colors.green),
                          );
                          setState(() {});
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error saving trip: ' + e.toString()), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Upcoming Trips', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            // Upcoming trips from Firestore
            StreamBuilder<List<Trip>>(
              stream: TripService.getUserTrips(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final upcomingTrips = snapshot.data ?? [];
                if (upcomingTrips.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No upcoming trips yet. Tap New Trip to add one!',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  );
                }
                return SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: upcomingTrips.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final trip = upcomingTrips[index];
                      final imageUrl = 'https://source.unsplash.com/featured/?${Uri.encodeComponent(trip.destination)}';
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TripDetailsPage(trip: trip),
                            ),
                          );
                        },
                        child: Container(
                          width: 260,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(18),
                                  topRight: Radius.circular(18),
                                ),
                                child: trip.imagePath.startsWith('assets/')
                                  ? Image.asset(
                                      trip.imagePath,
                                      width: 260,
                                      height: 120,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        width: 260,
                                        height: 120,
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.image, color: Colors.teal),
                                      ),
                                    )
                                  : Image.network(
                                      trip.imagePath,
                                      width: 260,
                                      height: 120,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        width: 260,
                                        height: 120,
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.image, color: Colors.teal),
                                      ),
                                    ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(trip.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                    const SizedBox(height: 4),
                                    Text('${trip.destination}', style: const TextStyle(color: Colors.teal)),
                                    const SizedBox(height: 4),
                                    Text('From: ${trip.from}'),
                                    Text('Dates: ${trip.startDate.toString().split(' ')[0]} - ${trip.endDate.toString().split(' ')[0]}'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            const Text('Popular Destinations', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 320,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: popularDestinations.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final dest = popularDestinations[index];
                  return Container(
                    width: 240,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(18),
                                topRight: Radius.circular(18),
                              ),
                              child: CachedNetworkImage(
                                imageUrl: dest['image']!,
                                height: 160,
                                width: 240,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  height: 160,
                                  width: 240,
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  height: 160,
                                  width: 240,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.error),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 10,
                              left: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(dest['type']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Icon(Icons.star, color: Colors.orange[300]),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(dest['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(dest['location']!, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(dest['desc']!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('Add to Trip'),
                                onPressed: () async {
                                  final tripImages = [
                                    'assets/images/trips/trip1.jpg',
                                    'assets/images/trips/trip2.jpeg',
                                    'assets/images/trips/trip3.webp',
                                    'assets/images/trips/trip4.jpeg',
                                    'assets/images/trips/trip5.jpeg',
                                  ];
                                  final random = Random();
                                  final imagePath = tripImages[random.nextInt(tripImages.length)];
                                  final newTrip = await showDialog<Trip>(
                                    context: context,
                                    builder: (context) => AddTripDialog(
                                      initialDestination: dest['location'],
                                      initialName: dest['name'],
                                      initialImagePath: imagePath,
                                    ),
                                  );
                                  if (newTrip != null) {
                                    try {
                                      await TripService.addTrip(newTrip);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Trip added!'), backgroundColor: Colors.green),
                                      );
                                      setState(() {});
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error saving trip: ' + e.toString()), backgroundColor: Colors.red),
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _username = 'John Doe';
  String _email = 'john.doe@example.com';
  String _phone = '+1 (555) 123-4567';
  String _userPhoto = '';
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  String _language = 'English';
  String _currency = 'USD';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await AuthService.getUserData();
      setState(() {
        _username = userData['name'] ?? 'User';
        _email = userData['email'] ?? 'user@example.com';
        _userPhoto = userData['photo'] ?? '';
      });
    } catch (error) {
      print('Error loading user data: $error');
    }
  }

  Future<void> _signOut() async {
    try {
      await AuthService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign out error: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade400, Colors.teal.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  // Profile Picture
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    backgroundImage: _userPhoto.isNotEmpty 
                      ? CachedNetworkImageProvider(_userPhoto) as ImageProvider
                      : null,
                    child: _userPhoto.isEmpty 
                      ? Icon(
                          Icons.person,
                          size: 60,
                          color: Colors.teal.shade700,
                        )
                      : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _username,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _email,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            
            // Basic profile content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.person, color: Colors.teal),
                      title: const Text('Username'),
                      subtitle: Text(_username),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showEditFieldDialog('Username', _username),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.email, color: Colors.teal),
                      title: const Text('Email'),
                      subtitle: Text(_email),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showEditFieldDialog('Email', _email),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.phone, color: Colors.teal),
                      title: const Text('Phone'),
                      subtitle: Text(_phone),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showEditFieldDialog('Phone', _phone),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Settings Section
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.notifications, color: Colors.teal),
                    title: const Text('Notifications'),
                    subtitle: const Text('Receive push notifications'),
                    trailing: Switch(
                      value: _notificationsEnabled,
                      onChanged: (value) => setState(() => _notificationsEnabled = value),
                      activeColor: Colors.teal,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.dark_mode, color: Colors.teal),
                    title: const Text('Dark Mode'),
                    subtitle: const Text('Use dark theme'),
                    trailing: Consumer<ThemeService>(
                      builder: (context, themeService, _) => Switch(
                        value: themeService.isDarkMode,
                        onChanged: (value) => themeService.toggleTheme(),
                        activeColor: Colors.teal,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.language, color: Colors.teal),
                    title: const Text('Language'),
                    subtitle: Text(_language),
                    trailing: DropdownButton<String>(
                      value: _language,
                      items: ['English', 'Spanish', 'French', 'German']
                          .map((lang) => DropdownMenuItem(
                                value: lang,
                                child: Text(lang),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() => _language = value!),
                      underline: Container(),
                    ),
                  ),
                  // Help & Support and About App removed from settings section
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Account Actions Section
            const Text(
              'Account',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.help, color: Colors.teal),
                    title: const Text('Help & Support'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Help & Support'),
                        content: const Text('For any help or support, please contact our support team or visit our website. We are here to assist you with any questions or issues you may have.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.info, color: Colors.teal),
                    title: const Text('About App'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('About App'),
                        content: const Text('''Tripify
Version 1.0.0

Your all-in-one travel companion app.'''),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Danger Zone Section
            const Text(
              'Danger Zone',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 12),
            
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      'Logout',
                      style: TextStyle(color: Colors.red),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showLogoutDialog(),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showEditFieldDialog(String field, String currentValue) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $field'),
        content: TextField(
          decoration: InputDecoration(labelText: field),
          controller: TextEditingController(text: currentValue),
          onChanged: (value) {
            switch (field) {
              case 'Username':
                _username = value;
                break;
              case 'Email':
                _email = value;
                break;
              case 'Phone':
                _phone = value;
                break;
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {});
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$field updated successfully!')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showHelpSupport() {
    // Implement help and support functionality
    print('Help and support dialog');
  }

  void _showAboutApp() {
    // Implement about app functionality
    print('About app dialog');
  }

  void _showLogoutDialog() {
    // Implement logout functionality
    print('Logout dialog');
  }
}

class MyTripsPage extends StatefulWidget {
  final List<Trip> trips;
  final List<Trip> favoriteTrips;
  const MyTripsPage({super.key, this.trips = const [], required this.favoriteTrips});

  @override
  State<MyTripsPage> createState() => _MyTripsPageState();
}

class _MyTripsPageState extends State<MyTripsPage> {
  // Remove local _trips and _favoriteTrips, use Firestore for trips
  // List<Trip> get _trips => widget.trips;
  // List<Trip> get _favoriteTrips => widget.favoriteTrips;
  List<Trip> _favoriteTrips = [];

  void _addTrip() async {
    final newTrip = await showDialog<Trip>(
      context: context,
      builder: (context) => AddTripDialog(),
    );
    if (newTrip != null) {
      try {
        await TripService.addTrip(newTrip);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip added!'), backgroundColor: Colors.green),
        );
        setState(() {}); // Refresh UI
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving trip: ' + e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openTripDetails(Trip trip) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TripDetailsPage(trip: trip, canEdit: true),
      ),
    );
    setState(() {}); // Refresh in case itinerary changed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Trip>>(
        stream: TripService.getUserTrips(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final trips = snapshot.data ?? [];
          if (trips.isEmpty) {
            return const Center(child: Text('No trips yet. Tap + to add one!'));
          }
          return ListView.builder(
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final trip = trips[index];
              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    trip.imagePath,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 48,
                      height: 48,
                      color: Colors.grey[300],
                      child: const Icon(Icons.error),
                    ),
                  ),
                ),
                title: Text(trip.name),
                subtitle: Text(
                    'From: ${trip.from}  To: ${trip.destination}\n${trip.startDate.toString().split(' ')[0]} - ${trip.endDate.toString().split(' ')[0]}\nBudget: ${trip.budget != null ? trip.budget.toString() : 'N/A'}'),
                isThreeLine: true,
                onTap: () => _openTripDetails(trip),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      tooltip: 'Edit',
                      onPressed: () async {
                        final editedTrip = await showDialog<Trip>(
                          context: context,
                          builder: (context) => EditTripDialog(trip: trip),
                        );
                        if (editedTrip != null) {
                          try {
                            await TripService.updateTrip(editedTrip.copyWith(id: trip.id));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Trip updated!'), backgroundColor: Colors.green),
                            );
                            setState(() {});
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error updating trip: ' + e.toString()), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Delete',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Trip'),
                            content: const Text('Are you sure you want to delete this trip?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: const Text('Delete'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          try {
                            await TripService.deleteTrip(trip.id!);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Trip deleted!'), backgroundColor: Colors.green),
                            );
                            setState(() {});
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error deleting trip: ' + e.toString()), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        _favoriteTrips.contains(trip) ? Icons.favorite : Icons.favorite_border,
                        color: _favoriteTrips.contains(trip) ? Colors.red : null,
                      ),
                      onPressed: () {
                        setState(() {
                          if (_favoriteTrips.contains(trip)) {
                            _favoriteTrips.remove(trip);
                          } else {
                            _favoriteTrips.add(trip);
                          }
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTrip,
        child: const Icon(Icons.add),
        tooltip: 'Add Trip',
      ),
    );
  }
}

class TripDetailsPage extends StatefulWidget {
  final Trip trip;
  final bool canEdit;
  const TripDetailsPage({super.key, required this.trip, this.canEdit = false});

  @override
  State<TripDetailsPage> createState() => _TripDetailsPageState();
}

class _TripDetailsPageState extends State<TripDetailsPage> {
  // Remove Amadeus/online hotel logic
  // Add hotel filter state for this trip
  String _selectedCountry = 'All';
  String _selectedCity = 'All';
  double _minPrice = 0;
  double _maxPrice = 200;
  double _minRating = 0;
  String? _bookedHotelName;
  
  // Add this state variable for trip booking
  bool _isTripBooked = false;
  Set<String> _bookedHotels = {};

  @override
  void initState() {
    super.initState();
    // Try to set default filters based on trip destination
    final dest = widget.trip.destination;
    final hotelMatch = hotels.firstWhere(
      (h) => dest.toLowerCase().contains(h.city.toLowerCase()) || dest.toLowerCase().contains(h.country.toLowerCase()),
      orElse: () => hotels.first,
    );
    _selectedCountry = hotelMatch.country;
    _selectedCity = hotelMatch.city;
  }

  List<Hotel> get _filteredHotels {
    final dest = widget.trip.destination.toLowerCase();
    return hotels.where((hotel) {
      final matchesDestination = hotel.city.toLowerCase() == dest || hotel.country.toLowerCase() == dest || dest.contains(hotel.city.toLowerCase()) || dest.contains(hotel.country.toLowerCase());
      final countryMatch = _selectedCountry == 'All' || hotel.country == _selectedCountry;
      final cityMatch = _selectedCity == 'All' || hotel.city == _selectedCity;
      final priceMatch = hotel.price >= _minPrice && hotel.price <= _maxPrice;
      final ratingMatch = hotel.rating >= _minRating;
      return matchesDestination && countryMatch && cityMatch && priceMatch && ratingMatch;
        }).toList();
      }
      
  List<String> get _countries => ['All', ...{for (var h in hotels) h.country}];
  List<String> get _cities => ['All', ...{for (var h in hotels.where((h) => _selectedCountry == 'All' || h.country == _selectedCountry)) h.city}];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.trip.destination),
        actions: widget.canEdit
            ? [
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit Trip',
                  onPressed: _editTrip,
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          // Buttons at the top
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.alt_route),
                  label: const Text('Calculate Route'),
                  onPressed: _showRouteInfo,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.cloud),
                  label: const Text('Show Weather'),
                  onPressed: _showWeatherInfo,
                ),
              ],
            ),
          ),
          // Booked Hotel section (always visible, like Itinerary)
       
        
          // Main content scrollable
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 80),
              children: [
                // Hotels section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.hotel, color: Colors.teal),
                      const SizedBox(width: 8),
                      Text(
                        'Hotels (${_filteredHotels.length} found)',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.map),
                        label: const Text('View Map'),
                        onPressed: () {
                          final hotelMarkers = _filteredHotels;
                          LatLng? center;
                          double zoom = 12;

                          if (hotelMarkers.isNotEmpty) {
                            if (hotelMarkers.length == 1) {
                              center = LatLng(hotelMarkers[0].latitude, hotelMarkers[0].longitude);
                              zoom = 14;
                            } else {
                              // Calculate average center
                              double avgLat = 0, avgLng = 0;
                              for (var h in hotelMarkers) {
                                avgLat += h.latitude;
                                avgLng += h.longitude;
                              }
                              avgLat /= hotelMarkers.length;
                              avgLng /= hotelMarkers.length;
                              center = LatLng(avgLat, avgLng);
                              zoom = 12;
                            }
                          } else {
                            center = LatLng(23.8103, 90.4125); // Default (Dhaka)
                            zoom = 8;
                          }

                          showDialog(
                            context: context,
                            builder: (context) => Dialog(
                              child: SizedBox(
                                width: 600,
                                height: 400,
                                child: FlutterMap(
                                  options: MapOptions(
                                    initialCenter: center!,
                                    initialZoom: zoom,
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      subdomains: ['a', 'b', 'c'],
                                    ),
                                    MarkerLayer(
                                      markers: hotelMarkers
                                          .map((hotel) => Marker(
                                                width: 40.0,
                                                height: 40.0,
                                                point: LatLng(hotel.latitude, hotel.longitude),
                                                child: GestureDetector(
                                                  onTap: () {
                                                    showDialog(
                                                      context: context,
                                                      builder: (context) => AlertDialog(
                                                        title: Text(hotel.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                                        content: Text('${hotel.city}, ${hotel.country}'),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () => Navigator.of(context).pop(),
                                                            child: const Text('Close'),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                  child: Icon(Icons.location_on, color: Colors.red, size: 32),
                                                ),
                                              ))
                                          .toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Hotel Filters
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    children: [
                      DropdownButton<String>(
                        value: _selectedCountry,
                        items: _countries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => setState(() {
                          _selectedCountry = v!;
                          _selectedCity = 'All';
                        }),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _selectedCity,
                        items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => setState(() => _selectedCity = v!),
                      ),
                      const SizedBox(width: 8),
                      Text('Price:'),
                      SizedBox(
                        width: 80,
                        child: Slider(
                          value: _minPrice,
                          min: 0,
                          max: 200,
                          divisions: 20,
                          label: '${_minPrice.round()}',
                          onChanged: (v) => setState(() => _minPrice = v),
                        ),
                      ),
                      Text('to'),
                      SizedBox(
                        width: 80,
                        child: Slider(
                          value: _maxPrice,
                          min: 0,
                          max: 200,
                          divisions: 20,
                          label: '${_maxPrice.round()}',
                          onChanged: (v) => setState(() => _maxPrice = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Min Rating:'),
                      SizedBox(
                        width: 60,
                        child: Slider(
                          value: _minRating,
                          min: 0,
                          max: 5,
                          divisions: 10,
                          label: _minRating.toStringAsFixed(1),
                          onChanged: (v) => setState(() => _minRating = v),
                        ),
                      ),
                    ],
                  ),
                ),
                // Hotel List (clickable)
                if (_filteredHotels.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(child: Text('No hotels found for this destination.')),
                  )
                else
                  ..._filteredHotels.map((hotel) => Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          hotel.imageUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey[300],
                            child: const Icon(Icons.hotel, color: Colors.teal),
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(child: Text(hotel.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                          if (_bookedHotelName == hotel.name) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Booked', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${hotel.city}, ${hotel.country}'),
                          Row(
                            children: [
                              Icon(Icons.star, color: Colors.amber, size: 16),
                              Text('${hotel.rating}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Text('(${hotel.reviewCount} reviews)'),
                            ],
                          ),
                          Text('Price: ${hotel.price}'),
                          Wrap(
                            spacing: 6,
                            children: hotel.facilities.map((f) => Chip(label: Text(f), backgroundColor: Colors.teal.shade50)).toList(),
                          ),
                        ],
                      ),
                      onTap: () => showDialog(
                        context: context,
                        builder: (context) {
                          final isBooked = _bookedHotels.contains(hotel.name);
                          return AlertDialog(
                            title: Text(hotel.name),
                            content: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      hotel.imageUrl,
                                      width: 250,
                                      height: 150,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        width: 250,
                                        height: 150,
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.hotel, color: Colors.teal),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text('City: ${hotel.city}'),
                                  Text('Country: ${hotel.country}'),
                                  Text('Price: ${hotel.price}'),
                                  Row(
                                    children: [
                                      Icon(Icons.star, color: Colors.amber, size: 16),
                                      Text('${hotel.rating}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      Text('(${hotel.reviewCount} reviews)'),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    children: hotel.facilities.map((f) => Chip(label: Text(f), backgroundColor: Colors.teal.shade50)).toList(),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text('Reviews:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ...hotel.reviews.map<Widget>((review) => ListTile(
                                    leading: Icon(Icons.person, color: Colors.teal),
                                    title: Text(review['user']),
                                    subtitle: Row(
                                      children: [
                                        ...List.generate(5, (i) => Icon(
                                          i < review['rating'] ? Icons.star : Icons.star_border,
                                          color: Colors.amber,
                                          size: 14,
                                        )),
                                        const SizedBox(width: 8),
                                        Text(review['comment']),
                                      ],
                                    ),
                                  )),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Close'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  // Write Review Dialog
                                  String reviewText = '';
                                  int reviewStars = 5;
                                  final userController = TextEditingController();
                                  await showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Write a Review'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextField(
                                            controller: userController,
                                            decoration: const InputDecoration(labelText: 'Your Name'),
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: List.generate(5, (i) => IconButton(
                                              icon: Icon(
                                                i < reviewStars ? Icons.star : Icons.star_border,
                                                color: Colors.amber,
                                              ),
                                              onPressed: () {
                                                reviewStars = i + 1;
                                                (context as Element).markNeedsBuild();
                                              },
                                            )),
                                          ),
                                          TextField(
                                            decoration: const InputDecoration(labelText: 'Comment'),
                                            onChanged: (v) => reviewText = v,
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            if (userController.text.isNotEmpty && reviewText.isNotEmpty) {
                                              hotel.reviews.add({
                                                'user': userController.text,
                                                'rating': reviewStars,
                                                'comment': reviewText,
                                              });
                                              (context.findAncestorStateOfType<_TripDetailsPageState>())?.setState(() {});
                                              Navigator.of(context).pop();
                                            }
                                          },
                                          child: const Text('Submit'),
                                        ),
                                      ],
                                    ),
                                  );
                                  (context.findAncestorStateOfType<_TripDetailsPageState>())?.setState(() {});
                                },
                                child: const Text('Write Review'),
                              ),
                              ElevatedButton(
                                onPressed: isBooked
                                    ? null
                                    : () {
                                        setState(() {
                                          _bookedHotels.add(hotel.name);
                                        });
                                        Navigator.of(context).pop();
                                      },
                                child: Text(isBooked ? 'Booked!' : 'Book Now'),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  )),
                const SizedBox(height: 24),
                // Itinerary section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: const [
                      Icon(Icons.list, color: Colors.teal),
                      SizedBox(width: 8),
                      Text('Itinerary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                if (widget.trip.itinerary.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: Text('No itinerary items yet. Tap + to add one!')),
                  )
                else
                  ...widget.trip.itinerary.map((item) => ListTile(
                        leading: Icon(_iconForType(item.type)),
                        title: Text(item.title),
                        subtitle: Text(item.type + (item.dateTime != null ? ' - ' + item.dateTime!.toString().split(' ')[0] : '')),
                      )),
                // After the top buttons and before hotel filters in TripDetailsPage:
               
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItineraryItem,
        child: const Icon(Icons.add),
        tooltip: 'Add Itinerary Item',
      ),
    );
  }

  void _showRouteInfo() {
    // Mock route info; replace with real API call if needed
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Route Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Distance: 120 km'),
            SizedBox(height: 8),
            Text('Estimated Time: 1 hr 45 min'),
            SizedBox(height: 8),
            Text('Route: Main Highway, Exit 12, City Center'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showWeatherInfo() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 400,
          height: 500,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wb_sunny, color: Colors.white, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Weather in ${widget.trip.destination}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              // Weather Widget
              Expanded(
                child: WeatherWidget(destination: widget.trip.destination),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHotelMapView() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 800,
          height: 600,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.map, color: Colors.white, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Hotels Map View',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              // Map
              
            ],
          ),
        ),
      ),
    );
  }

  void _showBookingDialog(Map<String, dynamic> hotel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Book ${hotel['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hotel['image'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: hotel['image'],
                  width: 200,
                  height: 120,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 200,
                    height: 120,
                    color: Colors.grey[300],
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 200,
                    height: 120,
                    color: Colors.grey[300],
                    child: const Icon(Icons.error),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text('Price: ${hotel['price']} USD'),
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 16),
                Text('${hotel['rating']}'),
              ],
            ),
            const SizedBox(height: 8),
            Text('Location: ${hotel['location']}'),
            const SizedBox(height: 8),
            Text('Rooms available: ${hotel['roomsAvailable']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Booking request sent!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showReviewsDialog(Map<String, dynamic> hotel) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('Reviews for ${hotel['name']}'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hotel['reviews'] == null || hotel['reviews'].isEmpty)
                  const Text('No reviews yet.'),
                if (hotel['reviews'] != null)
                  ...hotel['reviews'].map<Widget>((review) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Icon(Icons.person, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('${review['user']}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Icon(Icons.star, color: Colors.amber, size: 14),
                            Text('${review['rating']}'),
                            const SizedBox(width: 4),
                            Expanded(child: Text(review['comment'])),
                          ],
                        ),
                      )),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.rate_review),
                  label: const Text('Write a Review'),
                  onPressed: () async {
                    final newReview = await showDialog<Map<String, dynamic>>(
                      context: context,
                      builder: (context) => _WriteReviewDialog(),
                    );
                    if (newReview != null) {
                      setStateDialog(() {
                        hotel['reviews'].add(newReview);
                      });
                      setState(() {}); // update main UI
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'Activity':
        return Icons.event;
      case 'Attraction':
        return Icons.place;
      case 'Accommodation':
        return Icons.hotel;
      default:
        return Icons.help;
    }
  }

  String _getHotelImage(String hotelName) {
    // List of high-quality hotel placeholder images from Unsplash
    final List<String> hotelImages = [
      'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=400&q=80',
      'https://images.unsplash.com/photo-1551882547-ff40c63fe5fa?auto=format&fit=crop&w=400&q=80',
      'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?auto=format&fit=crop&w=400&q=80',
      'https://images.unsplash.com/photo-1578662996442-48f60103fc96?auto=format&fit=crop&w=400&q=80',
      'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?auto=format&fit=crop&w=400&q=80',
      'https://images.unsplash.com/photo-1571896349842-33c89424de2d?auto=format&fit=crop&w=400&q=80',
      'https://images.unsplash.com/photo-1590490360182-c33d57733427?auto=format&fit=crop&w=400&q=80',
      'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?auto=format&fit=crop&w=400&q=80',
    ];
    
    // Use hotel name to consistently assign the same image to the same hotel
    final hash = hotelName.hashCode.abs();
    final index = hash % hotelImages.length;
    return hotelImages[index];
  }

  void _addItineraryItem() async {
    final newItem = await showDialog<ItineraryItem>(
      context: context,
      builder: (context) => AddItineraryItemDialog(),
    );
    if (newItem != null) {
      setState(() {
        widget.trip.itinerary.add(newItem);
      });
    }
  }

  void _editTrip() async {
    final editedTrip = await showDialog<Trip>(
      context: context,
      builder: (context) => EditTripDialog(trip: widget.trip),
    );
    if (editedTrip != null) {
      setState(() {
        widget.trip.destination = editedTrip.destination;
        widget.trip.startDate = editedTrip.startDate;
        widget.trip.endDate = editedTrip.endDate;
      });
    }
  }

  void _bookHotel(String hotelName) {
    setState(() {
      _bookedHotelName = hotelName;
    });
  }
}

class AddTripDialog extends StatefulWidget {
  final String? initialDestination;
  final String? initialName;
  final String? initialImagePath;
  const AddTripDialog({Key? key, this.initialDestination, this.initialName, this.initialImagePath}) : super(key: key);

  @override
  State<AddTripDialog> createState() => _AddTripDialogState();
}

class _AddTripDialogState extends State<AddTripDialog> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _from = '';
  String _destination = '';
  double? _budget;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _name = widget.initialName ?? '';
    _destination = widget.initialDestination ?? '';
    _imagePath = widget.initialImagePath;
  }

  @override
  Widget build(BuildContext context) {
    final tripImages = [
      'assets/images/trips/trip1.jpg',
      'assets/images/trips/trip2.jpeg',
      'assets/images/trips/trip3.webp',
      'assets/images/trips/trip4.jpeg',
      'assets/images/trips/trip5.jpeg',
    ];
    return AlertDialog(
      title: const Text('Add New Trip'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: _name,
                decoration: const InputDecoration(labelText: 'My Trip Name'),
                validator: (value) => value == null || value.isEmpty ? 'Enter a trip name' : null,
                onSaved: (value) => _name = value ?? '',
              ),
              const SizedBox(height: 10),
              TextFormField(
                decoration: const InputDecoration(labelText: 'From'),
                validator: (value) => value == null || value.isEmpty ? 'Enter a starting location' : null,
                onSaved: (value) => _from = value ?? '',
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: _destination,
                decoration: const InputDecoration(labelText: 'To (Destination)'),
                validator: (value) => value == null || value.isEmpty ? 'Enter a destination' : null,
                onSaved: (value) => _destination = value ?? '',
              ),
              const SizedBox(height: 10),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Trip Budget'),
                keyboardType: TextInputType.number,
                onSaved: (value) => _budget = value != null && value.isNotEmpty ? double.tryParse(value) : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(_startDate == null ? 'Start Date' : _startDate!.toString().split(' ')[0]),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => _startDate = picked);
                      }
                    },
                    child: const Text('Pick'),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(_endDate == null ? 'End Date' : _endDate!.toString().split(' ')[0]),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: _startDate ?? DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => _endDate = picked);
                      }
                    },
                    child: const Text('Pick'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate() && _startDate != null && _endDate != null) {
              _formKey.currentState!.save();
              final imagePath = _imagePath ?? tripImages[Random().nextInt(tripImages.length)];
              Navigator.of(context).pop(Trip(
                name: _name,
                from: _from,
                destination: _destination,
                startDate: _startDate!,
                endDate: _endDate!,
                budget: _budget,
                itinerary: [],
                imagePath: imagePath,
              ));
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class AddItineraryItemDialog extends StatefulWidget {
  @override
  State<AddItineraryItemDialog> createState() => _AddItineraryItemDialogState();
}

class _AddItineraryItemDialogState extends State<AddItineraryItemDialog> {
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  String _type = 'Activity';
  String? _description;
  DateTime? _dateTime;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Itinerary Item'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) => value == null || value.isEmpty ? 'Enter a title' : null,
                onSaved: (value) => _title = value ?? '',
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _type,
                items: const [
                  DropdownMenuItem(value: 'Activity', child: Text('Activity')),
                  DropdownMenuItem(value: 'Attraction', child: Text('Attraction')),
                  DropdownMenuItem(value: 'Accommodation', child: Text('Accommodation')),
                ],
                onChanged: (value) => setState(() => _type = value ?? 'Activity'),
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Description (optional)'),
                onSaved: (value) => _description = value,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(_dateTime == null ? 'Date (optional)' : _dateTime!.toString().split(' ')[0]),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => _dateTime = picked);
                      }
                    },
                    child: const Text('Pick'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              Navigator.of(context).pop(ItineraryItem(
                title: _title,
                type: _type,
                description: _description,
                dateTime: _dateTime,
                place: null,
              ));
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class EditTripDialog extends StatefulWidget {
  final Trip trip;
  const EditTripDialog({super.key, required this.trip});

  @override
  State<EditTripDialog> createState() => _EditTripDialogState();
}

class _EditTripDialogState extends State<EditTripDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _from;
  late String _destination;
  late double? _budget;
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _name = widget.trip.name;
    _from = widget.trip.from;
    _destination = widget.trip.destination;
    _budget = widget.trip.budget;
    _startDate = widget.trip.startDate;
    _endDate = widget.trip.endDate;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Trip'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: _name,
                decoration: const InputDecoration(labelText: 'My Trip Name'),
                validator: (value) => value == null || value.isEmpty ? 'Enter a trip name' : null,
                onSaved: (value) => _name = value ?? '',
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: _from,
                decoration: const InputDecoration(labelText: 'From'),
                validator: (value) => value == null || value.isEmpty ? 'Enter a starting location' : null,
                onSaved: (value) => _from = value ?? '',
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: _destination,
                decoration: const InputDecoration(labelText: 'To (Destination)'),
                validator: (value) => value == null || value.isEmpty ? 'Enter a destination' : null,
                onSaved: (value) => _destination = value ?? '',
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: _budget != null ? _budget.toString() : '',
                decoration: const InputDecoration(labelText: 'Trip Budget'),
                keyboardType: TextInputType.number,
                onSaved: (value) => _budget = value != null && value.isNotEmpty ? double.tryParse(value) : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(_startDate == null ? 'Start Date' : _startDate.toString().split(' ')[0]),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => _startDate = picked);
                      }
                    },
                    child: const Text('Pick'),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(_endDate == null ? 'End Date' : _endDate.toString().split(' ')[0]),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _endDate,
                        firstDate: _startDate,
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => _endDate = picked);
                      }
                    },
                    child: const Text('Pick'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              Navigator.of(context).pop(Trip(
                name: _name,
                from: _from,
                destination: _destination,
                startDate: _startDate,
                endDate: _endDate,
                budget: _budget,
                itinerary: widget.trip.itinerary,
                imagePath: widget.trip.imagePath,
              ));
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class PlacesPage extends StatefulWidget {
  final List<Place> favorites;
  final List<Trip> trips;
  const PlacesPage({super.key, required this.favorites, required this.trips});

  @override
  State<PlacesPage> createState() => _PlacesPageState();
}

class _PlacesPageState extends State<PlacesPage> {
  // Remove old places data
  final List<Place> _allPlaces = [];
  String _search = '';

  // Add hotel filter state
  String _selectedCountry = 'All';
  String _selectedCity = 'All';
  double _minPrice = 0;
  double _maxPrice = 200;
  double _minRating = 0;
  String _hotelSearch = '';
  String? _bookedHotelName;

  List<String> get _countries => ['All', ...{for (var h in hotels) h.country}];
  List<String> get _cities => ['All', ...{for (var h in hotels.where((h) => _selectedCountry == 'All' || h.country == _selectedCountry)) h.city}];

  @override
  Widget build(BuildContext context) {
    final filtered = _allPlaces.where((place) =>
      place.name.toLowerCase().contains(_search.toLowerCase()) ||
      place.location.toLowerCase().contains(_search.toLowerCase())
    ).toList();
    // Hotel filter UI
    final filteredHotels = hotels.where((hotel) {
      final countryMatch = _selectedCountry == 'All' || hotel.country == _selectedCountry;
      final cityMatch = _selectedCity == 'All' || hotel.city == _selectedCity;
      final priceMatch = hotel.price >= _minPrice && hotel.price <= _maxPrice;
      final ratingMatch = hotel.rating >= _minRating;
      final searchMatch = _hotelSearch.isEmpty ||
        hotel.name.toLowerCase().contains(_hotelSearch.toLowerCase()) ||
        hotel.city.toLowerCase().contains(_hotelSearch.toLowerCase()) ||
        hotel.country.toLowerCase().contains(_hotelSearch.toLowerCase());
      return countryMatch && cityMatch && priceMatch && ratingMatch && searchMatch;
    }).toList();
    return Column(
      children: [
        // Hotel Search Box
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Search hotels',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _hotelSearch = value),
          ),
        ),
        // Hotel Filters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            children: [
              DropdownButton<String>(
                value: _selectedCountry,
                items: _countries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() {
                  _selectedCountry = v!;
                  _selectedCity = 'All';
                }),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _selectedCity,
                items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _selectedCity = v!),
              ),
              const SizedBox(width: 8),
              Text('Price:'),
              SizedBox(
                width: 80,
                child: Slider(
                  value: _minPrice,
                  min: 0,
                  max: 200,
                  divisions: 20,
                  label: '${_minPrice.round()}',
                  onChanged: (v) => setState(() => _minPrice = v),
                ),
              ),
              Text('to'),
              SizedBox(
                width: 80,
                child: Slider(
                  value: _maxPrice,
                  min: 0,
                  max: 200,
                  divisions: 20,
                  label: '${_maxPrice.round()}',
                  onChanged: (v) => setState(() => _maxPrice = v),
                ),
              ),
              const SizedBox(width: 8),
              Text('Min Rating:'),
              SizedBox(
                width: 60,
                child: Slider(
                  value: _minRating,
                  min: 0,
                  max: 5,
                  divisions: 10,
                  label: _minRating.toStringAsFixed(1),
                  onChanged: (v) => setState(() => _minRating = v),
                ),
              ),
            ],
          ),
        ),
        // Hotel List (clickable)
        Expanded(
          child: ListView.builder(
            itemCount: filteredHotels.length,
            itemBuilder: (context, index) {
              final hotel = filteredHotels[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      hotel.imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[300],
                        child: const Icon(Icons.hotel, color: Colors.teal),
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(hotel.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                      if (_bookedHotelName == hotel.name) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Booked', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${hotel.city}, ${hotel.country}'),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 16),
                          Text('${hotel.rating}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Text('(${hotel.reviewCount} reviews)'),
                        ],
                      ),
                      Text('Price: ${hotel.price}'),
                      Wrap(
                        spacing: 6,
                        children: hotel.facilities.map((f) => Chip(label: Text(f), backgroundColor: Colors.teal.shade50)).toList(),
                      ),
                    ],
                  ),
                  onTap: () => showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(hotel.name),
                      content: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                hotel.imageUrl,
                                width: 250,
                                height: 150,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 250,
                                  height: 150,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.hotel, color: Colors.teal),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text('City: ${hotel.city}'),
                            Text('Country: ${hotel.country}'),
                            Text('Price: ${hotel.price}'),
                            Row(
                              children: [
                                Icon(Icons.star, color: Colors.amber, size: 16),
                                Text('${hotel.rating}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                Text('(${hotel.reviewCount} reviews)'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              children: hotel.facilities.map((f) => Chip(label: Text(f), backgroundColor: Colors.teal.shade50)).toList(),
                            ),
                            const SizedBox(height: 12),
                            const Text('Reviews:', style: TextStyle(fontWeight: FontWeight.bold)),
                            ...hotel.reviews.map<Widget>((review) => ListTile(
                              leading: Icon(Icons.person, color: Colors.teal),
                              title: Text(review['user']),
                              subtitle: Row(
                                children: [
                                  ...List.generate(5, (i) => Icon(
                                    i < review['rating'] ? Icons.star : Icons.star_border,
                                    color: Colors.amber,
                                    size: 14,
                                  )),
                                  const SizedBox(width: 8),
                                  Text(review['comment']),
                                ],
                              ),
                            )),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                        ElevatedButton(
                  onPressed: () {
                            Navigator.of(context).pop();
                            // Show booking confirmation or form
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Book Now'),
                                content: Text('Booking for ${hotel.name}...'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: const Text('Book Now'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showPlaceDetails(Place place) async {
    // Get route information using coordinates if available
    Map<String, dynamic>? routeInfo;
    
    if (place.latitude != null && place.longitude != null) {
      try {
        Position? currentPosition = await RouteService.getCurrentLocation();
        if (currentPosition != null) {
          final distance = Geolocator.distanceBetween(
            currentPosition.latitude,
            currentPosition.longitude,
            place.latitude!,
            place.longitude!,
          );
          
          final estimatedTimeMinutes = (distance / 50000 * 60).round();
          
          routeInfo = {
            'distance': distance,
            'estimatedTime': estimatedTimeMinutes,
            'currentLocation': {
              'latitude': currentPosition.latitude,
              'longitude': currentPosition.longitude,
            },
            'destination': {
              'latitude': place.latitude,
              'longitude': place.longitude,
            },
          };
        }
      } catch (e) {
        print('Error calculating route: $e');
      }
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(place.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(place.description),
            const SizedBox(height: 8),
            Text('Location: ${place.location}'),
            if (routeInfo != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.route, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Route Information',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Distance: ${(routeInfo['distance'] / 1000).toStringAsFixed(1)} km'),
                    Text('Estimated Time: ${routeInfo['estimatedTime']} minutes'),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (routeInfo != null) ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.map),
              label: const Text('View Map'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _showRouteMap(place, routeInfo!);
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.navigation),
              label: const Text('Navigate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                await RouteService.openRouteInMaps(place.location);
              },
            ),
          ],
          if (widget.trips.isNotEmpty)
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await showDialog(
                  context: context,
                  builder: (context) => AddPlaceToTripDialog(
                    place: place,
                    trips: widget.trips,
                  ),
                );
                setState(() {}); // Refresh UI if needed
              },
              child: const Text('Add to Trip'),
            ),
        ],
      ),
    );
  }

  void _showRouteMap(Place place, Map<String, dynamic> routeInfo) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 400,
          height: 500,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.map, color: Colors.white, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Route to ${place.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              // Map
              Expanded(
                child: SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleMap(Place place, Map<String, dynamic>? routeInfo) {
    if (place.latitude == null || place.longitude == null) {
      return const Center(child: Text('Map not available for this location'));
    }

    final destLatLng = LatLng(place.latitude!, place.longitude!);
    
    // If we have route info, show both current location and destination
    if (routeInfo != null && routeInfo['currentLocation'] != null) {
      final currentLatLng = LatLng(
        routeInfo['currentLocation']['latitude'],
        routeInfo['currentLocation']['longitude'],
      );
      
      // Debug prints to check coordinates
      print('Current Location: ${currentLatLng.latitude}, ${currentLatLng.longitude}');
      print('Destination: ${destLatLng.latitude}, ${destLatLng.longitude}');
      
      // Calculate map center with better logic
      final mapCenter = LatLng(
        (currentLatLng.latitude + destLatLng.latitude) / 2,
        (currentLatLng.longitude + destLatLng.longitude) / 2,
      );
      
      print('Map Center: ${mapCenter.latitude}, ${mapCenter.longitude}');
      
      // Calculate appropriate zoom level based on distance
      final distance = Geolocator.distanceBetween(
        currentLatLng.latitude,
        currentLatLng.longitude,
        destLatLng.latitude,
        destLatLng.longitude,
      );
      
      double zoomLevel = 10.0;
      if (distance < 1000) { // Less than 1km
        zoomLevel = 15.0;
      } else if (distance < 10000) { // Less than 10km
        zoomLevel = 12.0;
      } else if (distance < 100000) { // Less than 100km
        zoomLevel = 8.0;
      } else { // More than 100km
        zoomLevel = 5.0;
      }
      
      print('Distance: ${(distance / 1000).toStringAsFixed(1)} km, Zoom: $zoomLevel');

      return Column(
        children: [
          // Debug info panel (remove in production)
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey.shade100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('From: ${currentLatLng.latitude.toStringAsFixed(4)}, ${currentLatLng.longitude.toStringAsFixed(4)}'),
                Text('To: ${destLatLng.latitude.toStringAsFixed(4)}, ${destLatLng.longitude.toStringAsFixed(4)}'),
                Text('Distance: ${(distance / 1000).toStringAsFixed(1)} km'),
              ],
            ),
          ),
          
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: mapCenter,
                initialZoom: zoomLevel,
                minZoom: 3.0,
                maxZoom: 18.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.tripify',
                ),
                
                // Current location marker
                MarkerLayer(markers: [
                  Marker(
                    point: currentLatLng,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.my_location, color: Colors.white, size: 20),
                    ),
                  ),
                ]),
                
                // Destination marker
                MarkerLayer(markers: [
                  Marker(
                    point: destLatLng,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.place, color: Colors.white, size: 20),
                    ),
                  ),
                ]),
                
                // Route line
                PolylineLayer(polylines: [
                  Polyline(
                    points: [currentLatLng, destLatLng],
                    strokeWidth: 4,
                    color: Colors.blue,
                  ),
                ]),
              ],
            ),
          ),
        ],
      );
    } else {
      // Fallback: show only destination
      print('Showing only destination: ${destLatLng.latitude}, ${destLatLng.longitude}');
      
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.orange.shade100,
            child: const Text(
              'Current location not available. Showing destination only.',
              style: TextStyle(color: Colors.orange),
            ),
          ),
          
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: destLatLng,
                initialZoom: 12.0,
                minZoom: 3.0,
                maxZoom: 18.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.tripify',
                ),
                
                // Destination marker only
                MarkerLayer(markers: [
                  Marker(
                    point: destLatLng,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.place, color: Colors.white, size: 20),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      );
    }
  }
}

class AddPlaceToTripDialog extends StatefulWidget {
  final Place place;
  final List<Trip> trips;
  const AddPlaceToTripDialog({super.key, required this.place, required this.trips});

  @override
  State<AddPlaceToTripDialog> createState() => _AddPlaceToTripDialogState();
}

class _AddPlaceToTripDialogState extends State<AddPlaceToTripDialog> {
  Trip? _selectedTrip;
  String _type = 'Attraction';
  DateTime? _date;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Place to Trip'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<Trip>(
            value: _selectedTrip,
            items: widget.trips
                .map((trip) => DropdownMenuItem(
                      value: trip,
                      child: Text(trip.destination),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _selectedTrip = value),
            decoration: const InputDecoration(labelText: 'Select Trip'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _type,
            items: const [
              DropdownMenuItem(value: 'Attraction', child: Text('Attraction')),
              DropdownMenuItem(value: 'Activity', child: Text('Activity')),
              DropdownMenuItem(value: 'Accommodation', child: Text('Accommodation')),
            ],
            onChanged: (value) => setState(() => _type = value ?? 'Attraction'),
            decoration: const InputDecoration(labelText: 'Type'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(_date == null ? 'Date (optional)' : _date!.toString().split(' ')[0]),
              ),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => _date = picked);
                  }
                },
                child: const Text('Pick'),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedTrip == null
              ? null
              : () {
                  _selectedTrip!.itinerary.add(ItineraryItem(
                    title: widget.place.name,
                    type: _type,
                    description: widget.place.description,
                    dateTime: _date,
                    place: widget.place,
                  ));
                  Navigator.of(context).pop();
                },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _WriteReviewDialog extends StatefulWidget {
  @override
  State<_WriteReviewDialog> createState() => _WriteReviewDialogState();
}

class _WriteReviewDialogState extends State<_WriteReviewDialog> {
  final _formKey = GlobalKey<FormState>();
  String _user = '';
  int _rating = 5;
  String _comment = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Write a Review'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              decoration: const InputDecoration(labelText: 'Your Name'),
              validator: (v) => v == null || v.isEmpty ? 'Enter your name' : null,
              onSaved: (v) => _user = v ?? '',
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              value: _rating,
              items: List.generate(5, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1} Star${i == 0 ? '' : 's'}'))),
              onChanged: (v) => setState(() => _rating = v ?? 5),
              decoration: const InputDecoration(labelText: 'Rating'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Comment'),
              validator: (v) => v == null || v.isEmpty ? 'Enter a comment' : null,
              onSaved: (v) => _comment = v ?? '',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              Navigator.of(context).pop({'user': _user, 'rating': _rating, 'comment': _comment});
            }
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

// Hotel Details Page
class HotelDetailsPage extends StatelessWidget {
  final Map<String, dynamic> hotel;
  
  const HotelDetailsPage({Key? key, required this.hotel}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(hotel['name'] ?? 'Hotel Details'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hotel Image
            if (hotel['image'] != null)
              Container(
                width: double.infinity,
                height: 250,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(hotel['image']),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                height: 250,
                color: Colors.grey[300],
                child: const Icon(
                  Icons.hotel,
                  size: 80,
                  color: Colors.grey,
                ),
              ),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hotel Name and Rating
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hotel['name'] ?? 'Hotel',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 20),
                          Text(
                            ' ${hotel['rating']?.toString() ?? '4.0'}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Location
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.grey[600], size: 16),
                      const SizedBox(width: 4),
                      Text(
                        hotel['location'] ?? 'Location not available',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Price
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.attach_money, color: Colors.teal[700], size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Price: ${hotel['price'] ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Amenities Section
                  const Text(
                    'Amenities',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _buildAmenityChip(Icons.wifi, 'Free WiFi'),
                      _buildAmenityChip(Icons.local_parking, 'Parking'),
                      _buildAmenityChip(Icons.fitness_center, 'Gym'),
                      _buildAmenityChip(Icons.pool, 'Pool'),
                      _buildAmenityChip(Icons.restaurant, 'Restaurant'),
                      _buildAmenityChip(Icons.room_service, 'Room Service'),
                      _buildAmenityChip(Icons.ac_unit, 'Air Conditioning'),
                      _buildAmenityChip(Icons.tv, 'TV'),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Description
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Experience luxury and comfort at ${hotel['name'] ?? 'this hotel'}. Located in the heart of ${hotel['location'] ?? 'the city'}, our hotel offers world-class amenities and exceptional service to make your stay memorable.',
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Reviews Section
                  const Text(
                    'Guest Reviews',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildReviewCard('John D.', 5, 'Excellent service and clean rooms!'),
                  _buildReviewCard('Sarah M.', 4, 'Great location and friendly staff.'),
                  _buildReviewCard('Mike R.', 5, 'Perfect for business trips.'),
                  
                  const SizedBox(height: 24),
                  
                  // Booking Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _showBookingDialog(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Book Now',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Contact Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        _showContactDialog(context);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.teal,
                        side: const BorderSide(color: Colors.teal),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Contact Hotel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAmenityChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.teal[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.teal[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.teal[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.teal[700],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildReviewCard(String name, int rating, String comment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 16,
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              comment,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showBookingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Book Hotel'),
        content: const Text('This would open a booking form or redirect to the hotel\'s booking system.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Booking request sent!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
  
  void _showContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Hotel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Contact Information:'),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.phone, size: 16),
                const SizedBox(width: 8),
                const Text('+1 (555) 123-4567'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.email, size: 16),
                const SizedBox(width: 8),
                const Text('info@hotel.com'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(hotel['location'] ?? 'Location not available'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// Interactive Map View Widget
class InteractiveMapView extends StatefulWidget {
  final List<Map<String, dynamic>> hotels;
  
  const InteractiveMapView({Key? key, required this.hotels}) : super(key: key);
  
  @override
  State<InteractiveMapView> createState() => _InteractiveMapViewState();
}

class _InteractiveMapViewState extends State<InteractiveMapView> {
  MapController mapController = MapController();
  List<Marker> markers = [];
  
  // Default center (Paris)
  static const LatLng _center = LatLng(48.8584, 2.2945);
  
  @override
  void initState() {
    super.initState();
    _createMarkers();
  }
  
  void _createMarkers() {
    markers.clear();
    
    // Create markers for each hotel with better distribution
    for (int i = 0; i < widget.hotels.length; i++) {
      final hotel = widget.hotels[i];
      
      // Better coordinate distribution around Paris center
      // Create a more realistic spread of hotels around the city
      final angle = (i * 2 * 3.14159) / widget.hotels.length; // Distribute in a circle
      final radius = 0.02 + (i * 0.005); // Varying distances from center
      
      final lat = _center.latitude + (radius * cos(angle));
      final lng = _center.longitude + (radius * sin(angle));
      
      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 80,
          height: 80,
          child: GestureDetector(
            onTap: () => _showHotelInfo(hotel),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    hotel['name'] ?? 'Hotel',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
  
  void _showHotelInfo(Map<String, dynamic> hotel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(hotel['name'] ?? 'Hotel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Price: ${hotel['price']}'),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 16),
                Text(' ${hotel['rating']}'),
              ],
            ),
            const SizedBox(height: 8),
            Text('Location: ${hotel['location']}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HotelDetailsPage(hotel: hotel),
                  ),
                );
              },
              child: const Text('View Details'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: _center,
        initialZoom: 13.0,
        minZoom: 8.0,
        maxZoom: 18.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.tripify',
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }
}

class Hotel {
  final String name;
  final String city;
  final String country;
  final double price;
  final double rating;
  final String imageUrl;
  final int reviewCount;
  final List<String> facilities;
  final List<Map<String, dynamic>> reviews;
  final double latitude;
  final double longitude;
  Hotel({
    required this.name,
    required this.city,
    required this.country,
    required this.price,
    required this.rating,
    required this.imageUrl,
    required this.reviewCount,
    required this.facilities,
    required this.reviews,
    required this.latitude,
    required this.longitude,
  });
}

final List<Hotel> hotels = [
  // Bangladesh - Dhaka
  Hotel(
    name: "Hotel Paradise",
    city: "Dhaka",
    country: "Bangladesh",
    price: 80,
    rating: 4.5,
    imageUrl: hotelImages[Random("Hotel Paradise".hashCode).nextInt(hotelImages.length)],
    reviewCount: 120,
    facilities: ["Free WiFi", "Breakfast", "Pool", "Gym"],
    reviews: [
      {"user": "Amin", "rating": 5, "comment": "Great stay!"},
      {"user": "Sara", "rating": 4, "comment": "Clean and comfortable."},
    ],
    latitude: 23.8103,
    longitude: 90.4125,
  ),
  Hotel(
    name: "City Inn Express",
    city: "Dhaka",
    country: "Bangladesh",
    price: 35,
    rating: 3.9,
    imageUrl: hotelImages[Random("City Inn Express".hashCode).nextInt(hotelImages.length)],
    reviewCount: 45,
    facilities: ["Free WiFi", "Parking"],
    reviews: [
      {"user": "Rahim", "rating": 4, "comment": "Good value."},
    ],
    latitude: 23.8103,
    longitude: 90.4125,
  ),
  Hotel(
    name: "The Dhaka Heights",
    city: "Dhaka",
    country: "Bangladesh",
    price: 60,
    rating: 4.3,
    imageUrl: hotelImages[Random("The Dhaka Heights".hashCode).nextInt(hotelImages.length)],
    reviewCount: 80,
    facilities: ["Free WiFi", "Breakfast", "Restaurant"],
    reviews: [
      {"user": "Nadia", "rating": 4, "comment": "Nice view!"},
    ],
    latitude: 23.8103,
    longitude: 90.4125,
  ),
  // Bangladesh - Chittagong
  Hotel(
    name: "Sea Breeze Resort",
    city: "Chittagong",
    country: "Bangladesh",
    price: 65,
    rating: 4.2,
    imageUrl: hotelImages[Random("Sea Breeze Resort".hashCode).nextInt(hotelImages.length)],
    reviewCount: 70,
    facilities: ["Free WiFi", "Pool", "Sea View"],
    reviews: [
      {"user": "Jamal", "rating": 5, "comment": "Loved the sea breeze!"},
    ],
    latitude: 22.3569,
    longitude: 91.7832,
  ),
  Hotel(
    name: "Bayview Inn",
    city: "Chittagong",
    country: "Bangladesh",
    price: 55,
    rating: 4.1,
    imageUrl: hotelImages[Random("Bayview Inn".hashCode).nextInt(hotelImages.length)],
    reviewCount: 50,
    facilities: ["Free WiFi", "Parking"],
    reviews: [
      {"user": "Sadia", "rating": 4, "comment": "Great location."},
    ],
    latitude: 22.3569,
    longitude: 91.7832,
  ),
  Hotel(
    name: "Transit Inn",
    city: "Chittagong",
    country: "Bangladesh",
    price: 30,
    rating: 3.6,
    imageUrl: hotelImages[Random("Transit Inn".hashCode).nextInt(hotelImages.length)],
    reviewCount: 30,
    facilities: ["Free WiFi"],
    reviews: [
      {"user": "Rafiq", "rating": 3, "comment": "Basic but clean."},
    ],
    latitude: 22.3569,
    longitude: 91.7832,
  ),
  // Bangladesh - Sylhet
  Hotel(
    name: "GreenLeaf Sylhet",
    city: "Sylhet",
    country: "Bangladesh",
    price: 50,
    rating: 4.3,
    imageUrl: hotelImages[Random("GreenLeaf Sylhet".hashCode).nextInt(hotelImages.length)],
    reviewCount: 60,
    facilities: ["Free WiFi", "Breakfast", "Garden"],
    reviews: [
      {"user": "Imran", "rating": 5, "comment": "Very green!"},
    ],
    latitude: 24.8900,
    longitude: 91.8740,
  ),
  Hotel(
    name: "Tea Resort Inn",
    city: "Sylhet",
    country: "Bangladesh",
    price: 45,
    rating: 4.1,
    imageUrl: hotelImages[Random("Tea Resort Inn".hashCode).nextInt(hotelImages.length)],
    reviewCount: 40,
    facilities: ["Free WiFi", "Tea Garden"],
    reviews: [
      {"user": "Mita", "rating": 4, "comment": "Loved the tea garden!"},
    ],
    latitude: 24.8900,
    longitude: 91.8740,
  ),
  Hotel(
    name: "Sylhet Hill View",
    city: "Sylhet",
    country: "Bangladesh",
    price: 35,
    rating: 4.0,
    imageUrl: hotelImages[Random("Sylhet Hill View".hashCode).nextInt(hotelImages.length)],
    reviewCount: 35,
    facilities: ["Free WiFi", "Hill View"],
    reviews: [
      {"user": "Rashid", "rating": 4, "comment": "Nice hill view."},
    ],
    latitude: 24.8900,
    longitude: 91.8740,
  ),
  // Bangladesh - Cox's Bazar
  Hotel(
    name: "Ocean Pearl Resort",
    city: "Cox's Bazar",
    country: "Bangladesh",
    price: 70,
    rating: 4.6,
    imageUrl: hotelImages[Random("Ocean Pearl Resort".hashCode).nextInt(hotelImages.length)],
    reviewCount: 90,
    facilities: ["Free WiFi", "Pool", "Sea View"],
    reviews: [
      {"user": "Sami", "rating": 5, "comment": "Amazing ocean view!"},
    ],
    latitude: 21.4267,
    longitude: 91.9525,
  ),
  Hotel(
    name: "Cox's Comfort Inn",
    city: "Cox's Bazar",
    country: "Bangladesh",
    price: 40,
    rating: 3.9,
    imageUrl: hotelImages[Random("Cox's Comfort Inn".hashCode).nextInt(hotelImages.length)],
    reviewCount: 40,
    facilities: ["Free WiFi", "Parking"],
    reviews: [
      {"user": "Lina", "rating": 4, "comment": "Comfortable stay."},
    ],
    latitude: 21.4267,
    longitude: 91.9525,
  ),
  Hotel(
    name: "Seaside Escape Hotel",
    city: "Cox's Bazar",
    country: "Bangladesh",
    price: 55,
    rating: 4.2,
    imageUrl: hotelImages[Random("Seaside Escape Hotel".hashCode).nextInt(hotelImages.length)],
    reviewCount: 55,
    facilities: ["Free WiFi", "Sea View"],
    reviews: [
      {"user": "Noman", "rating": 4, "comment": "Close to the beach."},
    ],
    latitude: 21.4267,
    longitude: 91.9525,
  ),
  // Bangladesh - Rajshahi
  Hotel(
    name: "Padma Riverside Hotel",
    city: "Rajshahi",
    country: "Bangladesh",
    price: 42,
    rating: 4.0,
    imageUrl: hotelImages[Random("Padma Riverside Hotel".hashCode).nextInt(hotelImages.length)],
    reviewCount: 30,
    facilities: ["Free WiFi", "River View"],
    reviews: [
      {"user": "Rumi", "rating": 4, "comment": "Nice river view."},
    ],
    latitude: 24.3761,
    longitude: 88.6000,
  ),
  Hotel(
    name: "Rajshahi Grand Inn",
    city: "Rajshahi",
    country: "Bangladesh",
    price: 60,
    rating: 4.2,
    imageUrl: hotelImages[Random("Rajshahi Grand Inn".hashCode).nextInt(hotelImages.length)],
    reviewCount: 35,
    facilities: ["Free WiFi", "Breakfast"],
    reviews: [
      {"user": "Shuvo", "rating": 4, "comment": "Grand experience."},
    ],
    latitude: 24.3761,
    longitude: 88.6000,
  ),
  // Bangladesh - Barisal
  Hotel(
    name: "Southern Breeze Hotel",
    city: "Barisal",
    country: "Bangladesh",
    price: 35,
    rating: 3.8,
    imageUrl: hotelImages[Random("Southern Breeze Hotel".hashCode).nextInt(hotelImages.length)],
    reviewCount: 20,
    facilities: ["Free WiFi"],
    reviews: [
      {"user": "Tania", "rating": 4, "comment": "Good for the price."},
    ],
    latitude: 22.7000,
    longitude: 90.3667,
  ),
  Hotel(
    name: "Barisal Bay Inn",
    city: "Barisal",
    country: "Bangladesh",
    price: 48,
    rating: 4.1,
    imageUrl: hotelImages[Random("Barisal Bay Inn".hashCode).nextInt(hotelImages.length)],
    reviewCount: 22,
    facilities: ["Free WiFi", "Breakfast"],
    reviews: [
      {"user": "Rana", "rating": 4, "comment": "Nice breakfast."},
    ],
    latitude: 22.7000,
    longitude: 90.3667,
  ),
  // Bangladesh - Khulna
  Hotel(
    name: "Sundarban Stay",
    city: "Khulna",
    country: "Bangladesh",
    price: 55,
    rating: 4.3,
    imageUrl: hotelImages[Random("Sundarban Stay".hashCode).nextInt(hotelImages.length)],
    reviewCount: 28,
    facilities: ["Free WiFi", "Breakfast", "Nature"],
    reviews: [
      {"user": "Babul", "rating": 5, "comment": "Loved the Sundarbans!"},
    ],
    latitude: 22.8000,
    longitude: 89.5500,
  ),
  Hotel(
    name: "Khulna Comfort Inn",
    city: "Khulna",
    country: "Bangladesh",
    price: 38,
    rating: 3.9,
    imageUrl: hotelImages[Random("Khulna Comfort Inn".hashCode).nextInt(hotelImages.length)],
    reviewCount: 18,
    facilities: ["Free WiFi"],
    reviews: [
      {"user": "Mina", "rating": 4, "comment": "Comfortable stay."},
    ],
    latitude: 22.8000,
    longitude: 89.5500,
  ),
  // Nepal - Kathmandu
  Hotel(
    name: "Himalayan Retreat",
    city: "Kathmandu",
    country: "Nepal",
    price: 55,
    rating: 4.3,
    imageUrl: hotelImages[Random("Himalayan Retreat".hashCode).nextInt(hotelImages.length)],
    reviewCount: 60,
    facilities: ["Free WiFi", "Mountain View"],
    reviews: [
      {"user": "Kiran", "rating": 5, "comment": "Amazing mountain view!"},
    ],
    latitude: 27.7172,
    longitude: 85.3240,
  ),
  Hotel(
    name: "Namaste Boutique",
    city: "Kathmandu",
    country: "Nepal",
    price: 45,
    rating: 4.4,
    imageUrl: hotelImages[Random("Namaste Boutique".hashCode).nextInt(hotelImages.length)],
    reviewCount: 40,
    facilities: ["Free WiFi", "Breakfast"],
    reviews: [
      {"user": "Sita", "rating": 4, "comment": "Very friendly staff."},
    ],
    latitude: 27.7172,
    longitude: 85.3240,
  ),
  Hotel(
    name: "Stupa View Lodge",
    city: "Kathmandu",
    country: "Nepal",
    price: 30,
    rating: 4.1,
    imageUrl: hotelImages[Random("Stupa View Lodge".hashCode).nextInt(hotelImages.length)],
    reviewCount: 25,
    facilities: ["Free WiFi", "Stupa View"],
    reviews: [
      {"user": "Ram", "rating": 4, "comment": "Nice view of the stupa."},
    ],
    latitude: 27.7172,
    longitude: 85.3240,
  ),
  // Nepal - Pokhara
  Hotel(
    name: "Lakeside Lodge",
    city: "Pokhara",
    country: "Nepal",
    price: 50,
    rating: 4.1,
    imageUrl: hotelImages[Random("Lakeside Lodge".hashCode).nextInt(hotelImages.length)],
    reviewCount: 30,
    facilities: ["Free WiFi", "Lake View"],
    reviews: [
      {"user": "Bishal", "rating": 4, "comment": "Loved the lake view."},
    ],
    latitude: 28.2400,
    longitude: 83.9850,
  ),
  Hotel(
    name: "Cloud's End Hotel",
    city: "Pokhara",
    country: "Nepal",
    price: 60,
    rating: 4.5,
    imageUrl: hotelImages[Random("Cloud's End Hotel".hashCode).nextInt(hotelImages.length)],
    reviewCount: 35,
    facilities: ["Free WiFi", "Breakfast"],
    reviews: [
      {"user": "Anil", "rating": 5, "comment": "Great breakfast!"},
    ],
    latitude: 28.2400,
    longitude: 83.9850,
  ),
  Hotel(
    name: "Trekkers' Rest Inn",
    city: "Pokhara",
    country: "Nepal",
    price: 22,
    rating: 3.9,
    imageUrl: hotelImages[Random("Trekkers' Rest Inn".hashCode).nextInt(hotelImages.length)],
    reviewCount: 15,
    facilities: ["Free WiFi"],
    reviews: [
      {"user": "Manish", "rating": 4, "comment": "Good for trekkers."},
    ],
    latitude: 28.2400,
    longitude: 83.9850,
  ),
  // Nepal - Bhaktapur
  Hotel(
    name: "Durbar Heritage Hotel",
    city: "Bhaktapur",
    country: "Nepal",
    price: 40,
    rating: 4.2,
    imageUrl: hotelImages[Random("Durbar Heritage Hotel".hashCode).nextInt(hotelImages.length)],
    reviewCount: 18,
    facilities: ["Free WiFi", "Breakfast"],
    reviews: [
      {"user": "Rupa", "rating": 4, "comment": "Heritage feel."},
    ],
    latitude: 27.6869,
    longitude: 85.3190,
  ),
  Hotel(
    name: "Bhaktapur Inn",
    city: "Bhaktapur",
    country: "Nepal",
    price: 30,
    rating: 3.8,
    imageUrl: hotelImages[Random("Bhaktapur Inn".hashCode).nextInt(hotelImages.length)],
    reviewCount: 10,
    facilities: ["Free WiFi"],
    reviews: [
      {"user": "Suresh", "rating": 4, "comment": "Simple and clean."},
    ],
    latitude: 27.6869,
    longitude: 85.3190,
  ),
  // Nepal - Lumbini
  Hotel(
    name: "Lumbini Garden Resort",
    city: "Lumbini",
    country: "Nepal",
    price: 45,
    rating: 4.3,
    imageUrl: hotelImages[Random("Lumbini Garden Resort".hashCode).nextInt(hotelImages.length)],
    reviewCount: 20,
    facilities: ["Free WiFi", "Garden"],
    reviews: [
      {"user": "Nabin", "rating": 5, "comment": "Peaceful garden."},
    ],
    latitude: 27.6869,
    longitude: 84.5600,
  ),
  Hotel(
    name: "Maya Boutique Hotel",
    city: "Lumbini",
    country: "Nepal",
    price: 38,
    rating: 4.2,
    imageUrl: hotelImages[Random("Maya Boutique Hotel".hashCode).nextInt(hotelImages.length)],
    reviewCount: 15,
    facilities: ["Free WiFi", "Breakfast"],
    reviews: [
      {"user": "Maya", "rating": 4, "comment": "Nice boutique hotel."},
    ],
    latitude: 27.6869,
    longitude: 84.5600,
  ),
  // Nepal - Chitwan
  Hotel(
    name: "Jungle Safari Lodge",
    city: "Chitwan",
    country: "Nepal",
    price: 55,
    rating: 4.4,
    imageUrl: hotelImages[Random("Jungle Safari Lodge".hashCode).nextInt(hotelImages.length)],
    reviewCount: 22,
    facilities: ["Free WiFi", "Safari"],
    reviews: [
      {"user": "Deepak", "rating": 5, "comment": "Great safari experience."},
    ],
    latitude: 27.6869,
    longitude: 84.5600,
  ),
  Hotel(
    name: "Chitwan Riverside Hotel",
    city: "Chitwan",
    country: "Nepal",
    price: 48,
    rating: 4.1,
    imageUrl: hotelImages[Random("Chitwan Riverside Hotel".hashCode).nextInt(hotelImages.length)],
    reviewCount: 18,
    facilities: ["Free WiFi", "River View"],
    reviews: [
      {"user": "Sunita", "rating": 4, "comment": "Nice river view."},
    ],
    latitude: 27.6869,
    longitude: 84.5600,
  ),
  // Nepal - Nagarkot
  Hotel(
    name: "Mountain View Resort",
    city: "Nagarkot",
    country: "Nepal",
    price: 60,
    rating: 4.5,
    imageUrl: hotelImages[Random("Mountain View Resort".hashCode).nextInt(hotelImages.length)],
    reviewCount: 25,
    facilities: ["Free WiFi", "Mountain View"],
    reviews: [
      {"user": "Ramesh", "rating": 5, "comment": "Amazing mountain view!"},
    ],
    latitude: 27.7172,
    longitude: 85.5200,
  ),
  Hotel(
    name: "Nagarkot Panorama Inn",
    city: "Nagarkot",
    country: "Nepal",
    price: 42,
    rating: 4.0,
    imageUrl: hotelImages[Random("Nagarkot Panorama Inn".hashCode).nextInt(hotelImages.length)],
    reviewCount: 12,
    facilities: ["Free WiFi"],
    reviews: [
      {"user": "Kishor", "rating": 4, "comment": "Nice panorama."},
    ],
    latitude: 27.7172,
    longitude: 85.5200,
  ),
  // Nepal - Dharan
  Hotel(
    name: "Eastern Gateway Hotel",
    city: "Dharan",
    country: "Nepal",
    price: 35,
    rating: 3.8,
    imageUrl: hotelImages[Random("Eastern Gateway Hotel".hashCode).nextInt(hotelImages.length)],
    reviewCount: 10,
    facilities: ["Free WiFi"],
    reviews: [
      {"user": "Raju", "rating": 4, "comment": "Good for a stopover."},
    ],
    latitude: 26.8121,
    longitude: 87.2832,
  ),
  Hotel(
    name: "Hotel Dharan Deluxe",
    city: "Dharan",
    country: "Nepal",
    price: 50,
    rating: 4.2,
    imageUrl: hotelImages[Random("Hotel Dharan Deluxe".hashCode).nextInt(hotelImages.length)],
    reviewCount: 14,
    facilities: ["Free WiFi", "Breakfast"],
    reviews: [
      {"user": "Suman", "rating": 4, "comment": "Deluxe experience."},
    ],
    latitude: 26.8121,
    longitude: 87.2832,
  ),
  // India - Delhi
  Hotel(
    name: "Capital Grand Hotel",
    city: "Delhi",
    country: "India",
    price: 100,
    rating: 4.6,
    imageUrl: hotelImages[Random("Capital Grand Hotel".hashCode).nextInt(hotelImages.length)],
    reviewCount: 100,
    facilities: ["Free WiFi", "Breakfast", "Gym"],
    reviews: [
      {"user": "Ankit", "rating": 5, "comment": "Grand experience!"},
    ],
    latitude: 28.6139,
    longitude: 77.2090,
  ),
  Hotel(
    name: "MetroPoint Hotel",
    city: "Delhi",
    country: "India",
    price: 38,
    rating: 3.9,
    imageUrl: hotelImages[Random("MetroPoint Hotel".hashCode).nextInt(hotelImages.length)],
    reviewCount: 40,
    facilities: ["Free WiFi", "Parking"],
    reviews: [
      {"user": "Priya", "rating": 4, "comment": "Close to metro."},
    ],
    latitude: 28.6139,
    longitude: 77.2090,
  ),
  Hotel(
    name: "Heritage Haveli Inn",
    city: "Delhi",
    country: "India",
    price: 45,
    rating: 4.2,
    imageUrl: hotelImages[Random("Heritage Haveli Inn".hashCode).nextInt(hotelImages.length)],
    reviewCount: 30,
    facilities: ["Free WiFi", "Heritage"],
    reviews: [
      {"user": "Rohit", "rating": 4, "comment": "Heritage feel."},
    ],
    latitude: 28.6139,
    longitude: 77.2090,
  ),
  // India - Mumbai
  Hotel(
    name: "Marine Bay Residency",
    city: "Mumbai",
    country: "India",
    price: 120,
    rating: 4.7,
    imageUrl: hotelImages[Random("Marine Bay Residency".hashCode).nextInt(hotelImages.length)],
    reviewCount: 110,
    facilities: ["Free WiFi", "Sea View"],
    reviews: [
      {"user": "Neha", "rating": 5, "comment": "Amazing sea view!"},
    ],
    latitude: 19.0760,
    longitude: 72.8777,
  ),
  Hotel(
    name: "Bollywood Stay Inn",
    city: "Mumbai",
    country: "India",
    price: 60,
    rating: 4.0,
    imageUrl: hotelImages[Random("Bollywood Stay Inn".hashCode).nextInt(hotelImages.length)],
    reviewCount: 50,
    facilities: ["Free WiFi", "Breakfast"],
    reviews: [
      {"user": "Amit", "rating": 4, "comment": "Bollywood vibes!"},
    ],
    latitude: 19.0760,
    longitude: 72.8777,
  ),
  Hotel(
    name: "Suburban Suites",
    city: "Mumbai",
    country: "India",
    price: 35,
    rating: 3.8,
    imageUrl: hotelImages[Random("Suburban Suites".hashCode).nextInt(hotelImages.length)],
    reviewCount: 20,
    facilities: ["Free WiFi"],
    reviews: [
      {"user": "Rina", "rating": 4, "comment": "Good for business."},
    ],
    latitude: 19.0760,
    longitude: 72.8777,
  ),
  // India - Bangalore
  Hotel(
    name: "TechTown Suites",
    city: "Bangalore",
    country: "India",
    price: 75,
    rating: 4.3,
    imageUrl: hotelImages[Random("TechTown Suites".hashCode).nextInt(hotelImages.length)],
    reviewCount: 60,
    facilities: ["Free WiFi", "Breakfast", "Gym"],
    reviews: [
      {"user": "Vikas", "rating": 5, "comment": "Great for techies!"},
    ],
    latitude: 12.9716,
    longitude: 77.5946,
  ),
  Hotel(
    name: "Budget Nest Bengaluru",
    city: "Bangalore",
    country: "India",
    price: 28,
    rating: 3.7,
    imageUrl: hotelImages[Random("Budget Nest Bengaluru".hashCode).nextInt(hotelImages.length)],
    reviewCount: 18,
    facilities: ["Free WiFi"],
    reviews: [
      {"user": "Meena", "rating": 4, "comment": "Budget friendly."},
    ],
    latitude: 12.9716,
    longitude: 77.5946,
  ),
  // India - Jaipur
  Hotel(
    name: "Pink Palace Hotel",
    city: "Jaipur",
    country: "India",
    price: 50,
    rating: 4.2,
    imageUrl: hotelImages[Random("Pink Palace Hotel".hashCode).nextInt(hotelImages.length)],
    reviewCount: 30,
    facilities: ["Free WiFi", "Breakfast"],
    reviews: [
      {"user": "Pooja", "rating": 4, "comment": "Loved the pink theme!"},
    ],
    latitude: 26.9124,
    longitude: 75.7873,
  ),
  Hotel(
    name: "Royal Haveli Stay",
    city: "Jaipur",
    country: "India",
    price: 70,
    rating: 4.5,
    imageUrl: hotelImages[Random("Royal Haveli Stay".hashCode).nextInt(hotelImages.length)],
    reviewCount: 40,
    facilities: ["Free WiFi", "Heritage"],
    reviews: [
      {"user": "Raj", "rating": 5, "comment": "Royal experience!"},
    ],
    latitude: 26.9124,
    longitude: 75.7873,
  ),
  // India - Kochi
  Hotel(
    name: "Backwater Bliss Hotel",
    city: "Kochi",
    country: "India",
    price: 65,
    rating: 4.3,
    imageUrl: hotelImages[Random("Backwater Bliss Hotel".hashCode).nextInt(hotelImages.length)],
    reviewCount: 28,
    facilities: ["Free WiFi", "Backwater View"],
    reviews: [
      {"user": "Anu", "rating": 5, "comment": "Loved the backwaters!"},
    ],
    latitude: 9.9312,
    longitude: 76.2673,
  ),
  Hotel(
    name: "Fort Kochi Residency",
    city: "Kochi",
    country: "India",
    price: 50,
    rating: 4.2,
    imageUrl: hotelImages[Random("Fort Kochi Residency".hashCode).nextInt(hotelImages.length)],
    reviewCount: 22,
    facilities: ["Free WiFi", "Breakfast"],
    reviews: [
      {"user": "Suresh", "rating": 4, "comment": "Nice residency."},
    ],
    latitude: 9.9312,
    longitude: 76.2673,
  ),
  // India - Hyderabad
  Hotel(
    name: "Pearl City Hotel",
    city: "Hyderabad",
    country: "India",
    price: 58,
    rating: 4.2,
    imageUrl: hotelImages[Random("Pearl City Hotel".hashCode).nextInt(hotelImages.length)],
    reviewCount: 30,
    facilities: ["Free WiFi", "Breakfast"],
    reviews: [
      {"user": "Farhan", "rating": 4, "comment": "Pearl city vibes!"},
    ],
    latitude: 17.3850,
    longitude: 78.4867,
  ),
  Hotel(
    name: "Hyderabad Heights",
    city: "Hyderabad",
    country: "India",
    price: 85,
    rating: 4.4,
    imageUrl: hotelImages[Random("Hyderabad Heights".hashCode).nextInt(hotelImages.length)],
    reviewCount: 35,
    facilities: ["Free WiFi", "Gym"],
    reviews: [
      {"user": "Ayesha", "rating": 5, "comment": "Great gym!"},
    ],
    latitude: 17.3850,
    longitude: 78.4867,
  ),
  // India - Chennai
  Hotel(
    name: "Marina View Hotel",
    city: "Chennai",
    country: "India",
    price: 60,
    rating: 4.1,
    imageUrl: hotelImages[Random("Marina View Hotel".hashCode).nextInt(hotelImages.length)],
    reviewCount: 20,
    facilities: ["Free WiFi", "Sea View"],
    reviews: [
      {"user": "Karthik", "rating": 4, "comment": "Nice marina view."},
    ],
    latitude: 13.0827,
    longitude: 80.2707,
  ),
  Hotel(
    name: "Southern Stay Inn",
    city: "Chennai",
    country: "India",
    price: 38,
    rating: 3.9,
    imageUrl: hotelImages[Random("Southern Stay Inn".hashCode).nextInt(hotelImages.length)],
    reviewCount: 12,
    facilities: ["Free WiFi"],
    reviews: [
      {"user": "Lakshmi", "rating": 4, "comment": "Good value."},
    ],
    latitude: 13.0827,
    longitude: 80.2707,
  ),
  // India - Goa
  Hotel(
    name: "Goa Sands Resort",
    city: "Goa",
    country: "India",
    price: 70,
    rating: 4.5,
    imageUrl: hotelImages[Random("Goa Sands Resort".hashCode).nextInt(hotelImages.length)],
    reviewCount: 40,
    facilities: ["Free WiFi", "Beach Access"],
    reviews: [
      {"user": "Ravi", "rating": 5, "comment": "Loved the beach!"},
    ],
    latitude: 15.2993,
    longitude: 74.1240,
  ),
  Hotel(
    name: "Palm Grove Guesthouse",
    city: "Goa",
    country: "India",
    price: 45,
    rating: 4.0,
    imageUrl: hotelImages[Random("Palm Grove Guesthouse".hashCode).nextInt(hotelImages.length)],
    reviewCount: 18,
    facilities: ["Free WiFi", "Garden"],
    reviews: [
      {"user": "Sonia", "rating": 4, "comment": "Nice garden."},
    ],
    latitude: 15.2993,
    longitude: 74.1240,
  ),
  // India - Kolkata
  Hotel(
    name: "Victoria View Hotel",
    city: "Kolkata",
    country: "India",
    price: 55,
    rating: 4.2,
    imageUrl: hotelImages[Random("Victoria View Hotel".hashCode).nextInt(hotelImages.length)],
    reviewCount: 22,
    facilities: ["Free WiFi", "Breakfast"],
    reviews: [
      {"user": "Arjun", "rating": 4, "comment": "Great view of Victoria!"},
    ],
    latitude: 22.5726,
    longitude: 88.3639,
  ),
  Hotel(
    name: "Kolkata Comfort Suites",
    city: "Kolkata",
    country: "India",
    price: 42,
    rating: 4.0,
    imageUrl: hotelImages[Random("Kolkata Comfort Suites".hashCode).nextInt(hotelImages.length)],
    reviewCount: 15,
    facilities: ["Free WiFi"],
    reviews: [
      {"user": "Rupa", "rating": 4, "comment": "Comfortable stay."},
    ],
    latitude: 22.5726,
    longitude: 88.3639,
  ),
  // India - Shimla
  Hotel(
    name: "Himalayan Hilltop Hotel",
    city: "Shimla",
    country: "India",
    price: 65,
    rating: 4.4,
    imageUrl: hotelImages[Random("Himalayan Hilltop Hotel".hashCode).nextInt(hotelImages.length)],
    reviewCount: 28,
    facilities: ["Free WiFi", "Mountain View"],
    reviews: [
      {"user": "Simran", "rating": 5, "comment": "Amazing hilltop view!"},
    ],
    latitude: 31.1048,
    longitude: 77.1734,
  ),
  Hotel(
    name: "Snowline Retreat",
    city: "Shimla",
    country: "India",
    price: 50,
    rating: 4.3,
    imageUrl: hotelImages[Random("Snowline Retreat".hashCode).nextInt(hotelImages.length)],
    reviewCount: 20,
    facilities: ["Free WiFi", "Snow View"],
    reviews: [
      {"user": "Rajeev", "rating": 5, "comment": "Loved the snow!"},
    ],
    latitude: 31.1048,
    longitude: 77.1734,
  ),
];

final List<String> hotelImages = [
  "https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=400&q=80",
  "https://images.unsplash.com/photo-1551882547-ff40c63fe5fa?auto=format&fit=crop&w=400&q=80",
  "https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?auto=format&fit=crop&w=400&q=80",
  "https://images.unsplash.com/photo-1578662996442-48f60103fc96?auto=format&fit=crop&w=400&q=80",
  "https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?auto=format&fit=crop&w=400&q=80",
  "https://images.unsplash.com/photo-1571896349842-33c89424de2d?auto=format&fit=crop&w=400&q=80",
  "https://images.unsplash.com/photo-1590490360182-c33d57733427?auto=format&fit=crop&w=400&q=80",
  "https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?auto=format&fit=crop&w=400&q=80",
  "https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=400&q=80",
  "https://images.unsplash.com/photo-1512918728675-ed5a9ecdebfd?auto=format&fit=crop&w=400&q=80",
  "https://images.unsplash.com/photo-1464983953574-0892a716854b?auto=format&fit=crop&w=400&q=80",
  "https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?auto=format&fit=crop&w=400&q=80",
  "https://images.unsplash.com/photo-1511746315387-c4a76980c9a2?auto=format&fit=crop&w=400&q=80",
  "https://images.unsplash.com/photo-1465156799763-2c087c332922?auto=format&fit=crop&w=400&q=80",
  "https://images.unsplash.com/photo-1515378791036-0648a3ef77b2?auto=format&fit=crop&w=400&q=80",
];
