import re
content = open('lib/screens/teacher_dashboard.dart', 'r', encoding='utf-8').read()

row_block = """                    Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  
"""

# Let's find this row_block and remove it
if row_block in content:
    content = content.replace(row_block, "")
    print("REMOVED row_block")

# Now let's find `const ComicBadgeHeader(title: "YOUR CLASSES"),` and insert the row block before it
target = '                      const ComicBadgeHeader(title: "YOUR CLASSES"),'
if target in content:
    content = content.replace(target, row_block + target)
    print("INSERTED row_block")
    
open('lib/screens/teacher_dashboard.dart', 'w', encoding='utf-8').write(content)
