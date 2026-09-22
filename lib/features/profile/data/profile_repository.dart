import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/data_exception.dart';
import '../../../core/data/repository_support.dart';
import '../models/profile.dart';
import '../../skins/data/skin_repository.dart';

class ProfileRepository {
  ProfileRepository(this._client);
  final SupabaseClient _client;

  Future<Profile?> fetchCurrent() => dataOperation(() async {
    final id = requireUserId(_client);
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  });

  Future<Profile> updateDisplayName(String? name) => _update({
    'display_name': name == null || name.trim().isEmpty ? null : name.trim(),
  });

  Future<Profile> updateSelectedSkin(String skinId) async {
    if (skinId.trim().isEmpty) {
      throw const DataException(DataError.invalidInput);
    }
    await SkinRepository(_client).selectSkin(skinId.trim());
    final profile = await fetchCurrent();
    if (profile == null) throw const DataException(DataError.unavailable);
    return profile;
  }

  Future<Profile> _update(Map<String, dynamic> fields) =>
      dataOperation(() async {
        final id = requireUserId(_client);
        final row = await _client
            .from('profiles')
            .update(fields)
            .eq('id', id)
            .select()
            .single();
        return Profile.fromJson(row);
      });
}
