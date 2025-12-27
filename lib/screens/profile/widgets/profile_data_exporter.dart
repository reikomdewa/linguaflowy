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

      // ============================================================
      // 5. Convert to JSON (FIXED)
      // We pass a custom function to handle Firestore Timestamps
      // ============================================================
      final jsonString = JsonEncoder.withIndent('  ', (object) {
        if (object is Timestamp) {
          return object.toDate().toIso8601String();
        }
        if (object is GeoPoint) {
          return {'lat': object.latitude, 'lng': object.longitude};
        }
        if (object is DocumentReference) {
          return object.path;
        }
        // Return string for unknown objects to prevent crash
        return object.toString(); 
      }).convert(exportData);

      // 6. Write to Temp File
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/linguaflow_export.json');
      await file.writeAsString(jsonString);

      // 7. Share File
      if (context.mounted) {
        // Updated to standard Share_plus syntax
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'My LinguaFlow Data Export',
        );
      }
      
      // Optional: Clear loading snackbar
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
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