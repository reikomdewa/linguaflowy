
// File: lib/screens/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/screens/reader/reader_screen.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = (context.watch<AuthBloc>().state as AuthAuthenticated).user;

    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${user.displayName}!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 24),
            _StatCard(
              title: 'Known Words',
              value: '0',
              icon: Icons.check_circle,
              color: Colors.green,
            ),
            SizedBox(height: 16),
            _StatCard(
              title: 'Learning Words',
              value: '0',
              icon: Icons.school,
              color: Colors.orange,
            ),
            SizedBox(height: 16),
            _StatCard(
              title: 'Lessons Completed',
              value: '0',
              icon: Icons.book,
              color: Colors.blue,
            ),
            SizedBox(height: 32),
            Text(
              'Recent Lessons',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            BlocBuilder<LessonBloc, LessonState>(
              builder: (context, state) {
                if (state is LessonInitial) {
                  context.read<LessonBloc>().add(LessonLoadRequested(user.id));
                  return Center(child: CircularProgressIndicator());
                }
                if (state is LessonLoading) {
                  return Center(child: CircularProgressIndicator());
                }
                if (state is LessonLoaded) {
                  if (state.lessons.isEmpty) {
                    return Center(
                      child: Column(
                        children: [
                          Icon(Icons.library_books, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No lessons yet. Create your first lesson!'),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: state.lessons.take(5).map((lesson) {
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(lesson.language.toUpperCase()),
                          ),
                          title: Text(lesson.title),
                          subtitle: Text('${lesson.progress}% complete'),
                          trailing: Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReaderScreen(lesson: lesson),
                              ),
                            );
                          },
                        ),
                      );
                    }).toList(),
                  );
                }
                return SizedBox();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 40, color: color),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
