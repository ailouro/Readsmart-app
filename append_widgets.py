import re

widgets = '''
class ComicSunburstPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    import_math(); // just to avoid import dart:math
  }
}
'''
# Actually, I should just write them properly and append to the file!
