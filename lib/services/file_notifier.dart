import 'package:flutter/foundation.dart';

/// Singleton notifier — call [notifyFileChanged] whenever a file is
/// saved/deleted so all listening screens can reload their data.
class FileNotifier extends ChangeNotifier {
  FileNotifier._();
  static final instance = FileNotifier._();

  void notifyFileChanged() => notifyListeners();
}
