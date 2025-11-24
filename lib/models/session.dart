import 'package:equatable/equatable.dart';

enum SessionState {
  idle,
  discovering,
  advertising,
  connecting,
  connected,
  ended,
}

class Session extends Equatable {
  final String id;
  final String hostId;
  final List<String> peerIds;
  final SessionState state;
  final bool isHost;

  const Session({
    required this.id,
    required this.hostId,
    this.peerIds = const [],
    this.state = SessionState.idle,
    this.isHost = false,
  });

  Session copyWith({
    String? id,
    String? hostId,
    List<String>? peerIds,
    SessionState? state,
    bool? isHost,
  }) {
    return Session(
      id: id ?? this.id,
      hostId: hostId ?? this.hostId,
      peerIds: peerIds ?? this.peerIds,
      state: state ?? this.state,
      isHost: isHost ?? this.isHost,
    );
  }

  @override
  List<Object?> get props => [id, hostId, peerIds, state, isHost];
}
