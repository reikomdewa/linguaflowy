import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

// -----------------------------------------------------------------------------
// PROMO CODES TAB
// -----------------------------------------------------------------------------
class PromoCodesTab extends StatefulWidget {
  const PromoCodesTab({super.key});
  @override
  State<PromoCodesTab> createState() => _PromoCodesTabState();
}

class _PromoCodesTabState extends State<PromoCodesTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  void _createCode(BuildContext context) {
    final controller = TextEditingController();
    final countController = TextEditingController(text: "1");
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        title: Text("Generate Codes", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: controller, style: TextStyle(color: isDark ? Colors.white : Colors.black), decoration: const InputDecoration(labelText: "Custom Code", hintText: "SALE2024", border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: countController, keyboardType: TextInputType.number, style: TextStyle(color: isDark ? Colors.white : Colors.black), decoration: const InputDecoration(labelText: "Quantity", border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              int count = int.tryParse(countController.text) ?? 1;
              _bulkGenerate(ctx, controller.text.trim().toUpperCase(), count);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            child: const Text("Generate"),
          ),
        ],
      ),
    );
  }

  void _bulkGenerate(BuildContext context, String customCode, int count) async {
    Navigator.pop(context);
    final batch = FirebaseFirestore.instance.batch();
    final List<String> generatedCodes = [];
    for (int i = 0; i < count; i++) {
      String code = (customCode.isNotEmpty && count == 1) ? customCode : "PRO-${List.generate(4, (index) => "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"[Random().nextInt(32)]).join()}";
      generatedCodes.add(code);
      batch.set(FirebaseFirestore.instance.collection('promo_codes').doc(code), {
        'isClaimed': false, 'createdAt': FieldValue.serverTimestamp(), 'createdBy': 'admin', 'claimedBy': null, 'source': 'manual',
      });
    }
    await batch.commit();
    if(count > 1 && context.mounted) _showBulkResultDialog(context, generatedCodes);
  }

  void _showBulkResultDialog(BuildContext context, List<String> codes) {
    final text = codes.join("\n");
    showDialog(context: context, builder: (ctx) => AlertDialog(title: Text("${codes.length} Codes Generated"), content: SingleChildScrollView(child: SelectableText(text)), actions: [ElevatedButton(onPressed: () { Clipboard.setData(ClipboardData(text: text)); Navigator.pop(ctx); }, child: const Text("Copy All"))]));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createCode(context),
        backgroundColor: Colors.amber,
        label: const Text("Generate", style: TextStyle(color: Colors.black)),
        icon: const Icon(Icons.add, color: Colors.black),
      ),
      body: Column(
        children: [
          Padding(padding: const EdgeInsets.all(16.0), child: TextField(controller: _searchController, style: TextStyle(color: textColor), decoration: const InputDecoration(hintText: "Search Code...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()), onChanged: (val) => setState(() => _searchQuery = val.toUpperCase()))),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('promo_codes').orderBy('createdAt', descending: true).limit(50).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var docs = snapshot.data!.docs;
                if (_searchQuery.isNotEmpty) docs = docs.where((doc) => doc.id.contains(_searchQuery)).toList();

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final code = docs[index].id;
                    final source = data['source'] ?? 'manual';
                    
                    return Card(
                      color: cardColor,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: Icon(data['isClaimed'] == true ? Icons.check : Icons.vpn_key, color: data['isClaimed'] == true ? Colors.red : Colors.green),
                        title: Row(
                          children: [
                            if (source == 'gumroad') Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.pinkAccent, borderRadius: BorderRadius.circular(4)), child: const Text("GUMROAD", style: TextStyle(color: Colors.white, fontSize: 8))),
                            Expanded(child: InkWell(onTap: () => Clipboard.setData(ClipboardData(text: code)), child: Text(code, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', color: textColor, fontSize: 12)))),
                          ],
                        ),
                        subtitle: data['isClaimed'] == true 
                          ? InkWell(onTap: () => Clipboard.setData(ClipboardData(text: data['claimedBy'] ?? "")), child: Text("Used by: ${data['claimedBy']}", overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.blue))) 
                          : const Text("Active", style: TextStyle(color: Colors.green)),
                        trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => FirebaseFirestore.instance.collection('promo_codes').doc(code).delete()),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
