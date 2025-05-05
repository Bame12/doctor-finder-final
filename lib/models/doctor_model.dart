class DoctorModel {
  final String id;
  final String name;
  final String? firstName;
  final String? surname;
  final String? email;
  final String? phone;
  final String? specialty;
  final String? services;
  final String? description;
  final String? location;
  final String? city;
  final String? address;
  final double? latitude;
  final double? longitude;
  final double? rating;
  final int? reviewCount;
  final List<String>? imageUrls;

  DoctorModel({
    required this.id,
    required this.name,
    this.firstName,
    this.surname,
    this.email,
    this.phone,
    this.specialty,
    this.services,
    this.description,
    this.location,
    this.city,
    this.address,
    this.latitude,
    this.longitude,
    this.rating,
    this.reviewCount,
    this.imageUrls,
  });

  factory DoctorModel.fromMap(String id, Map<String, dynamic> map) {
    return DoctorModel(
      id: id,
      name: map['name'] ?? map['fullName'] ?? map['doctorName'] ?? 'Unknown Doctor',
      firstName: map['firstName'],
      surname: map['surname'],
      email: map['email'],
      phone: map['contacts'] ?? map['phone'],
      specialty: map['specialty'] ?? map['specialization'] ?? map['profession'],
      services: map['services'],
      description: map['description'],
      location: map['location'],
      city: map['city'],
      address: map['address'],
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
      rating: map['rating'] != null ? (map['rating'] as num).toDouble() : null,
      reviewCount: map['reviewCount'],
      imageUrls: map['imageUrls'] is List ? List<String>.from(map['imageUrls']) : null,
    );
  }
}