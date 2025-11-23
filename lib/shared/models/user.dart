

class User {
  final String id;
  final String email;
  final String? username;
  final String? avatarUrl;
  final String? displayName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isOnline;
  final DateTime? lastSeen;

  User({
    required this.id,
    required this.email,
    this.username,
    this.avatarUrl,
    this.displayName,
    this.createdAt,
    this.updatedAt,
    this.isOnline = false,
    this.lastSeen,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String,
      email: map['email'] as String,
      username: map['username'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      displayName: map['display_name'] as String?,
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'] as String) 
          : null,
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at'] as String) 
          : null,
      isOnline: map['is_online'] as bool? ?? false,
      lastSeen: map['last_seen'] != null 
          ? DateTime.parse(map['last_seen'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'avatar_url': avatarUrl,
      'display_name': displayName,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_online': isOnline,
      'last_seen': lastSeen?.toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? email,
    String? username,
    String? avatarUrl,
    String? displayName,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}