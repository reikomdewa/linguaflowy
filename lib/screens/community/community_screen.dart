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
import 'package:linguaflow/utils/auth_guard.dart';
import 'package:linguaflow/utils/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  // Default language for guests if no preference is saved locally
  String _guestLanguage = 'en';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadGuestLanguage();
  }

  Future<void> _loadGuestLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('guest_language_code');
    if (savedLang != null && mounted) {
      setState(() {
        _guestLanguage = savedLang;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;

    final UserModel? user = (authState is AuthAuthenticated)
        ? authState.user
        : null;

    final String currentLanguage = user?.currentLanguage ?? _guestLanguage;

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
                      color: Colors.blueAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      currentLanguage.toUpperCase(),
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
          children: [
            _buildLessonFeed(user, currentLanguage),
            _buildForumFeed(user, currentLanguage),
          ],
        ),
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _tabController,
        builder: (context, child) {
          return _tabController.index == 1
              ? FloatingActionButton.extended(
                  onPressed: () {
                    AuthGuard.run(
                      context,
                      onAuthenticated: () {
                        if (user != null) {
                          _showCreatePostDialog(context, user);
                        }
                      },
                    );
                  },
                  label: const Text("Ask Question"),
                  icon: const Icon(Icons.question_answer),
                )
              : const SizedBox.shrink();
        },
      ),
    );
  }

  // --- TAB 1: SHARED LESSONS (RESPONSIVE) ---
  Widget _buildLessonFeed(UserModel? user, String language) {
    return StreamBuilder<List<LessonModel>>(
      stream: _service.getPublicLessons(language),
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

        return LayoutBuilder(
          builder: (context, constraints) {
            // Check for Desktop width
            final bool isDesktop = constraints.maxWidth > 750;

            if (isDesktop) {
              return GridView.builder(
                padding: const EdgeInsets.all(24),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 450, // Card max width
                  mainAxisExtent: 320, // Fixed height for consistency
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                ),
                itemCount: lessons.length,
                itemBuilder: (context, index) {
                  return CommunityLessonCard(
                    lesson: lessons[index],
                    currentUser: user,
                    service: _service,
                  );
                },
              );
            }

            // Mobile View (List)
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
      },
    );
  }

  // --- TAB 2: FORUM / Q&A (RESPONSIVE) ---
  Widget _buildForumFeed(UserModel? user, String language) {
    return StreamBuilder<List<ForumPost>>(
      stream: _service.getForumPosts(language),
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

        return LayoutBuilder(
          builder: (context, constraints) {
            final bool isDesktop = constraints.maxWidth > 750;

            if (isDesktop) {
              return GridView.builder(
                padding: const EdgeInsets.all(24),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 450,
                  // Forum posts are usually shorter text, but let's give them room
                  mainAxisExtent: 220,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                ),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  return ForumPostCard(
                    post: posts[index],
                    currentUser: user,
                    service: _service,
                  );
                },
              );
            }

            // Mobile View
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
