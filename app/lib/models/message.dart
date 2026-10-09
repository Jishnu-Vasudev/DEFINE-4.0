enum OutboxStatus { queued, sent, delivered }

class Message {
  final String id;
  final String channelId;
  final String senderId;
  final String type;
  final String body;
  final String? media;
  final int createdAt;
  final int offline;
  final int? seq;
  final OutboxStatus status;

  Message({
    required this.id,
    required this.channelId,
    required this.senderId,
    required this.type,
    required this.body,
    this.media,
    required this.createdAt,
    this.offline = 0,
    this.seq,
    this.status = OutboxStatus.delivered,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      channelId: json['channel_id'] as String,
      senderId: json['sender_id'] as String,
      type: json['type'] as String,
      body: (json['body'] as String?) ?? '',
      media: json['media'] as String?,
      createdAt: (json['created_at'] as num).toInt(),
      offline: (json['offline'] as num?)?.toInt() ?? 0,
      seq: (json['seq'] as num?)?.toInt(),
      status: OutboxStatus.delivered,
    );
  }

  factory Message.fromDbMap(Map<String, dynamic> map) {
    OutboxStatus st = OutboxStatus.delivered;
    if (map['status'] == 'queued') st = OutboxStatus.queued;
    if (map['status'] == 'sent') st = OutboxStatus.sent;

    return Message(
      id: map['id'] as String,
      channelId: map['channel_id'] as String,
      senderId: map['sender_id'] as String,
      type: map['type'] as String,
      body: (map['body'] as String?) ?? '',
      media: map['media'] as String?,
      createdAt: (map['created_at'] as num).toInt(),
      offline: (map['offline'] as num?)?.toInt() ?? 0,
      seq: (map['seq'] as num?)?.toInt(),
      status: st,
    );
  }

  Map<String, dynamic> toDbMap() => {
    'id': id,
    'channel_id': channelId,
    'sender_id': senderId,
    'type': type,
    'body': body,
    'media': media,
    'created_at': createdAt,
    'offline': offline,
    'seq': seq,
    'status': status.name,
  };

  Map<String, dynamic> toApiPayload() => {
    'id': id,
    'channel_id': channelId,
    'type': type,
    'body': body,
    if (media != null) 'media': media,
    'created_at': createdAt,
    'offline': offline,
  };

  Message copyWith({
    String? id,
    String? channelId,
    String? senderId,
    String? type,
    String? body,
    String? media,
    int? createdAt,
    int? offline,
    int? seq,
    OutboxStatus? status,
  }) {
    return Message(
      id: id ?? this.id,
      channelId: channelId ?? this.channelId,
      senderId: senderId ?? this.senderId,
      type: type ?? this.type,
      body: body ?? this.body,
      media: media ?? this.media,
      createdAt: createdAt ?? this.createdAt,
      offline: offline ?? this.offline,
      seq: seq ?? this.seq,
      status: status ?? this.status,
    );
  }
}
