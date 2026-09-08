import re

with open('lib/screens/story_view_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# 1. Update onPageChanged logic
old_onpage = '''                              } else {
                                _setupTargetWords(
                                  (pages[index]['audio_scripts'] is List)
                                      ? (pages[index]['audio_scripts'] as List).join(" ")
                                      : (pages[index]['audio_scripts'] ?? "").toString(),
                                );
                              }'''

new_onpage = '''                              } else {
                                String scriptText = (pages[index]['scripts'] is List)
                                      ? (pages[index]['scripts'] as List).join(" ")
                                      : (pages[index]['scripts'] ?? "").toString();
                                _setupTargetWords(scriptText);
                              }'''

text = text.replace(old_onpage, new_onpage)

# 2. Add fallback in build method if _targetWords is empty
old_build_start = '''    List<dynamic> currentScripts = pages[_currentPage]['scripts'] ?? [];

    return Scaffold('''

new_build_start = '''    List<dynamic> currentScripts = pages[_currentPage]['scripts'] ?? [];
    String fullTargetText = currentScripts.join(" ");
    if (_targetWords.isEmpty && fullTargetText.isNotEmpty) {
      // Must defer state update during build
      Future.microtask(() {
        if (mounted) {
          setState(() {
            _setupTargetWords(fullTargetText);
          });
        }
      });
    }

    return Scaffold('''

text = text.replace(old_build_start, new_build_start)

with open('lib/screens/story_view_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)

print("Fixed target words bug")
