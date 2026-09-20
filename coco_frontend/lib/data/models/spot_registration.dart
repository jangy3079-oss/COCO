// 스팟 등록 신청 — coco_backend SpotRegistrationResponse 매핑.
import '../../core/utils/backend_datetime.dart';

class SpotRegistration {
  final int id;
  final String name;
  final String category;
  final String address;
  final double lat;
  final double lng;
  final String? description;
  final String status; // pending | approved | rejected
  final DateTime createdAt;

  const SpotRegistration({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.lat,
    required this.lng,
    this.description,
    required this.status,
    required this.createdAt,
  });

  factory SpotRegistration.fromJson(Map<String, dynamic> json) => SpotRegistration(
        id: json['id'] as int,
        name: json['name'] as String,
        category: json['category'] as String,
        address: json['address'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        description: json['description'] as String?,
        status: json['status'] as String,
        createdAt: parseBackendDateTime(json['createdAt'] as String),
      );
}
