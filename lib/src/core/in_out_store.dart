
class InOutStore {
  static final storeData = <int, InOutStore>{};
  final _data = <String, dynamic>{};

  void set(String key, dynamic value) => _data[key] = value;

  /// Returns the stored value that has been associated with the specified [key].
  /// Returns `null` if no value has been written.
  ///
  /// Example:
  /// ```dart
  /// var foo = req.store.tryGet<Foo>('foo');
  /// ```
  T? tryGet<T>(String key) {
    dynamic data = _data[key];
    assert(data == null || data is T, 'Store value for key $key does not match type $T');
    return data as T?;
  }

  /// Returns the stored value that has been associated with the specified [key].
  /// Will throw if null or no value was registered.
  T get<T>(String key) {
    return tryGet<T>(key) as T;
  }

  /// Gets the value for the specified [key] or sets it using the [builder].
  ///
  /// Example:
  /// ```dart
  /// var foo = req.store.getOrSet<ExpensiveFoo>('foo', () => ExpensiveFoo());
  /// ```
  T getOrSet<T>(String key, T Function() builder) {
    if (!_data.containsKey(key)) {
      final value = builder();
      set(key, value);
      return value;
    } else {
      return get<T>(key);
    }
  }

  bool exist(String key){
    return _data[key] != null;
  }

  /// Clear any value associated with the specified [key].
  void unset(String key) => _data.remove(key);

  /// Used within server to remove request-related data after the request has been resolved.
  static void releaseStore(int inOutHash) {
    InOutStore.storeData.remove(inOutHash);
  }
}
