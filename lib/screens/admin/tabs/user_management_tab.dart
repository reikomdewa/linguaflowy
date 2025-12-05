import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class UserManagementTab extends StatefulWidget {
  const UserManagementTab({super.key});

  @override
  State<UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<UserManagementTab> {
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
      // Search by Email
      final emailFuture = FirebaseFirestore.instance
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: cleanQuery)
          .where('email', isLessThan: '$cleanQuery\uf8ff')
          .limit(10)
          .get();

      // Search by Display Name
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

      // Special Case: specific User ID search (IDs are usually 20+ chars)
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
    // Refresh the search result to show new status
    _performSearch(_searchController.text);
  }
  
  void _checkUserCodes(String userId) async {
    final snapshot = await FirebaseFirestore.instance.collection('promo_codes').where('claimedBy', isEqualTo: userId).get();
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Claimed Codes History"),
        content: snapshot.docs.isEmpty 
          ? const Text("No codes claimed by this user.") 
          : SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: snapshot.docs.map((doc) => ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green), 
                  title: Text(doc.id, style: const TextStyle(fontFamily: 'monospace')),
                  onTap: () {
                     Clipboard.setData(ClipboardData(text: doc.id));
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Code Copied")));
                  },
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
          // Search Bar
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
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey), 
                    onPressed: () { _searchController.clear(); _onSearchChanged(""); }
                  ),
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
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: userId));
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User ID Copied")));
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: isDark ? Colors.black38 : Colors.grey[100], borderRadius: BorderRadius.circular(4)),
                                  child: Text("ID: $userId", style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace')),
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