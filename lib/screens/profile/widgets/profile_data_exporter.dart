import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ProfileDataExporter {
  static Future<void> exportUserData(
    BuildContext context,
    String userId,
  ) async {
    // 1. Show Loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Generating export file... please wait.")),
    );

    try {
      final firestore = FirebaseFirestore.instance;

      // 2. Fetch User Profile
      final userDoc = await firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() ?? {};

      // 3. Fetch Vocabulary
      final vocabSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('vocabulary')
          .get();

      final vocabList = vocabSnapshot.docs.map((doc) => doc.data()).toList();

      // 4. Combine Data
      final Map<String, dynamic> exportData = {
        'generated_at': DateTime.now().toIso8601String(),
        'app': 'LinguaFlow',
        'profile': userData,
        'vocabulary_count': vocabList.length,
        'vocabulary': vocabList,
      };

      // 5. Convert to JSON
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      // 6. Write to Temp File
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/linguaflow_export.json');
      await file.writeAsString(jsonString);

      // 7. Share File

      // inside async context
      if (context.mounted) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'My LinguaFlow Data Export',
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Export failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
