import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/trip.dart';

class TripService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static Future<void> addTrip(Trip trip) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    await _firestore.collection('users').doc(user.uid).collection('trips').add(trip.toJson());
  }

  static Stream<List<Trip>> getUserTrips() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('trips')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Trip.fromJson(doc.data(), id: doc.id)).toList());
  }

  static Future<void> updateTrip(Trip trip) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    if (trip.id == null) throw Exception('Trip ID is null');
    await _firestore.collection('users').doc(user.uid).collection('trips').doc(trip.id).set(trip.toJson());
  }

  static Future<void> deleteTrip(String tripId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    await _firestore.collection('users').doc(user.uid).collection('trips').doc(tripId).delete();
  }
} 