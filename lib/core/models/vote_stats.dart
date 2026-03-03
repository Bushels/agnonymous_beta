class VoteStats {
  final int thumbsUpVotes;
  final int partialVotes;
  final int thumbsDownVotes;
  final int funnyVotes;
  final int totalVotes;

  VoteStats({
    required this.thumbsUpVotes,
    required this.partialVotes,
    required this.thumbsDownVotes,
    required this.funnyVotes,
  }) : totalVotes = thumbsUpVotes + partialVotes + thumbsDownVotes + funnyVotes;

  factory VoteStats.fromMap(Map<String, dynamic> map) {
    return VoteStats(
      thumbsUpVotes: (map['thumbs_up_votes'] ?? 0).toInt(),
      partialVotes: (map['partial_votes'] ?? 0).toInt(),
      thumbsDownVotes: (map['thumbs_down_votes'] ?? 0).toInt(),
      funnyVotes: (map['funny_votes'] ?? 0).toInt(),
    );
  }
}
