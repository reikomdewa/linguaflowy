
// File: lib/screens/vocabulary/vocabulary_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/vocabulary/vocabulary_bloc.dart';

class VocabularyScreen extends StatefulWidget {
  @override
  _VocabularyScreenState createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends State<VocabularyScreen> {
  int _selectedStatus = -1; // -1 means all

  @override
  Widget build(BuildContext context) {
    final user = (context.watch<AuthBloc>().state as AuthAuthenticated).user;

    return Scaffold(
      appBar: AppBar(
        title: Text('Vocabulary'),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _selectedStatus == -1,
                  onTap: () => setState(() => _selectedStatus = -1),
                ),
                SizedBox(width: 8),
                _FilterChip(
                  label: 'New',
                  selected: _selectedStatus == 0,
                  color: Colors.blue,
                  onTap: () => setState(() => _selectedStatus = 0),
                ),
                SizedBox(width: 8),
                _FilterChip(
                  label: 'Learning',
                  selected: _selectedStatus == 1,
                  color: Colors.orange,
                  onTap: () => setState(() => _selectedStatus = 1),
                ),
                SizedBox(width: 8),
                _FilterChip(
                  label: 'Known',
                  selected: _selectedStatus == 5,
                  color: Colors.green,
                  onTap: () => setState(() => _selectedStatus = 5),
                ),
              ],
            ),
          ),
          Expanded(
            child: BlocBuilder<VocabularyBloc, VocabularyState>(
              builder: (context, state) {
                if (state is VocabularyInitial) {
                  context
                      .read<VocabularyBloc>()
                      .add(VocabularyLoadRequested(user.id));
                  return Center(child: CircularProgressIndicator());
                }
                if (state is VocabularyLoading) {
                  return Center(child: CircularProgressIndicator());
                }
                if (state is VocabularyLoaded) {
                  var items = state.items;
                  if (_selectedStatus >= 0) {
                    items = items
                        .where((item) => item.status == _selectedStatus)
                        .toList();
                  }

                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.book, size: 100, color: Colors.grey[300]),
                          SizedBox(height: 24),
                          Text(
                            'No vocabulary yet',
                            style: TextStyle(fontSize: 20, color: Colors.grey[600]),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Start reading lessons to build your vocabulary',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Card(
                        margin: EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getStatusColor(item.status),
                            child: Text(
                              item.word[0].toUpperCase(),
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            item.word,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 4),
                              Text(item.translation),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(item.status),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _getStatusLabel(item.status),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '${item.timesEncountered}x',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<int>(
                            onSelected: (status) {
                              context.read<VocabularyBloc>().add(
                                    VocabularyUpdateRequested(
                                      item.copyWith(status: status, lastReviewed: DateTime.now()),
                                    ),
                                  );
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(value: 0, child: Text('New')),
                              PopupMenuItem(value: 1, child: Text('Learning 1')),
                              PopupMenuItem(value: 2, child: Text('Learning 2')),
                              PopupMenuItem(value: 3, child: Text('Learning 3')),
                              PopupMenuItem(value: 4, child: Text('Learning 4')),
                              PopupMenuItem(value: 5, child: Text('Known')),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }
                return Center(child: Text('Something went wrong'));
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 0:
        return Colors.blue;
      case 1:
      case 2:
      case 3:
      case 4:
        return Colors.orange;
      case 5:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(int status) {
    switch (status) {
      case 0:
        return 'New';
      case 1:
      case 2:
      case 3:
      case 4:
        return 'Learning $status';
      case 5:
        return 'Known';
      default:
        return 'Unknown';
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? (color ?? Colors.blue)
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}