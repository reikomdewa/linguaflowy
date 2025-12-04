// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/services.dart';
// import 'dart:async';

// class AdminDashboardScreen extends StatefulWidget {
//   const AdminDashboardScreen({super.key});

//   @override
//   State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
// }

// class _AdminDashboardScreenState extends State<AdminDashboardScreen>
//     with SingleTickerProviderStateMixin {
//   late TabController _tabController;

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 2, vsync: this);
//   }

//   @override
//   Widget build(BuildContext context) {
//     final isDark = Theme.of(context).brightness == Brightness.dark;
//     final bgColor = Theme.of(context).scaffoldBackgroundColor;
//     final textColor = Theme.of(context).textTheme.bodyLarge?.color;

//     return Scaffold(
//       backgroundColor: bgColor,
//       appBar: AppBar(
//         title: Text("Admin Dashboard", style: TextStyle(color: textColor)),
//         backgroundColor: bgColor,
//         elevation: 0,
//         iconTheme: IconThemeData(color: textColor),
//         bottom: TabBar(
//           controller: _tabController,
//           indicatorColor: Colors.amber,
//           labelColor: Colors.amber,
//           unselectedLabelColor: Colors.grey,
//           tabs: const [
//             Tab(icon: Icon(Icons.vpn_key), text: "Promo Codes"),
//             Tab(icon: Icon(Icons.people), text: "Manage Users"),
//           ],
//         ),
//       ),
//       body: TabBarView(
//         controller: _tabController,
//         // FIXED: Removed 'const' from the list itself
//         children: [
//           const _PromoCodesTab(),
//           const _UserManagementTab(),
//         ],
//       ),
//     );
//   }
// }

// // -----------------------------------------------------------------------------
// // TAB 1: PROMO CODES
// // -----------------------------------------------------------------------------
// class _PromoCodesTab extends StatefulWidget {
//   const _PromoCodesTab();

//   @override
//   State<_PromoCodesTab> createState() => _PromoCodesTabState();
// }

// class _PromoCodesTabState extends State<_PromoCodesTab> {
//   final TextEditingController _searchController = TextEditingController();
//   String _searchQuery = "";

//   void _createCode(BuildContext context) {
//     final controller = TextEditingController();
//     final countController = TextEditingController(text: "1");
//     final isDark = Theme.of(context).brightness == Brightness.dark;

//     showDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
//         title: Text("Generate Codes", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               controller: controller,
//               style: TextStyle(color: isDark ? Colors.white : Colors.black),
//               decoration: const InputDecoration(
//                 labelText: "Custom Code (Optional)",
//                 hintText: "e.g. SALE2024",
//                 border: OutlineInputBorder(),
//               ),
//             ),
//             const SizedBox(height: 16),
//             TextField(
//               controller: countController,
//               keyboardType: TextInputType.number,
//               style: TextStyle(color: isDark ? Colors.white : Colors.black),
//               decoration: const InputDecoration(
//                 labelText: "Quantity (Bulk Generate)",
//                 border: OutlineInputBorder(),
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
//           ElevatedButton(
//             onPressed: () {
//               int count = int.tryParse(countController.text) ?? 1;
//               _bulkGenerate(ctx, controller.text.trim().toUpperCase(), count);
//             },
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
//             child: const Text("Generate"),
//           ),
//         ],
//       ),
//     );
//   }

//   void _bulkGenerate(BuildContext context, String customCode, int count) async {
//     Navigator.pop(context); 
//     final batch = FirebaseFirestore.instance.batch();
//     final List<String> generatedCodes = [];
    
//     for (int i = 0; i < count; i++) {
//       String code;
//       if (customCode.isNotEmpty && count == 1) {
//         code = customCode;
//       } else {
//         const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; 
//         final rnd = Random();
//         code = "PRO-${List.generate(4, (index) => chars[rnd.nextInt(chars.length)]).join()}";
//       }
      
//       generatedCodes.add(code);
//       final docRef = FirebaseFirestore.instance.collection('promo_codes').doc(code);
//       batch.set(docRef, {
//         'isClaimed': false,
//         'createdAt': FieldValue.serverTimestamp(),
//         'createdBy': 'admin',
//         'claimedBy': null,
//         'source': 'manual',
//       });
//     }

//     try {
//       await batch.commit();
//       if (count > 1) {
//         _showBulkResultDialog(context, generatedCodes);
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text("Code Created!"), backgroundColor: Colors.green));
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
//     }
//   }

//   void _showBulkResultDialog(BuildContext context, List<String> codes) {
//     final text = codes.join("\n");
//     showDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: Text("${codes.length} Codes Generated"),
//         content: SizedBox(
//           width: double.maxFinite,
//           child: SingleChildScrollView(child: SelectableText(text)),
//         ),
//         actions: [
//           ElevatedButton.icon(
//             icon: const Icon(Icons.copy),
//             label: const Text("Copy All"),
//             onPressed: () {
//                Clipboard.setData(ClipboardData(text: text));
//                Navigator.pop(ctx);
//                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied to clipboard")));
//             },
//           )
//         ],
//       ),
//     );
//   }

//   void _deleteCode(String code) {
//     FirebaseFirestore.instance.collection('promo_codes').doc(code).delete();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final isDark = Theme.of(context).brightness == Brightness.dark;
//     final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
//     final textColor = isDark ? Colors.white : Colors.black;

//     return Scaffold(
//       backgroundColor: Colors.transparent,
//       floatingActionButton: FloatingActionButton.extended(
//         onPressed: () => _createCode(context),
//         backgroundColor: Colors.amber,
//         icon: const Icon(Icons.add, color: Colors.black),
//         label: const Text("Generate", style: TextStyle(color: Colors.black)),
//       ),
//       body: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: TextField(
//               controller: _searchController,
//               style: TextStyle(color: textColor),
//               decoration: const InputDecoration(
//                 hintText: "Search Code...",
//                 prefixIcon: Icon(Icons.search),
//                 border: OutlineInputBorder(),
//                 isDense: true,
//               ),
//               onChanged: (val) => setState(() => _searchQuery = val.toUpperCase()),
//             ),
//           ),
          
//           Expanded(
//             child: StreamBuilder<QuerySnapshot>(
//               stream: FirebaseFirestore.instance
//                   .collection('promo_codes')
//                   .orderBy('createdAt', descending: true)
//                   .limit(50)
//                   .snapshots(),
//               builder: (context, snapshot) {
//                 if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
//                 var docs = snapshot.data!.docs;

//                 if (_searchQuery.isNotEmpty) {
//                   docs = docs.where((doc) => doc.id.contains(_searchQuery)).toList();
//                 }

//                 if (docs.isEmpty) return const Center(child: Text("No codes found."));

//                 return ListView.builder(
//                   padding: const EdgeInsets.only(bottom: 80),
//                   itemCount: docs.length,
//                   itemBuilder: (context, index) {
//                     final data = docs[index].data() as Map<String, dynamic>;
//                     final code = docs[index].id;
//                     final isClaimed = data['isClaimed'] == true;
//                     final source = data['source'] ?? 'manual';

//                     return Card(
//                       color: cardColor,
//                       margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//                       child: ListTile(
//                         leading: CircleAvatar(
//                           backgroundColor: isClaimed ? Colors.red[100] : Colors.green[100],
//                           child: Icon(
//                             isClaimed ? Icons.check : Icons.vpn_key,
//                             color: isClaimed ? Colors.red : Colors.green,
//                           ),
//                         ),
//                         title: Row(
//                           children: [
//                             Text(code, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', color: textColor)),
//                             if (source == 'gumroad') 
//                               Container(
//                                 margin: const EdgeInsets.only(left: 8),
//                                 padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
//                                 decoration: BoxDecoration(color: Colors.pinkAccent, borderRadius: BorderRadius.circular(4)),
//                                 child: const Text("GUMROAD", style: TextStyle(color: Colors.white, fontSize: 8)),
//                               )
//                           ],
//                         ),
//                         subtitle: isClaimed
//                             ? Text("Used by: ${data['claimedBy'] ?? 'Unknown'}", style: const TextStyle(fontSize: 12, color: Colors.grey))
//                             : const Text("Active", style: TextStyle(color: Colors.green)),
//                         trailing: IconButton(
//                           icon: const Icon(Icons.delete_outline, color: Colors.grey),
//                           onPressed: () => _deleteCode(code),
//                         ),
//                         onLongPress: () {
//                            Clipboard.setData(ClipboardData(text: code));
//                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied"), duration: Duration(milliseconds: 500)));
//                         },
//                       ),
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // -----------------------------------------------------------------------------
// // TAB 2: USER MANAGEMENT
// // -----------------------------------------------------------------------------
// class _UserManagementTab extends StatefulWidget {
//   const _UserManagementTab();

//   @override
//   State<_UserManagementTab> createState() => _UserManagementTabState();
// }

// class _UserManagementTabState extends State<_UserManagementTab> {
//   final TextEditingController _searchController = TextEditingController();
//   List<DocumentSnapshot> _searchResults = [];
//   bool _isLoading = false;
//   Timer? _debounce; 

//   @override
//   void dispose() {
//     _searchController.dispose();
//     _debounce?.cancel();
//     super.dispose();
//   }

//   void _onSearchChanged(String query) {
//     if (_debounce?.isActive ?? false) _debounce!.cancel();
//     _debounce = Timer(const Duration(milliseconds: 500), () {
//       _performSearch(query);
//     });
//   }

//   Future<void> _performSearch(String query) async {
//     if (query.isEmpty) {
//       setState(() { _searchResults = []; _isLoading = false; });
//       return;
//     }

//     setState(() => _isLoading = true);
//     final cleanQuery = query.trim();

//     try {
//       final emailFuture = FirebaseFirestore.instance
//           .collection('users')
//           .where('email', isGreaterThanOrEqualTo: cleanQuery)
//           .where('email', isLessThan: '$cleanQuery\uf8ff')
//           .limit(10)
//           .get();

//       final nameFuture = FirebaseFirestore.instance
//           .collection('users')
//           .where('displayName', isGreaterThanOrEqualTo: cleanQuery)
//           .where('displayName', isLessThan: '$cleanQuery\uf8ff')
//           .limit(10)
//           .get();

//       final results = await Future.wait([emailFuture, nameFuture]);
//       final Map<String, DocumentSnapshot> mergedDocs = {};

//       for (var doc in results[0].docs) mergedDocs[doc.id] = doc;
//       for (var doc in results[1].docs) mergedDocs[doc.id] = doc;

//       if (mergedDocs.isEmpty && cleanQuery.length > 20) {
//          final docById = await FirebaseFirestore.instance.collection('users').doc(cleanQuery).get();
//          if (docById.exists) mergedDocs[docById.id] = docById;
//       }

//       if (mounted) {
//         setState(() { _searchResults = mergedDocs.values.toList(); _isLoading = false; });
//       }
//     } catch (e) {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   void _togglePremium(String userId, bool currentStatus) async {
//     await FirebaseFirestore.instance.collection('users').doc(userId).update({'isPremium': !currentStatus});
//     _performSearch(_searchController.text);
//   }
  
//   void _checkUserCodes(String userId) async {
//     final snapshot = await FirebaseFirestore.instance.collection('promo_codes').where('claimedBy', isEqualTo: userId).get();
//     if (!mounted) return;
    
//     showDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text("Claimed Codes"),
//         content: snapshot.docs.isEmpty 
//           ? const Text("No codes claimed.") 
//           : Column(mainAxisSize: MainAxisSize.min, children: snapshot.docs.map((doc) => ListTile(leading: const Icon(Icons.check_circle, color: Colors.green), title: Text(doc.id))).toList()),
//         actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close"))],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final isDark = Theme.of(context).brightness == Brightness.dark;
//     final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
//     final textColor = isDark ? Colors.white : Colors.black;

//     return Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: Column(
//         children: [
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
//             decoration: BoxDecoration(
//               color: isDark ? Colors.grey[800] : Colors.grey[200],
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: Row(
//               children: [
//                 const Icon(Icons.search, color: Colors.grey),
//                 const SizedBox(width: 10),
//                 Expanded(
//                   child: TextField(
//                     controller: _searchController,
//                     style: TextStyle(color: textColor),
//                     decoration: const InputDecoration(
//                       hintText: "Search Name, Email or ID...",
//                       border: InputBorder.none,
//                       isDense: true,
//                     ),
//                     onChanged: _onSearchChanged,
//                   ),
//                 ),
//                 if (_searchController.text.isNotEmpty)
//                   IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () { _searchController.clear(); _onSearchChanged(""); }),
//               ],
//             ),
//           ),
          
//           const SizedBox(height: 20),
//           if (_isLoading) const CircularProgressIndicator(),
          
//           Expanded(
//             child: ListView.builder(
//               itemCount: _searchResults.length,
//               itemBuilder: (context, index) {
//                 final data = _searchResults[index].data() as Map<String, dynamic>;
//                 final userId = _searchResults[index].id;
//                 final isPremium = data['isPremium'] == true;
//                 final email = data['email'] ?? 'No Email';
//                 final name = data['displayName'] ?? 'No Name';

//                 return Card(
//                   color: cardColor,
//                   elevation: 2,
//                   margin: const EdgeInsets.only(bottom: 12),
//                   child: Padding(
//                     padding: const EdgeInsets.all(12.0),
//                     child: Column(
//                       children: [
//                         ListTile(
//                           contentPadding: EdgeInsets.zero,
//                           leading: CircleAvatar(
//                             backgroundColor: isPremium ? Colors.amber : Colors.grey,
//                             child: Icon(isPremium ? Icons.star : Icons.person, color: Colors.white),
//                           ),
//                           title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
//                           subtitle: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(email, style: TextStyle(color: Colors.grey[600])),
//                               const SizedBox(height: 4),
//                               InkWell(
//                                 onTap: () {
//                                   Clipboard.setData(ClipboardData(text: userId));
//                                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User ID Copied")));
//                                 },
//                                 child: Container(
//                                   padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                                   decoration: BoxDecoration(color: isDark ? Colors.black38 : Colors.grey[100], borderRadius: BorderRadius.circular(4)),
//                                   child: Text("ID: $userId", style: TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace')),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                         const Divider(),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                              TextButton.icon(
//                                icon: const Icon(Icons.history, size: 16),
//                                label: const Text("Codes"),
//                                onPressed: () => _checkUserCodes(userId),
//                              ),
//                              Row(
//                                children: [
//                                  Text(isPremium ? "PREMIUM" : "FREE", 
//                                    style: TextStyle(color: isPremium ? Colors.amber : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)
//                                  ),
//                                  Switch(
//                                    value: isPremium,
//                                    activeColor: Colors.amber,
//                                    onChanged: (val) => _togglePremium(userId, isPremium),
//                                  ),
//                                ],
//                              )
//                           ],
//                         )
//                       ],
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }




import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Admin Dashboard", style: TextStyle(color: textColor)),
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.vpn_key), text: "Promo Codes"),
            Tab(icon: Icon(Icons.people), text: "Manage Users"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _PromoCodesTab(),
          _UserManagementTab(),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 1: PROMO CODES
// -----------------------------------------------------------------------------
class _PromoCodesTab extends StatefulWidget {
  const _PromoCodesTab({super.key});

  @override
  State<_PromoCodesTab> createState() => _PromoCodesTabState();
}

class _PromoCodesTabState extends State<_PromoCodesTab> {
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
            TextField(
              controller: controller,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: const InputDecoration(
                labelText: "Custom Code (Optional)",
                hintText: "e.g. SALE2024",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: countController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: const InputDecoration(
                labelText: "Quantity (Bulk Generate)",
                border: OutlineInputBorder(),
              ),
            ),
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
      String code;
      if (customCode.isNotEmpty && count == 1) {
        code = customCode;
      } else {
        const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; 
        final rnd = Random();
        code = "PRO-${List.generate(4, (index) => chars[rnd.nextInt(chars.length)]).join()}";
      }
      
      generatedCodes.add(code);
      final docRef = FirebaseFirestore.instance.collection('promo_codes').doc(code);
      batch.set(docRef, {
        'isClaimed': false,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': 'admin',
        'claimedBy': null,
        'source': 'manual',
      });
    }

    try {
      await batch.commit();
      if (count > 1) {
        _showBulkResultDialog(context, generatedCodes);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Code Created!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _showBulkResultDialog(BuildContext context, List<String> codes) {
    final text = codes.join("\n");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("${codes.length} Codes Generated"),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(child: SelectableText(text)),
        ),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text("Copy All"),
            onPressed: () {
               Clipboard.setData(ClipboardData(text: text));
               Navigator.pop(ctx);
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied to clipboard")));
            },
          )
        ],
      ),
    );
  }

  void _deleteCode(String code) {
    FirebaseFirestore.instance.collection('promo_codes').doc(code).delete();
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
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text("Generate", style: TextStyle(color: Colors.black)),
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
                isDense: true,
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

                if (docs.isEmpty) return const Center(child: Text("No codes found."));

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final code = docs[index].id;
                    final isClaimed = data['isClaimed'] == true;
                    final source = data['source'] ?? 'manual';
                    final isGumroad = source == 'gumroad';

                    return Card(
                      color: cardColor,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: InkWell(
                        // Make the whole card copyable on tap or long press
                        onLongPress: () {
                           Clipboard.setData(ClipboardData(text: code));
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Code Copied"), duration: Duration(milliseconds: 500)));
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                          child: Row(
                            children: [
                              // 1. ICON
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: isClaimed ? Colors.red[100] : Colors.green[100],
                                child: Icon(
                                  isClaimed ? Icons.check : Icons.vpn_key,
                                  color: isClaimed ? Colors.red : Colors.green,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              
                              // 2. CONTENT (Tag + Code)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        // GUMROAD TAG FIRST
                                        if (isGumroad) 
                                          Container(
                                            margin: const EdgeInsets.only(right: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            decoration: BoxDecoration(color: Colors.pinkAccent, borderRadius: BorderRadius.circular(4)),
                                            child: const Text("GUMROAD", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                          ),
                                        
                                        // CODE SECOND (Expanded)
                                        Expanded(
                                          child: Text(
                                            code, 
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold, 
                                              fontFamily: 'monospace', 
                                              fontSize: 13, // Smaller font
                                              color: textColor
                                            ),
                                            overflow: TextOverflow.ellipsis, // Truncate with ...
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isClaimed
                                          ? "Used by: ${data['claimedBy'] ?? 'Unknown'}"
                                          : "Active • Long press to copy",
                                      style: TextStyle(fontSize: 11, color: isClaimed ? Colors.grey : Colors.green),
                                    ),
                                  ],
                                ),
                              ),

                              // 3. DELETE ACTION
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                                onPressed: () => _deleteCode(code),
                              ),
                            ],
                          ),
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

// -----------------------------------------------------------------------------
// TAB 2: USER MANAGEMENT
// -----------------------------------------------------------------------------
class _UserManagementTab extends StatefulWidget {
  const _UserManagementTab({super.key});

  @override
  State<_UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<_UserManagementTab> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _searchResults = [];
  bool _isLoading = false;
  Timer? _debounce; 

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() { _searchResults = []; _isLoading = false; });
      return;
    }

    setState(() => _isLoading = true);
    final cleanQuery = query.trim();

    try {
      final emailFuture = FirebaseFirestore.instance
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: cleanQuery)
          .where('email', isLessThan: '$cleanQuery\uf8ff')
          .limit(10)
          .get();

      final nameFuture = FirebaseFirestore.instance
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: cleanQuery)
          .where('displayName', isLessThan: '$cleanQuery\uf8ff')
          .limit(10)
          .get();

      final results = await Future.wait([emailFuture, nameFuture]);
      final Map<String, DocumentSnapshot> mergedDocs = {};

      for (var doc in results[0].docs) mergedDocs[doc.id] = doc;
      for (var doc in results[1].docs) mergedDocs[doc.id] = doc;

      if (mergedDocs.isEmpty && cleanQuery.length > 20) {
         final docById = await FirebaseFirestore.instance.collection('users').doc(cleanQuery).get();
         if (docById.exists) mergedDocs[docById.id] = docById;
      }

      if (mounted) {
        setState(() { _searchResults = mergedDocs.values.toList(); _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _togglePremium(String userId, bool currentStatus) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({'isPremium': !currentStatus});
    _performSearch(_searchController.text);
  }
  
  void _checkUserCodes(String userId) async {
    final snapshot = await FirebaseFirestore.instance.collection('promo_codes').where('claimedBy', isEqualTo: userId).get();
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Claimed Codes"),
        content: snapshot.docs.isEmpty 
          ? const Text("No codes claimed.") 
          : SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true, 
                children: snapshot.docs.map((doc) => ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green), 
                  title: SelectableText(doc.id) // Copiable inside dialog
                )).toList()
              ),
            ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.grey),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: textColor),
                    decoration: const InputDecoration(
                      hintText: "Search Name, Email or ID...",
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () { _searchController.clear(); _onSearchChanged(""); }),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          if (_isLoading) const CircularProgressIndicator(),
          
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final data = _searchResults[index].data() as Map<String, dynamic>;
                final userId = _searchResults[index].id;
                final isPremium = data['isPremium'] == true;
                final email = data['email'] ?? 'No Email';
                final name = data['displayName'] ?? 'No Name';

                return Card(
                  color: cardColor,
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: isPremium ? Colors.amber : Colors.grey,
                            child: Icon(isPremium ? Icons.star : Icons.person, color: Colors.white),
                          ),
                          title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(email, style: TextStyle(color: Colors.grey[600])),
                              const SizedBox(height: 4),
                              
                              // --- COPIABLE USER ID ---
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: userId));
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User ID Copied")));
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.black38 : Colors.grey[100], 
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.grey.withOpacity(0.3))
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.copy, size: 10, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text("ID: $userId", style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace')),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                             TextButton.icon(
                               icon: const Icon(Icons.history, size: 16),
                               label: const Text("Codes"),
                               onPressed: () => _checkUserCodes(userId),
                             ),
                             Row(
                               children: [
                                 Text(isPremium ? "PREMIUM" : "FREE", 
                                   style: TextStyle(color: isPremium ? Colors.amber : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)
                                 ),
                                 Switch(
                                   value: isPremium,
                                   activeColor: Colors.amber,
                                   onChanged: (val) => _togglePremium(userId, isPremium),
                                 ),
                               ],
                             )
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}