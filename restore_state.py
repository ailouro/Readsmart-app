import re

with open('lib/screens/story_view_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# 1. Add page cache variables
cache_vars = '''
  // Page State Caching
  final Map<int, List<WordStatus>> _pageTargetWords = {};
  final Map<int, int> _pageCurrentWordIndex = {};
  final Map<int, bool> _pageAssessmentPassed = {};
'''
text = text.replace('  bool _isAssessmentPassed = false;', '  bool _isAssessmentPassed = false;\n' + cache_vars)

# 2. Fix SpeechListenOptions (which I also lost)
text = text.replace('pauseFor: const Duration(seconds: 5),', 'listenOptions: stt.SpeechListenOptions(pauseFor: const Duration(seconds: 5)),')

with open('lib/screens/story_view_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)

print("Restored state vars and speech options")
