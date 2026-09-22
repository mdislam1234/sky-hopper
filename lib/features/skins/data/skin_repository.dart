import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/data_exception.dart';
import '../../../core/data/repository_support.dart';
import '../models/user_skin.dart';
import '../models/skin.dart';

abstract interface class SkinStore {
  Future<List<Skin>> fetchCatalog();
  Future<List<UserSkin>> fetchOwnedSkins();
  Future<SkinUnlock> unlockSkin(String skinId);
  Future<SkinSelection> selectSkin(String skinId);
}

class SkinRepository implements SkinStore {
  SkinRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<Skin>> fetchCatalog() => dataOperation(() async {
    requireUserId(_client);
    final rows = await _client
        .from('skin_catalog')
        .select(
          'id,name,description,cost,primary_color,secondary_color,accent_color',
        )
        .eq('is_active', true)
        .order('sort_order')
        .order('id');
    return rows.map(Skin.fromJson).toList(growable: false);
  });

  Future<List<UserSkin>> fetchUnlocked() => fetchOwnedSkins();
  @override
  Future<List<UserSkin>> fetchOwnedSkins() => dataOperation(() async {
    final id = requireUserId(_client);
    final rows = await _client
        .from('user_skins')
        .select()
        .eq('user_id', id)
        .order('unlocked_at')
        .order('skin_id');
    return rows.map(UserSkin.fromJson).toList(growable: false);
  });

  Future<Object?> _call(String function, String skinId) =>
      dataOperation(() async {
        requireUserId(_client);
        if (!RegExp(r'^[a-z][a-z0-9_]{0,39}$').hasMatch(skinId)) {
          throw const DataException(DataError.invalidInput);
        }
        try {
          return await _client.rpc(function, params: {'p_skin_id': skinId});
        } on PostgrestException catch (error) {
          if (error.code == 'SH001') {
            throw const DataException(DataError.insufficientCoins);
          }
          if (error.code == 'SH002') {
            throw const DataException(DataError.skinNotOwned);
          }
          rethrow;
        }
      });

  @override
  Future<SkinUnlock> unlockSkin(String skinId) => dataOperation(() async {
    final result = SkinUnlock.fromJson(await _call('unlock_skin', skinId));
    if (result.skinId != skinId) {
      throw const FormatException('Mismatched skin.');
    }
    return result;
  });

  @override
  Future<SkinSelection> selectSkin(String skinId) => dataOperation(() async {
    final result = SkinSelection.fromJson(await _call('select_skin', skinId));
    if (result.skinId != skinId) {
      throw const FormatException('Mismatched skin.');
    }
    return result;
  });
}
