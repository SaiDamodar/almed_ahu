class User {
  final String id;
  final String email;
  final String username;
  final String phoneNumber;
  final String hospitalName;
  final String? profileImageUrl;
  final UserStatus status;
  final List<String> assignedAhuIds;
  final DateTime createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.email,
    required this.username,
    required this.phoneNumber,
    required this.hospitalName,
    this.profileImageUrl,
    required this.status,
    required this.assignedAhuIds,
    required this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'] ?? '',
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      phoneNumber: json['phone_number'] ?? json['phoneNumber'] ?? '',
      hospitalName: json['hospital_name'] ?? json['hospitalName'] ?? '',
      profileImageUrl: json['profile_image_url'] ?? json['profileImageUrl'],
      status: userStatusFromString(json['status'] ?? 'pending'),
      assignedAhuIds: json['assigned_ahu_ids'] != null
          ? List<String>.from(json['assigned_ahu_ids'])
          : json['assignedAhuIds'] != null
              ? List<String>.from(json['assignedAhuIds'])
              : [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : json['createdAt'] != null
              ? DateTime.parse(json['createdAt'])
              : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : json['updatedAt'] != null
              ? DateTime.parse(json['updatedAt'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'phone_number': phoneNumber,
      'hospital_name': hospitalName,
      'profile_image_url': profileImageUrl,
      'status': status.value,
      'assigned_ahu_ids': assignedAhuIds,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

enum UserStatus {
  pending,      // Waiting for admin approval
  approved,     // Approved by admin, waiting for AHU assignment
  active,       // Has assigned AHUs, can use the app
  rejected,     // Registration rejected by admin
  suspended,    // Temporarily suspended
}

extension UserStatusExtension on UserStatus {
  String get value {
    switch (this) {
      case UserStatus.pending:
        return 'pending';
      case UserStatus.approved:
        return 'approved';
      case UserStatus.active:
        return 'active';
      case UserStatus.rejected:
        return 'rejected';
      case UserStatus.suspended:
        return 'suspended';
    }
  }

  String get displayMessage {
    switch (this) {
      case UserStatus.pending:
        return 'Waiting for verification';
      case UserStatus.approved:
        return 'Waiting for AHU assignment';
      case UserStatus.active:
        return 'Account active';
      case UserStatus.rejected:
        return 'Your request is rejected';
      case UserStatus.suspended:
        return 'Account suspended';
    }
  }
}

/// Helper function to parse UserStatus from string
UserStatus userStatusFromString(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return UserStatus.pending;
    case 'approved':
      return UserStatus.approved;
    case 'active':
      return UserStatus.active;
    case 'rejected':
      return UserStatus.rejected;
    case 'suspended':
      return UserStatus.suspended;
    default:
      return UserStatus.pending;
  }
}

