import 'package:media_kit/media_kit.dart';

class MediaLifecycle {
  // A static list that holds players while they are dying.
  // This prevents the Garbage Collector (GC) from finding them and 
  // triggering the "NativeReferenceHolder" crash.
  static final List<Player> _protectFromGc = [];

  static void disposeSafe(Player? player) {
    if (player == null) return;

    // 1. "Pin" the player in memory so GC ignores it
    _protectFromGc.add(player);

    // 2. Dispose safely without awaiting (Fire and Forget)
    player.dispose().catchError((e) {
      // Ignore errors during app exit
    }).whenComplete(() {
      // 3. Only unpin when we are 100% sure the native side is done
      _protectFromGc.remove(player);
    });
  }
}