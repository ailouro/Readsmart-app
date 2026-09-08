import re

with open('lib/screens/story_view_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

def_method = '''
  void _showWordDefinition(String word) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.5,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(word, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 20),
            const Text("Definition not found", style: TextStyle(color: Colors.grey)),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF44336)),
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Close", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
'''

# Insert it before Widget build(BuildContext context)
idx = text.find('  @override\n  Widget build(BuildContext context) {')
text = text[:idx] + def_method + '\n' + text[idx:]

with open('lib/screens/story_view_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)

print("Added _showWordDefinition")
