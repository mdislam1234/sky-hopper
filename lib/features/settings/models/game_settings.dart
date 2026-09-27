class GameSettings {
  const GameSettings({
    this.musicEnabled = true,
    this.soundEnabled = true,
    this.hapticsEnabled = true,
  });

  final bool musicEnabled;
  final bool soundEnabled;
  final bool hapticsEnabled;

  GameSettings copyWith({
    bool? musicEnabled,
    bool? soundEnabled,
    bool? hapticsEnabled,
  }) => GameSettings(
    musicEnabled: musicEnabled ?? this.musicEnabled,
    soundEnabled: soundEnabled ?? this.soundEnabled,
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
  );

  @override
  bool operator ==(Object other) =>
      other is GameSettings &&
      musicEnabled == other.musicEnabled &&
      soundEnabled == other.soundEnabled &&
      hapticsEnabled == other.hapticsEnabled;

  @override
  int get hashCode => Object.hash(musicEnabled, soundEnabled, hapticsEnabled);
}
