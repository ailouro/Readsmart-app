import sys

with open("d:/flutter/readsmart/theapp/lib/screens/teacher_dashboard.dart", "r", encoding="utf-8") as f:
    content = f.read()

def remove_method(content, start_str):
    if start_str not in content:
        return content
    
    start_idx = content.find(start_str)
    
    # Simple bracket matching
    bracket_count = 0
    in_bracket = False
    end_idx = -1
    
    for i in range(start_idx, len(content)):
        if content[i] == '{':
            bracket_count += 1
            in_bracket = True
        elif content[i] == '}':
            bracket_count -= 1
        
        if in_bracket and bracket_count == 0:
            end_idx = i + 1
            break
            
    if end_idx != -1:
        return content[:start_idx] + content[end_idx:]
    return content

content = remove_method(content, "Map<String, List<Map<String, dynamic>>> _groupStudentsByClass(List<dynamic> students) {")
content = remove_method(content, "Widget _buildStudentSummaryRow(Map<String, dynamic> student) {")

with open("d:/flutter/readsmart/theapp/lib/screens/teacher_dashboard.dart", "w", encoding="utf-8") as f:
    f.write(content)
    
