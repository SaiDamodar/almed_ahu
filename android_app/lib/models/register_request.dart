class RegisterRequest {
  final String email;
  final String username;
  final String phoneNumber;
  final String hospitalName;
  final String password;
  final String? googleId;
  final String? profileImageUrl;

  RegisterRequest({
    required this.email,
    required this.username,
    required this.phoneNumber,
    required this.hospitalName,
    required this.password,
    this.googleId,
    this.profileImageUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'username': username,
      'phone_number': phoneNumber,
      'hospital_name': hospitalName,
      'password': password,
      if (googleId != null) 'google_id': googleId,
      if (profileImageUrl != null) 'profile_image_url': profileImageUrl,
    };
  }
}

