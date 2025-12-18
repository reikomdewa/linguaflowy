import 'package:flutter/foundation.dart';

/// "Debug Print" - Only prints when in debug mode.
/// Safe to use everywhere; it will vanish in production.
void printLog(Object object) {
  if (kDebugMode) {
    printLog(object);
  }
}
