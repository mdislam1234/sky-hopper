enum DataError {
  unauthenticated,
  invalidInput,
  unavailable,
  insufficientCoins,
  skinNotOwned,
}

class DataException implements Exception {
  const DataException(this.code);
  final DataError code;

  String get message => switch (code) {
    DataError.insufficientCoins => 'Not enough coins.',
    DataError.skinNotOwned => 'Unlock this skin before selecting it.',
    DataError.unauthenticated => 'Sign in before accessing your saved data.',
    DataError.invalidInput => 'Check the supplied values and try again.',
    DataError.unavailable =>
      'Your saved data could not be accessed. Please try again.',
  };

  @override
  String toString() => message;
}
