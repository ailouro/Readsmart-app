import re

file_path = r'd:\flutter\readsmart\theapp\lib\screens\story_view_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add _readingStartTime and _totalWordsInStory
insertion = """  bool _isGenerating = false;
  DateTime? _readingStartTime;
  int _totalWordsInStory = 0;"""

content = content.replace("  bool _isGenerating = false;", insertion)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("done adding variables")
