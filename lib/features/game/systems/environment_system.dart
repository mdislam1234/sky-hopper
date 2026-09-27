import 'dart:ui';

import '../config/game_config.dart';

enum Biome {
  sunny('SUNNY SKY'),
  sunset('SUNSET'),
  storm('STORM'),
  night('NIGHT'),
  space('SPACE');

  const Biome(this.label);
  final String label;
}

class BiomeVisualConfig {
  const BiomeVisualConfig({
    required this.skyTop,
    required this.skyBottom,
    required this.cloud,
    required this.platformTop,
    required this.platformBase,
    required this.starDensity,
    required this.rainDensity,
  });

  final Color skyTop;
  final Color skyBottom;
  final Color cloud;
  final Color platformTop;
  final Color platformBase;
  final double starDensity;
  final double rainDensity;
}

class BiomeFrame {
  const BiomeFrame({
    required this.biome,
    required this.from,
    required this.to,
    required this.blend,
  });

  final Biome biome;
  final Biome from;
  final Biome to;
  final double blend;

  Color blendColor(Color Function(BiomeVisualConfig value) select) =>
      Color.lerp(
        select(BiomeSystem.visuals[from]!),
        select(BiomeSystem.visuals[to]!),
        blend,
      )!;

  double blendValue(double Function(BiomeVisualConfig value) select) {
    final start = select(BiomeSystem.visuals[from]!);
    return start + (select(BiomeSystem.visuals[to]!) - start) * blend;
  }
}

abstract final class BiomeSystem {
  static const Map<Biome, BiomeVisualConfig> visuals = {
    Biome.sunny: BiomeVisualConfig(
      skyTop: Color(0xFF55BFF5),
      skyBottom: Color(0xFFC7EEFF),
      cloud: Color(0xFFF7FCFF),
      platformTop: Color(0xFF7EE081),
      platformBase: Color(0xFF3B8F62),
      starDensity: 0,
      rainDensity: 0,
    ),
    Biome.sunset: BiomeVisualConfig(
      skyTop: Color(0xFF9559B9),
      skyBottom: Color(0xFFFFA667),
      cloud: Color(0xFFFFC7B2),
      platformTop: Color(0xFFD8A568),
      platformBase: Color(0xFF78536F),
      starDensity: 0.08,
      rainDensity: 0,
    ),
    Biome.storm: BiomeVisualConfig(
      skyTop: Color(0xFF273C5B),
      skyBottom: Color(0xFF62768D),
      cloud: Color(0xFF9BA9B5),
      platformTop: Color(0xFF73A69A),
      platformBase: Color(0xFF3F5961),
      starDensity: 0,
      rainDensity: 0.8,
    ),
    Biome.night: BiomeVisualConfig(
      skyTop: Color(0xFF081A45),
      skyBottom: Color(0xFF244A79),
      cloud: Color(0xFF8294B4),
      platformTop: Color(0xFF78D9D0),
      platformBase: Color(0xFF315C74),
      starDensity: 0.75,
      rainDensity: 0.1,
    ),
    Biome.space: BiomeVisualConfig(
      skyTop: Color(0xFF050714),
      skyBottom: Color(0xFF161438),
      cloud: Color(0xFF5C6182),
      platformTop: Color(0xFF8FE6FF),
      platformBase: Color(0xFF424C83),
      starDensity: 1,
      rainDensity: 0,
    ),
  };

  static Biome forScore(int score) {
    if (score >= GameConfig.spaceScore) return Biome.space;
    if (score >= GameConfig.nightScore) return Biome.night;
    if (score >= GameConfig.stormScore) return Biome.storm;
    if (score >= GameConfig.sunsetScore) return Biome.sunset;
    return Biome.sunny;
  }

  static BiomeFrame frameForScore(int score) {
    const boundaries = <(int, Biome, Biome)>[
      (GameConfig.sunsetScore, Biome.sunny, Biome.sunset),
      (GameConfig.stormScore, Biome.sunset, Biome.storm),
      (GameConfig.nightScore, Biome.storm, Biome.night),
      (GameConfig.spaceScore, Biome.night, Biome.space),
    ];
    for (final boundary in boundaries) {
      final start = boundary.$1 - GameConfig.biomeTransitionHalfWidth;
      final end = boundary.$1 + GameConfig.biomeTransitionHalfWidth;
      if (score >= start && score <= end) {
        return BiomeFrame(
          biome: forScore(score),
          from: boundary.$2,
          to: boundary.$3,
          blend: ((score - start) / (end - start)).clamp(0, 1),
        );
      }
    }
    final biome = forScore(score);
    return BiomeFrame(biome: biome, from: biome, to: biome, blend: 0);
  }
}

class EnvironmentState {
  BiomeFrame frame = BiomeSystem.frameForScore(0);
  Biome get biome => frame.biome;

  bool update(int score) {
    final previous = biome;
    frame = BiomeSystem.frameForScore(score);
    return previous != biome;
  }

  void reset() => frame = BiomeSystem.frameForScore(0);
}
