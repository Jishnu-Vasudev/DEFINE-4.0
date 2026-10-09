class Channel {
  final String id;
  final String? teamId;
  final String name;
  final String kind;

  Channel({
    required this.id,
    this.teamId,
    required this.name,
    required this.kind,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id'] as String,
      teamId: json['team_id'] as String?,
      name: json['name'] as String,
      kind: (json['kind'] as String?) ?? 'team',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'team_id': teamId,
    'name': name,
    'kind': kind,
  };
}
