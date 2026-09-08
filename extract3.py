import json
import glob

log_dir = "C:/Users/ANTHONETTE/.gemini/antigravity/brain/5b62970f-5e34-4b9a-8b52-0b42738c000a/.system_generated/logs/transcript_full.jsonl"
log_files = glob.glob("C:/Users/ANTHONETTE/.gemini/antigravity/brain/5b62970f-5e34-4b9a-8b52-0b42738c000a/.system_generated/tasks/*.log")

def find_block():
    # first search transcript_full.jsonl
    with open(log_dir, "r", encoding="utf-8") as f:
        for line in f:
            if "LEARNERS' RECORDS" in line and "YOUR CLASSES" in line:
                data = json.loads(line)
                content = data.get('content', '')
                if 'const ComicBadgeHeader(title: "LEARNERS\' RECORDS"),' in content and 'const ComicBadgeHeader(title: "YOUR CLASSES"),' in content:
                    idx1 = content.find('const ComicBadgeHeader(title: "LEARNERS\' RECORDS"),')
                    idx2 = content.find('const ComicBadgeHeader(title: "YOUR CLASSES"),')
                    if idx1 != -1 and idx2 != -1 and idx1 < idx2:
                        return content[idx1:idx2]
    
    # search task logs
    for log in log_files:
        try:
            content = open(log, 'r', encoding='utf-8').read()
            idx1 = content.find('const ComicBadgeHeader(title: "LEARNERS\' RECORDS"),')
            idx2 = content.find('const ComicBadgeHeader(title: "YOUR CLASSES"),')
            if idx1 != -1 and idx2 != -1 and idx1 < idx2:
                return content[idx1:idx2]
        except:
            pass
        try:
            content = open(log, 'r', encoding='utf-16').read()
            idx1 = content.find('const ComicBadgeHeader(title: "LEARNERS\' RECORDS"),')
            idx2 = content.find('const ComicBadgeHeader(title: "YOUR CLASSES"),')
            if idx1 != -1 and idx2 != -1 and idx1 < idx2:
                return content[idx1:idx2]
        except:
            pass

    return None

block = find_block()
if block:
    print("Found block of length:", len(block))
    with open("restored_block.txt", "w", encoding="utf-8") as f:
        f.write(block)
else:
    print("Could not find the block")
