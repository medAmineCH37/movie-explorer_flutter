import 'package:flutter/foundation.dart';

/// Signals that the user's lists (or anything feeding the recommendations)
/// changed, so open screens can refresh themselves without a manual reload.
class ListChanges extends ChangeNotifier {
  ListChanges._();

  static final ListChanges instance = ListChanges._();

  void notify() => notifyListeners();
}
