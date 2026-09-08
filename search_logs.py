import re
import os
import glob

def find_block(start_str):
    logs = glob.glob("C:/Users/ANTHONETTE/.gemini/antigravity/brain/5b62970f-5e34-4b9a-8b52-0b42738c000a/.system_generated/tasks/*.log")
    for log in logs:
        try:
            content = open(log, 'r', encoding='utf-8').read()
            if start_str in content:
                # We found a log that contains the string!
                # It might be in the Output of a cat / Get-Content command
                return content
        except:
            pass
        
        try:
            content = open(log, 'r', encoding='utf-16').read()
            if start_str in content:
                return content
        except:
            pass
    return None

c = find_block("Map<String, List<Map<String, dynamic>>> _groupStudentsByClass")
if c:
    print("FOUND _groupStudentsByClass")
else:
    print("NOT FOUND")
    
c2 = find_block("const ComicBadgeHeader(title: \"LEARNERS' RECORDS\"),")
if c2:
    print("FOUND LEARNERS RECORDS")
else:
    print("NOT FOUND")
