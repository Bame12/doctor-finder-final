import 'package:cloud_firestore/cloud_firestore.dart';  // ADDED THIS IMPORT

class UserModel {
  final String id;
  final String? fullName;
  final String? firstName;
  final String? surname;
  final String email;
  final String? username;
  final String? contacts;
  final String? gender;
  final String? role;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    this.fullName,
    this.firstName,
    this.surname,
    required this.email,
    this.username,
    this.contacts,
    this.gender,
    this.role,
    this.createdAt,
  });

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    return UserModel(
      id: id,
      fullName: map['fullName'] ?? map['name'],
      firstName: map['firstName'],
      surname: map['surname'],
      email: map['email'] ?? '',
      username: map['username'],
      contacts: map['contacts'],
      gender: map['gender'],
      role: map['role'],
      createdAt: map['created_at'] != null
          ? (map['created_at'] as Timestamp).toDate()
          : null,
    );
  }
}