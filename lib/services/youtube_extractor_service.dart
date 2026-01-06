import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class AudioExtractorService {
  final YoutubeExplode _yt = YoutubeExplode();

  Future<String?> downloadAudio(String videoUrl) async {
    try {
      debugPrint("🔍 Extracting Audio for: $videoUrl");

      var video = await _yt.videos.get(videoUrl);
      var manifest = await _yt.videos.streamsClient.getManifest(video.id);
      
      // Get audio only streams
      var audioStreams = manifest.audioOnly;
      if (audioStreams.isEmpty) return null;

      // FIX: Manually find lowest bitrate to save data/processing time
      var streamInfo = audioStreams.reduce((curr, next) => 
        (curr.bitrate.bitsPerSecond < next.bitrate.bitsPerSecond) ? curr : next
      );

      var stream = _yt.videos.streamsClient.get(streamInfo);
      
      final dir = await getTemporaryDirectory();
      // Whisper often prefers wav/m4a. 
      final filePath = '${dir.path}/audio_${video.id}.m4a';
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
      }

      var fileStream = file.openWrite();
      await stream.pipe(fileStream);
      await fileStream.flush();
      await fileStream.close();

      debugPrint("✅ Audio downloaded: $filePath");
      return filePath;

    } catch (e) {
      debugPrint("❌ Extraction Failed: $e");
      return null;
    } finally {
      _yt.close();
    }
  }
}