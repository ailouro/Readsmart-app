import json

log_dir = "C:/Users/ANTHONETTE/.gemini/antigravity/brain/5b62970f-5e34-4b9a-8b52-0b42738c000a/.system_generated/logs/transcript_full.jsonl"

with open(log_dir, "r", encoding="utf-8") as f:
    for line in f:
        if "_groupStudentsByClass" in line:
            # Found it
            data = json.loads(line)
            content = data.get('content', '')
            if "_groupStudentsByClass" in content:
                print("FOUND IN CONTENT length:", len(content))
                with open("found_code.txt", "w", encoding="utf-8") as out:
                    out.write(content)
                break
