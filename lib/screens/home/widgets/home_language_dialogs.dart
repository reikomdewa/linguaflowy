import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linguaflow/blocs/auth/auth_bloc.dart';
import 'package:linguaflow/blocs/lesson/lesson_bloc.dart';
import 'package:linguaflow/blocs/vocabulary/vocabulary_bloc.dart';
import 'package:linguaflow/screens/placement_test/placement_test_screen.dart';
import 'package:linguaflow/utils/language_helper.dart';

class HomeLanguageDialogs {
  
  /// 1. Native Language Selector
  /// NOW WITH A CONFIRM BUTTON so users can select the default English.
  static void showNativeLanguageSelector(BuildContext context, {bool isFirstSetup = false}) {
    final authState = context.read<AuthBloc>().state;
    
    // 1. Determine initial value
    String currentSelection = 'en'; 
    if (authState is AuthAuthenticated && authState.user.nativeLanguage.isNotEmpty) {
      currentSelection = authState.user.nativeLanguage;
    }

    showDialog(
      context: context,
      barrierDismissible: !isFirstSetup, // Prevent closing without selection on setup
      builder: (ctx) {
        // 2. Use StatefulBuilder to manage the radio button state INSIDE the dialog
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("What language do you speak?"),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        shrinkWrap: true,
                        children: LanguageHelper.availableLanguages.entries.map((entry) {
                          return RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            title: Row(
                              children: [
                                Text(LanguageHelper.getFlagEmoji(entry.key), style: const TextStyle(fontSize: 24)),
                                const SizedBox(width: 12),
                                Text(entry.value),
                              ],
                            ),
                            value: entry.key,
                            groupValue: currentSelection,
                            // Update local dialog state when clicked
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => currentSelection = val);
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                // 3. The Confirm Button (Works even if 'en' is default)
                ElevatedButton(
                  onPressed: () {
                    // Update Auth Bloc
                    context.read<AuthBloc>().add(AuthUpdateUser(nativeLanguage: currentSelection));
                    Navigator.pop(ctx);
                    
                    // Proceed to Target Language if this is onboarding
                    if (isFirstSetup) {
                      showTargetLanguageSelector(context, isMandatory: true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("Continue"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 2. Target Language Selector (What to learn)
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
          height: MediaQuery.of(context).size.height * 0.75,
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
                if(isMandatory)
                   Padding(
                     padding: const EdgeInsets.all(8.0),
                     child: Text(
                       "We will translate content to ${LanguageHelper.getLanguageName(user.nativeLanguage)}", 
                       style: const TextStyle(color: Colors.grey, fontSize: 14),
                     ),
                   ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: LanguageHelper.availableLanguages.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = LanguageHelper.availableLanguages.entries.elementAt(index);
                      
                      // Don't show the language they already speak (native)
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
                          // Standard "Tap to select" works fine here for a list
                          context.read<AuthBloc>().add(AuthTargetLanguageChanged(entry.key));
                          
                          // Trigger Data Loads
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

  /// 3. Level Selector (Unchanged logic, just keeping it handy)
  static void showLevelSelector(BuildContext context, String currentLevel, String langCode) {
    // ... (Same as previous code) ...
    // Keeping this concise for this answer, use the previous version of this method
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<String> proficiencyLevels = [
      'A1 - Newcomer', 'A1 - Beginner', 'A2 - Elementary',
      'B1 - Intermediate', 'B2 - Upper Intermediate', 'C1 - Advanced',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.only(top: 16),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
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
                          if (level != currentLevel) {
                            if (level == 'A1 - Newcomer') {
                              context.read<AuthBloc>().add(AuthLanguageLevelChanged(level));
                            } else {
                              _showPlacementTestConfirmDialog(context, level, langCode);
                            }
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