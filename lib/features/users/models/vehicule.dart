// lib/features/users/models/vehicle.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum VehicleType { car, motorcycle, other }

extension VehicleTypeExt on VehicleType {
  IconData get icon {
    switch (this) {
      case VehicleType.car:
        return Icons.directions_car_rounded;
      case VehicleType.motorcycle:
        return Icons.two_wheeler_rounded;
      case VehicleType.other:
        return Icons.commute_rounded;
    }
  }

  String get value {
    switch (this) {
      case VehicleType.car:
        return 'car';
      case VehicleType.motorcycle:
        return 'motorcycle';
      case VehicleType.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case VehicleType.car:
        return 'Carro';
      case VehicleType.motorcycle:
        return 'Moto';
      case VehicleType.other:
        return 'Otro';
    }
  }

  String get platePrefix {
    switch (this) {
      case VehicleType.car:
        return 'P';
      case VehicleType.motorcycle:
        return 'M';
      case VehicleType.other:
        return 'C';
    }
  }

  String get hint {
    switch (this) {
      case VehicleType.car:
        return 'Ej: 123ABC  →  P123ABC';
      case VehicleType.motorcycle:
        return 'Ej: 45XYZ   →  M45XYZ';
      case VehicleType.other:
        return 'Ej: 78QRS   →  C78QRS';
    }
  }
}

VehicleType vehicleTypeFromString(String? s) {
  switch (s) {
    case 'motorcycle':
      return VehicleType.motorcycle;
    case 'other':
      return VehicleType.other;
    default:
      return VehicleType.car;
  }
}

class Vehicle {
  final String id;
  final VehicleType type;
  final String plate; // full plate e.g. "P123ABC"
  final bool isPrimary;
  final DateTime createdAt;

  const Vehicle({
    required this.id,
    required this.type,
    required this.plate,
    this.isPrimary = false,
    required this.createdAt,
  });

  factory Vehicle.fromMap(String id, Map<String, dynamic> data) {
    return Vehicle(
      id: id,
      type: vehicleTypeFromString(data['type'] as String?),
      plate: (data['plate'] as String?) ?? '',
      isPrimary: (data['isPrimary'] as bool?) ?? false,
      createdAt:
          data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'type': type.value,
    'plate': plate,
    'isPrimary': isPrimary,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  Vehicle copyWith({bool? isPrimary}) => Vehicle(
    id: id,
    type: type,
    plate: plate,
    isPrimary: isPrimary ?? this.isPrimary,
    createdAt: createdAt,
  );
}
