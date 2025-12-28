import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_state.dart';
import 'package:linguaflow/models/community_models.dart';
import 'package:linguaflow/models/lesson_model.dart';
import 'package:linguaflow/models/user_model.dart';
import 'package:linguaflow/screens/community/widgets/community_search_delegate.dart';
import 'package:linguaflow/services/community_service.dart';
import 'package:linguaflow/screens/community/widgets/community_lesson_card.dart';
import 'package:linguaflow/screens/community/widgets/forum_post_card.dart';
import 'package:linguaflow/utils/utils.dart'; // Ensure you have this for showCustomSnackBar
import 'package:uuid/uuid.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CommunityService _service = CommunityService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final userState = context.watch<AuthBloc>().state;
    if (userState is! AuthAuthenticated) return const SizedBox.shrink();
    final user = userState.user;

    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              title: Row(
                children: [
                  const Text("Community"),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      user.currentLanguage.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ),
                ],
              ),
              centerTitle: false,
              floating: true,
              pinned: true,
              backgroundColor: bgColor,
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Colors.blueAccent,
                labelColor: Colors.blueAccent,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(text: "Community Lessons"),
                  Tab(text: "Q&A Forum"),
                ],
              ),
              actions: [
                // --- SEARCH ICON ---
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    showSearch(
                      context: context,
                      delegate: CommunitySearchDelegate(
                        currentUser: user,
                        service: _service,
                      ),
                    );
                  },
                ),
              ],
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [_buildLessonFeed(user), _buildForumFeed(user)],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "To share a lesson, go to your Library, open options, and select 'Share to Everyone'.",
                ),
              ),
            );
          } else {
            _showCreatePostDialog(context, user);
          }
        },
        label: Text(
          _tabController.index == 0 ? "Share Lesson" : "Ask Question",
        ),
        icon: Icon(
          _tabController.index == 0 ? Icons.share : Icons.question_answer,
        ),
      ),
    );
  }

  // --- TAB 1: SHARED LESSONS ---
  Widget _buildLessonFeed(UserModel user) {
    return StreamBuilder<List<LessonModel>>(
      stream: _service.getPublicLessons(user.currentLanguage),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            "No shared lessons yet.",
            Icons.library_books_outlined,
          );
        }

        final lessons = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: lessons.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            return CommunityLessonCard(
              lesson: lessons[index],
              currentUser: user,
              service: _service,
            );
          },
        );
      },
    );
  }

  // --- TAB 2: FORUM / Q&A ---
  Widget _buildForumFeed(UserModel user) {
    return StreamBuilder<List<ForumPost>>(
      stream: _service.getForumPosts(user.currentLanguage),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            "No discussions yet. Be the first!",
            Icons.forum_outlined,
          );
        }

        final posts = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            return ForumPostCard(
              post: posts[index],
              currentUser: user,
              service: _service,
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(text, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }

  void _showCreatePostDialog(BuildContext context, UserModel user) {
    final textController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Ask a Question or Share a Tip",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: textController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: "How do you say...?",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        // Assuming you have a standard helper or use the custom one
                        Utils().showCustomSnackBar(
                          context,
                          'Feature coming soon, only text is allowed for now',
                        );
                      },
                      icon: const Icon(Icons.mic, color: Colors.grey),
                    ),
                    IconButton(
                      onPressed: () {
                        Utils().showCustomSnackBar(
                          context,
                          'Feature coming soon, only text is allowed for now',
                        );
                      },
                      icon: const Icon(Icons.image, color: Colors.grey),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () async {
                        if (textController.text.trim().isEmpty) return;

                        final post = ForumPost(
                          id: const Uuid().v4(),
                          authorId: user.id,
                          authorName: user.displayName.isEmpty
                              ? 'User'
                              : user.displayName,
                          authorPhoto: user.photoUrl,
                          content: textController.text.trim(),
                          language: user.currentLanguage,
                          createdAt: DateTime.now(),
                        );

                        Navigator.pop(ctx);
                        await _service.createPost(post);
                      },
                      child: const Text("Post"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
