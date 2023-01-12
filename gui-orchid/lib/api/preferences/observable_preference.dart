import 'package:flutter/material.dart';
import 'package:orchid/api/preferences/user_preferences.dart';
import 'package:rxdart/rxdart.dart';

class ObservablePreference<T> {
  UserPreferenceKey key;
  bool _initialized = false;

  bool get initialized {
    return _initialized;
  }

  BehaviorSubject<T> _subject = BehaviorSubject();

  T Function(UserPreferenceKey key) getValue;
  Future Function(UserPreferenceKey key, T value) putValue;

  ObservablePreference(
      {@required this.key, @required this.getValue, @required this.putValue});

  /// Subscribe to the value stream. This method ensures that the stream is
  /// initialized with the first value from the underlying user preference.
  Stream<T> stream() {
    _ensureInitialized();
    return _subject.asBroadcastStream();
  }

  ObservablePreferenceBuilder<T> builder(Widget Function(T t) builder) {
    return ObservablePreferenceBuilder(stream: stream(), builder: builder);
  }

  T get() {
    if (_initialized) {
      return _subject.value;
    } else {
      T value = getValue(key);
      _broadcast(value);
      return value;
    }
  }

  Future<T> set(T value) async {
    await putValue(key, value);
    // If the value is null attempt to load it again allowing the store method
    // to transform it if needed.
    _broadcast(value ?? getValue(key));
    return value;
  }

  bool hasValue() {
    return get() != null;
  }

  Future<void> clear() async {
    return set(null);
  }

  // This can be called during startup to block until the property has been initialized
  void _ensureInitialized() {
    get();
  }

  void _broadcast(value) {
    _initialized = true;
    _subject.add(value);
  }

}

class ObservableStringPreference extends ObservablePreference<String> {
  ObservableStringPreference(UserPreferenceKey key)
      : super(
            key: key,
            getValue: (key) {
              return UserPreferences().getStringForKey(key);
            },
            putValue: (key, value) {
              return UserPreferences().putStringForKey(key, value);
            });
}

/// An observable boolean value which returns false (or a specified default)
/// when uninitialized
class ObservableBoolPreference extends ObservablePreference<bool> {
  final bool defaultValue;

  ObservableBoolPreference(UserPreferenceKey key, {this.defaultValue = false})
      : super(
            key: key,
            getValue: (key) {
              return (UserPreferences().sharedPreferences())
                      .getBool(key.toString()) ??
                  defaultValue;
            },
            putValue: (key, value) async {
              return (UserPreferences().sharedPreferences())
                  .setBool(key.toString(), value);
            });
}

class ObservablePreferenceBuilder<T> extends StatelessWidget {
  final Stream<T> stream;
  final Widget Function(T t) builder;

  const ObservablePreferenceBuilder({
    Key key,
    this.stream,
    this.builder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
        stream: stream,
        builder: (context, snapshot) {
          return builder(snapshot.data);
        });
  }
}

// TODO: MOVE
class ReleaseVersion {
  final int version;

  ReleaseVersion(this.version);

  ReleaseVersion.resetFirstLaunch() : this.version = null;

  /// This is represents a first launch of the app since the V1 UI.
  bool get isFirstLaunch {
    return version == null;
  }

  // Compare versions or return true if first launch.
  bool isOlderThan(ReleaseVersion other) {
    return version == null || version < other.version;
  }

  @override
  String toString() {
    return 'ReleaseVersion{version: $version}';
  }
}
