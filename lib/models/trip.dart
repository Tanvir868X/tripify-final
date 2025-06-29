class Trip {
  String? id; // Firestore document ID
  String name;
  String from;
  String destination;
  DateTime startDate;
  DateTime endDate;
  double? budget;
  List<ItineraryItem> itinerary;
  String imagePath; // Local asset image path

  Trip({
    this.id,
    required this.name,
    required this.from,
    required this.destination,
    required this.startDate,
    required this.endDate,
    this.budget,
    required this.itinerary,
    required this.imagePath,
  });

  Trip copyWith({
    String? id,
    String? name,
    String? from,
    String? destination,
    DateTime? startDate,
    DateTime? endDate,
    double? budget,
    List<ItineraryItem>? itinerary,
    String? imagePath,
  }) {
    return Trip(
      id: id ?? this.id,
      name: name ?? this.name,
      from: from ?? this.from,
      destination: destination ?? this.destination,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      budget: budget ?? this.budget,
      itinerary: itinerary ?? this.itinerary,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'from': from,
    'destination': destination,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'budget': budget,
    'itinerary': itinerary.map((item) => item.toJson()).toList(),
    'imagePath': imagePath,
  };

  static Trip fromJson(Map<String, dynamic> json, {String? id}) => Trip(
    id: id,
    name: json['name'],
    from: json['from'],
    destination: json['destination'],
    startDate: DateTime.parse(json['startDate']),
    endDate: DateTime.parse(json['endDate']),
    budget: (json['budget'] as num?)?.toDouble(),
    itinerary: (json['itinerary'] as List<dynamic>? ?? []).map((item) => ItineraryItem.fromJson(item)).toList(),
    imagePath: json['imagePath'],
  );
}

class ItineraryItem {
  final String title;
  final String type; // e.g., 'Activity', 'Attraction', 'Accommodation'
  final String? description;
  final DateTime? dateTime;
  final Place? place;

  ItineraryItem({
    required this.title,
    required this.type,
    this.description,
    this.dateTime,
    this.place,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'type': type,
    'description': description,
    'dateTime': dateTime?.toIso8601String(),
    'place': place?.toJson(),
  };

  static ItineraryItem fromJson(Map<String, dynamic> json) => ItineraryItem(
    title: json['title'],
    type: json['type'],
    description: json['description'],
    dateTime: json['dateTime'] != null ? DateTime.parse(json['dateTime']) : null,
    place: json['place'] != null ? Place.fromJson(json['place']) : null,
  );
}

class Place {
  final String name;
  final String description;
  final String location;
  final String? imageUrl;
  final double? latitude;
  final double? longitude;

  Place({
    required this.name,
    required this.description,
    required this.location,
    this.imageUrl,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'location': location,
    'imageUrl': imageUrl,
    'latitude': latitude,
    'longitude': longitude,
  };

  static Place fromJson(Map<String, dynamic> json) => Place(
    name: json['name'],
    description: json['description'],
    location: json['location'],
    imageUrl: json['imageUrl'],
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
  );
} 