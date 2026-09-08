import re

with open('lib/screens/story_view_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Revert accuracy back to 92.0 ONLY in _saveFinalProgress
# Let's find _saveFinalProgress
idx = content.find('Future<void> _saveFinalProgress() async {')
if idx != -1:
    end_idx = content.find('}', idx)
    method_content = content[idx:end_idx+200]
    new_method = method_content.replace('"oral_fluency_accuracy": accuracy,', '"oral_fluency_accuracy": 92.0,')
    content = content[:idx] + new_method + content[idx+len(method_content):]
    
    with open('lib/screens/story_view_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print("Fixed")
else:
    print("Not found")

