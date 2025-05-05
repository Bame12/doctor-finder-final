import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentModel {
  final String id;
  final String doctorId;
  final String doctorName;
  final String userId;
  final String userName;
  final String userEmail;
  final String date;
  final String fromTime;
  final String toTime;
  final String message;
  final String status;
  final DateTime createdAt;

  AppointmentModel({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.date,
    required this.fromTime,
    required this.toTime,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  factory AppointmentModel.fromMap(String id, Map<String, dynamic> map) {
    return AppointmentModel(
      id: id,
      doctorId: map['doctorId'] ?? '',
      doctorName: map['doctorName'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userEmail: map['userEmail'] ?? '',
      date: map['date'] is Timestamp
          ? (map['date'] as Timestamp).toDate().toString()
          : map['date'] ?? '',
      fromTime: map['fromTime'] ?? '',
      toTime: map['toTime'] ?? '',
      message: map['message'] ?? '',
      status: map['status'] ?? 'Scheduled',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}