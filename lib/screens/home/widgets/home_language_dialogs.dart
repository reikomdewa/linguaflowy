import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/blocs/vocabulary/vocabulary_bloc.dart';
import 'package:linguaflow/screens/placement_test/placement_test_screen.dart';
import 'package:linguaflow/utils/language_helper.dart';

class HomeLanguageDialogs {
  
  /// 1. Prompts for Native Language (Source)
  /// If [isFirstSetup] is true, it will automatically open the Target Language dialog after selection.
  static void showNativeLanguageSelector(BuildContext context, {bool isFirstSetup = false}) {
    final authState = context.read<AuthBloc>().state;
    String currentNative = 'en'; // default
    if (authState is AuthAuthenticated) {
      currentNative = authState.user.nativeLanguage.isNotEmpty 
          ? authState.user.nativeLanguage 
          : 'en';
    }

    showDialog(
      context: context,
      barrierDismissible: !isFirstSetup, // Force selection if first setup
      builder: (ctx) => AlertDialog(
        title: const Text("Select Native Language"),
        content: SizedBox(
          width: double.maxFinite,
          height: 400, // Limit height
          child: ListView(
            shrinkWrap: true,
            children: LanguageHelper.availableLanguages.entries.map((entry) {
              return RadioListTile<String>(
                title: Row(
                  children: [
                    Text(LanguageHelper.getFlagEmoji(entry.key), style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Text(entry.value),
                  ],
                ),
                value: entry.key,
                groupValue: currentNative,
                onChanged: (val) {
                  if (val != null) {
                    // Update Auth Bloc
                    context.read<AuthBloc>().add(AuthUpdateUser(nativeLanguage: val));
                    Navigator.pop(ctx);
                    
                    // If this is the initial setup, proceed to ask for Target Language
                    if (isFirstSetup) {
                      showTargetLanguageSelector(context, isMandatory: true);
                    }
                  }
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  /// 2. Prompts for Target Language (Learning)
  static void showTargetLanguageSelector(BuildContext context, {bool isMandatory = false}) {
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isDismissible: !isMandatory,
      enableDrag: !isMandatory,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => PopScope(
        canPop: !isMandatory,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  isMandatory ? "What do you want to learn? 🚀" : "Switch Language",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: LanguageHelper.availableLanguages.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = LanguageHelper.availableLanguages.entries.elementAt(index);
                      
                      // Skip if target is same as native (optional logic)
                      if (entry.key == user.nativeLanguage) return const SizedBox.shrink();

                      return ListTile(
                        leading: Text(LanguageHelper.getFlagEmoji(entry.key), style: const TextStyle(fontSize: 32)),
                        title: Text(
                          entry.value,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        onTap: () {
                          // Update Target Language
                          context.read<AuthBloc>().add(AuthTargetLanguageChanged(entry.key));
                          
                          // Trigger Loads
                          context.read<LessonBloc>().add(LessonLoadRequested(user.id, entry.key));
                          context.read<VocabularyBloc>().add(VocabularyLoadRequested(user.id));
                          
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 3. Level Selector
  static void showLevelSelector(BuildContext context, String currentLevel, String langCode) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final List<String> proficiencyLevels = [
      'A1 - Newcomer',
      'A1 - Beginner',
      'A2 - Elementary',
      'B1 - Intermediate',
      'B2 - Upper Intermediate',
      'C1 - Advanced',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white, 
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20))
        ),
        padding: const EdgeInsets.only(top: 16),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: Text("Select Your Level", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black)),
              ),
              Divider(color: Colors.grey.withOpacity(0.2)),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: proficiencyLevels.map((level) {
                      final isSelected = currentLevel == level;
                      return ListTile(
                        leading: Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? Colors.blue : Colors.grey),
                        title: Text(level, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        onTap: () {
                          Navigator.pop(ctx);
                          if (level == currentLevel) return;
                          
                          if (level == 'A1 - Newcomer') {
                            context.read<AuthBloc>().add(AuthLanguageLevelChanged(level));
                          } else {
                            _showPlacementTestConfirmDialog(context, level, langCode);
                          }
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _showPlacementTestConfirmDialog(BuildContext context, String targetLevel, String langCode) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = (context.read<AuthBloc>().state as AuthAuthenticated).user;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text("Change Level?", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Text("You selected $targetLevel. We recommend taking a quick placement test.", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthBloc>().add(AuthLanguageLevelChanged(targetLevel));
            },
            child: const Text("Just switch"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Make sure PlacementTestScreen is imported
              final resultLevel = await Navigator.push(context, MaterialPageRoute(builder: (_) => PlacementTestScreen(
                userId: user.id, 
                nativeLanguage: user.nativeLanguage, 
                targetLanguage: user.currentLanguage, 
                targetLevelToCheck: targetLevel
              )));
              
              if (resultLevel != null && resultLevel is String && context.mounted) {
                context.read<AuthBloc>().add(AuthLanguageLevelChanged(resultLevel));
              }
            },
            child: const Text("Take Test"),
          ),
        ],
      ),
    );
  }
}