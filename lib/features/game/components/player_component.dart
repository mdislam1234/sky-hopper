import 'dart:ui';

import 'package:flame/components.dart';

import '../../skins/models/skin.dart';
import '../../skins/widgets/skin_preview.dart';
import '../systems/game_state.dart';

class PlayerComponent extends PositionComponent {
  PlayerComponent(this.state, {this.appearance = SkinAppearance.defaultSkin})
    : art = HopperArt(appearance),
      super(priority: 10);
  final GameState state;
  final SkinAppearance appearance;
  final HopperArt art;
  @override
  void update(double dt) {
    position.setValues(state.x, state.y);
    super.update(dt);
  }

  @override
  void render(Canvas canvas) => art.render(canvas);
}
