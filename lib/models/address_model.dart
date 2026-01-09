class Province {
  final int code;
  final String name;

  Province({required this.code, required this.name});

  factory Province.fromJson(Map<String, dynamic> json) {
    return Province(code: json['code'], name: json['name']);
  }

  @override
  bool operator ==(Object other) => other is Province && other.code == code;
  @override
  int get hashCode => code.hashCode;
}

class District {
  final int code;
  final String name;

  District({required this.code, required this.name});

  factory District.fromJson(Map<String, dynamic> json) {
    return District(code: json['code'], name: json['name']);
  }

  @override
  bool operator ==(Object other) => other is District && other.code == code;
  @override
  int get hashCode => code.hashCode;
}

class Ward {
  final int code;
  final String name;

  Ward({required this.code, required this.name});

  factory Ward.fromJson(Map<String, dynamic> json) {
    return Ward(code: json['code'], name: json['name']);
  }

  @override
  bool operator ==(Object other) => other is Ward && other.code == code;
  @override
  int get hashCode => code.hashCode;
}