import re

with open('lib/screens/story_view_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

state_vars = '''
  bool _isGenerating = false;
  DateTime? _readingStartTime;
  int _totalWordsInStory = 0;
'''
text = text.replace('  bool _isAssessmentPassed = false;', '  bool _isAssessmentPassed = false;\n' + state_vars)

with open('lib/screens/story_view_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)

print("Restored readingStartTime and totalWordsInStory")
