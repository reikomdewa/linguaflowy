import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class PromoCodesTab extends StatefulWidget {
  const PromoCodesTab({super.key});
  @override
  State<PromoCodesTab> createState() => _PromoCodesTabState();
}

class _PromoCodesTabState extends State<PromoCodesTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // ---------------------------------------------------------------------------
  // NEW: ENHANCED DIALOG
  // ---------------------------------------------------------------------------
  void _createCode(BuildContext context) {
    final codeController = TextEditingController();
    final countController = TextEditingController(text: "1");
    final amountController = TextEditingController(text: "0");
    final currencyController = TextEditingController(text: "USD");
    
    // Default: 1 Month from now
    DateTime? expirationDate = DateTime.now().add(const Duration(days: 30));
    bool isLifetime = false;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = TextStyle(color: isDark ? Colors.white : Colors.black);
    final hintStyle = TextStyle(color: isDark ? Colors.grey : Colors.grey[600]);

    showDialog(
      context: context,
      builder: (ctx) {
        // Use StatefulBuilder so the Dialog can update when typing amount
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            
            // Helper to calculate date based on amount
            void updateDateFromAmount(String value) {
              double amount = double.tryParse(value) ?? 0;
              setStateDialog(() {
                if (amount >= 100) {
                  isLifetime = true;
                  expirationDate = null; // Represents Forever
                } else if (amount >= 20) {
                  isLifetime = false;
                  expirationDate = DateTime.now().add(const Duration(days: 30 * 6));
                } else {
                  isLifetime = false;
                  expirationDate = DateTime.now().add(const Duration(days: 30));
                }
              });
            }

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
              title: Text("Generate Premium Codes", style: style),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Code Input
                    TextField(
                      controller: codeController,
                      style: style,
                      decoration: InputDecoration(
                        labelText: "Custom Code (Optional)",
                        hintText: "SALE2025",
                        hintStyle: hintStyle,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Quantity
                    TextField(
                      controller: countController,
                      keyboardType: TextInputType.number,
                      style: style,
                      decoration: InputDecoration(
                        labelText: "Quantity",
                        hintStyle: hintStyle,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Amount and Currency Row
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: style,
                            decoration: InputDecoration(
                              labelText: "Paid Amount",
                              prefixText: "\$ ",
                              hintStyle: hintStyle,
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (val) => updateDateFromAmount(val),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: currencyController,
                            style: style,
                            decoration: InputDecoration(
                              labelText: "Currency",
                              hintStyle: hintStyle,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Date Picker Section
                    Text("Expiration Date:", style: style.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: expirationDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                        );
                        if (picked != null) {
                          setStateDialog(() {
                            expirationDate = picked;
                            isLifetime = false;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isLifetime 
                                  ? "Lifetime (Never Expires)" 
                                  : (expirationDate != null 
                                      ? "${expirationDate!.day}/${expirationDate!.month}/${expirationDate!.year}" 
                                      : "Select Date"),
                              style: style,
                            ),
                            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    if (isLifetime)
                      Padding(
                        padding: const EdgeInsets.only(top: 5.0),
                        child: Text(
                          "Set to Lifetime because amount is \$100+",
                          style: TextStyle(color: Colors.amber[700], fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    int count = int.tryParse(countController.text) ?? 1;
                    double amount = double.tryParse(amountController.text) ?? 0.0;
                    
                    _bulkGenerate(
                      ctx,
                      codeController.text.trim().toUpperCase(),
                      count,
                      amount,
                      currencyController.text.trim().toLowerCase(),
                      expirationDate,
                      isLifetime,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text("Generate"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // NEW: BULK GENERATE LOGIC
  // ---------------------------------------------------------------------------
  void _bulkGenerate(
    BuildContext context,
    String customCode,
    int count,
    double amount,
    String currency,
    DateTime? explicitExpiration,
    bool isLifetime,
  ) async {
    Navigator.pop(context); // Close dialog
    final batch = FirebaseFirestore.instance.batch();
    final List<String> generatedCodes = [];

    // Convert Amount to Cents for compatibility with your Logic
    final int amountInCents = (amount * 100).toInt();

    for (int i = 0; i < count; i++) {
      String code = (customCode.isNotEmpty && count == 1) 
          ? customCode 
          : "PRO-${List.generate(4, (index) => "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"[Random().nextInt(32)]).join()}";
      
      generatedCodes.add(code);

      final docRef = FirebaseFirestore.instance.collection('promo_codes').doc(code);

      batch.set(docRef, {
        'isClaimed': false,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': 'admin',
        'claimedBy': null,
        'source': 'manual_admin', // Mark as manually generated

        // PAYMENT DATA (Matches Gumroad format so AuthBloc works)
        'amount_paid': amountInCents, 
        'currency': currency,
        // We set 'purchased_at' to Now
        'purchased_at': DateTime.now().toIso8601String(),
        
        // OPTIONAL: If you want to enforce the specific date chosen in the date picker
        // You would need to update AuthBloc to check 'manual_expires_at' first.
        'manual_expires_at': isLifetime ? null : explicitExpiration?.toIso8601String(),
      });
    }

    await batch.commit();
    if (count > 0 && context.mounted) {
      _showBulkResultDialog(context, generatedCodes);
    }
  }

  void _showBulkResultDialog(BuildContext context, List<String> codes) {
    final text = codes.join("\n");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("${codes.length} Codes Generated"),
        content: SingleChildScrollView(child: SelectableText(text)),
        actions: [
          ElevatedButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              Navigator.pop(ctx);
            },
            child: const Text("Copy All"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ... (Your existing build method is fine, no changes needed below here) ...
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: textColor),
              decoration: const InputDecoration(
                hintText: "Search Code...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toUpperCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('promo_codes')
                  .orderBy('createdAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var docs = snapshot.data!.docs;
                if (_searchQuery.isNotEmpty) {
                  docs = docs.where((doc) => doc.id.contains(_searchQuery)).toList();
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final code = docs[index].id;
                    final source = data['source'] ?? 'manual';
                    final amount = data['amount_paid'] != null ? (data['amount_paid'] / 100).toString() : "0";

                    return Card(
                      color: cardColor,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: Icon(
                          data['isClaimed'] == true ? Icons.check : Icons.vpn_key,
                          color: data['isClaimed'] == true ? Colors.red : Colors.green,
                        ),
                        title: Row(
                          children: [
                            if (source == 'gumroad')
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.pinkAccent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text("GUM", style: TextStyle(color: Colors.white, fontSize: 8)),
                              ),
                             if (source == 'manual_admin')
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text("ADMIN", style: TextStyle(color: Colors.white, fontSize: 8)),
                              ),
                            Expanded(
                              child: InkWell(
                                onTap: () => Clipboard.setData(ClipboardData(text: code)),
                                child: Text(
                                  code,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', color: textColor, fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if(data['isClaimed'] == true)
                              Text("Used by: ${data['claimedBy']}", style: const TextStyle(fontSize: 10, color: Colors.blue)),
                            Text("Val: \$$amount", style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => FirebaseFirestore.instance.collection('promo_codes').doc(code).delete(),
                        ),
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