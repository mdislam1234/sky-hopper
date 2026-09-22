import 'package:supabase_flutter/supabase_flutter.dart';

import 'data_exception.dart';

String requireUserId(SupabaseClient client) {
  final user = client.auth.currentUser;
  if (user == null) throw const DataException(DataError.unauthenticated);
  return user.id;
}

Future<T> dataOperation<T>(Future<T> Function() operation) async {
  try {
    return await operation();
  } on DataException {
    rethrow;
  } on Exception {
    throw const DataException(DataError.unavailable);
  }
}
