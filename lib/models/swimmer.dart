class Swimmer {
  final int? id;
  final String firstName;
  final String surname;
  final String? photoPath;
  final DateTime dob;
  final String nationality;
  final String? club;
  final String gender;

  Swimmer({
    this.id,
    required this.firstName,
    required this.surname,
    this.photoPath,
    required this.dob,
    required this.nationality,
    required this.gender,
    this.club,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firstName': firstName,
      'surname': surname,
      'photoPath': photoPath,
      'dob': dob.toIso8601String(),
      'nationality': nationality,
      'gender': gender,
      'club': club,
    };
  }

  factory Swimmer.fromMap(Map<String, dynamic> map) {
    return Swimmer(
      id: map['id'],
      firstName: map['firstName'],
      surname: map['surname'],
      photoPath: map['photoPath'],
      dob: DateTime.parse(map['dob']),
      nationality: map['nationality'],
      gender: map['gender'] ?? 'Female',
      club: map['club'],
    );
  }

  String get fullName => '$firstName $surname';

  int calculateAgeAtEndYear() {
    final now = DateTime.now();
    return now.year - dob.year;
  }
}
