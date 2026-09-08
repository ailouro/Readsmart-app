import re

with open('lib/screens/story_view_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# We need to find the rrow_forward section which is broken.
# The broken section looks like:
'''
                              child: IconButton(
                                icon: const Icon(
                                  Icons.arrow_forward,
                                  color: Colors.white,
                                ),
                      // CLOSE BUTTON (X)
'''
# We will replace it with the correct closing brackets for the arrow_forward button,
# AND THEN the Positioned for the CLOSE BUTTON.

broken_str = '''                              child: IconButton(
                                icon: const Icon(
                                  Icons.arrow_forward,
                                  color: Colors.white,
                                ),
                      // CLOSE BUTTON (X)'''

fixed_str = '''                              child: IconButton(
                                icon: const Icon(
                                  Icons.arrow_forward,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      // CLOSE BUTTON (X)'''

if broken_str in text:
    text = text.replace(broken_str, fixed_str)
    with open('lib/screens/story_view_screen.dart', 'w', encoding='utf-8') as f:
        f.write(text)
    print('Fixed the broken IconButton and Positioned block.')
else:
    print('Could not find the broken string.')

