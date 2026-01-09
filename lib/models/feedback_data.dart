class UserFeedback {
  final String username;
  final String content;
  final DateTime timestamp;

  final String? imagePath;
  final String city;
  final String district;
  final String ward;
  final String address;

  UserFeedback({
    required this.username,
    required this.content,
    required this.timestamp,
    this.imagePath,
    required this.city,
    required this.district,
    required this.ward,
    required this.address,
  });
}

List<UserFeedback> globalFeedbackList = [];