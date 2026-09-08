import json
import re
import os

log_dir = "C:/Users/ANTHONETTE/.gemini/antigravity/brain/5b62970f-5e34-4b9a-8b52-0b42738c000a/.system_generated/logs"
transcript_path = os.path.join(log_dir, "transcript_full.jsonl")

# We want to find a tool call to view_file or run_command that outputted the full content of teacher_dashboard.dart
# Or we can find the content before my first modification in this session.
# Let's search backwards.
best_content = None

with open(transcript_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

for line in reversed(lines):
    try:
        data = json.loads(line)
        content = data.get("content", "")
        # Look for the LEARNERS' RECORDS block
        if "const ComicBadgeHeader(title: \"LEARNERS' RECORDS\")," in content and "class TeacherDashboard extends StatefulWidget" in content:
            # This looks like the full file content!
            # Usually it's in the output of a run_command like cat or a view_file response
            if "The command exited with code 0." in content:
                # Extract output
                parts = content.split("Output:\n", 1)
                if len(parts) > 1:
                    best_content = parts[1]
                    break
    except Exception as e:
        pass

if best_content:
    print("Found a candidate for restoration! Length:", len(best_content))
    with open("restored_teacher_dashboard.dart", "w", encoding="utf-8") as f:
        f.write(best_content)
else:
    print("Could not find full content in transcript.")
