import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class StoryEditorScreen extends StatefulWidget {
  final dynamic story;
  final String baseUrl;

  const StoryEditorScreen({
    super.key,
    required this.story,
    required this.baseUrl,
  });

  @override
  State<StoryEditorScreen> createState() => _StoryEditorScreenState();
}

class _StoryEditorScreenState extends State<StoryEditorScreen> {
  final PageController _pageController = PageController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  int _currentPage = 0;

  // Uri ng kuwento ('pre_test' o 'post_test')
  String _storyType = 'pre_test';

  // Grade level ng kuwento ('Grade 5' o 'Grade 6') -- null hanggang piliin
  // mismo ng guro; hindi ito dapat basta-basta i-default sa 'Grade 5'.
  String? _gradeLevel;

  // Managed list of text editing controllers for separate script segments
  final List<TextEditingController> _scriptControllers = [];
  bool _isSaving = false;
  bool _isGeneratingVoice = false;
  bool _isPlayingAudio = false;
  List<dynamic> _pages = [];

  @override
  void initState() {
    super.initState();
    _pages = List.from(widget.story['pages'] ?? []);

    // Kunan ang story_type mula sa na-pass na story object, default sa 'pre_test' kapag wala
    final rawType = widget.story['story_type']?.toString();
    if (rawType != null && rawType.isNotEmpty) {
      _storyType = rawType;
    } else {
      _storyType = 'pre_test';
    }

    // Kunan ang grade_level mula sa na-pass na story object -- iwanang
    // null (walang naka-select na pill) kapag wala pang itinakda ang guro,
    // sa halip na basta i-assume na 'Grade 5'.
    final rawGrade = widget.story['grade_level']?.toString();
    _gradeLevel = (rawGrade != null && rawGrade.isNotEmpty) ? rawGrade : null;

    _loadCurrentSlideScript();

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
        });
      }
    });
  }

  void _clearScriptControllers() {
    for (var controller in _scriptControllers) {
      controller.dispose();
    }
    _scriptControllers.clear();
  }

  void _loadCurrentSlideScript() {
    _stopAudio();
    _clearScriptControllers();

    if (_pages.isNotEmpty && _currentPage < _pages.length) {
      var rawScripts = _pages[_currentPage]['audio_scripts'];
      if (rawScripts is List && rawScripts.isNotEmpty) {
        for (var script in rawScripts) {
          final controller = TextEditingController(text: script.toString());
          controller.addListener(_onScriptChanged);
          _scriptControllers.add(controller);
        }
      } else if (rawScripts is String && rawScripts.trim().isNotEmpty) {
        final controller = TextEditingController(text: rawScripts);
        controller.addListener(_onScriptChanged);
        _scriptControllers.add(controller);
      }
    }

    if (_scriptControllers.isEmpty) {
      final controller = TextEditingController();
      controller.addListener(_onScriptChanged);
      _scriptControllers.add(controller);
    }

    if (mounted) setState(() {});
  }

  void _onScriptChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _addScriptSegment() {
    setState(() {
      final controller = TextEditingController();
      controller.addListener(_onScriptChanged);
      _scriptControllers.add(controller);
    });
  }

  void _removeScriptSegment(int index) {
    if (_scriptControllers.length > 1) {
      setState(() {
        _scriptControllers[index].removeListener(_onScriptChanged);
        _scriptControllers[index].dispose();
        _scriptControllers.removeAt(index);
      });
    }
  }

  List<String> _getScriptsList() {
    return _scriptControllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
  }

  Future<void> _stopAudio() async {
    if (_isPlayingAudio) {
      await _audioPlayer.stop();
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
        });
      }
    }
  }

  // Function para i-update ang story_type at/o grade_level sa backend.
  // NOTE: dating tinatawagan nito ang `PUT /api/stories/{id}` na wala palang
  // naka-register na route sa backend (405 error). Ginawa itong tumugma sa
  // parehong convention ng `update-script` endpoint (na gumagana) --
  // `/api/stories/{id}/update-meta` -- kaya kailangan itong idagdag din sa
  // routes/api.php at StoryController.php sa backend.
  Future<void> _updateStoryMeta({String? newType, String? newGrade}) async {
    final String effectiveType = newType ?? _storyType;
    final String? effectiveGrade = newGrade ?? _gradeLevel;

    if (effectiveType == _storyType && effectiveGrade == _gradeLevel) return;

    final String previousType = _storyType;
    final String? previousGrade = _gradeLevel;

    setState(() {
      _storyType = effectiveType;
      _gradeLevel = effectiveGrade;
    });

    try {
      final url = Uri.parse(
        "${widget.baseUrl}/api/stories/${widget.story['id']}/update-meta",
      );
      final response = await http.put(
        url,
        headers: {
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "69420",
        },
        body: jsonEncode({
          "story_type": effectiveType,
          "grade_level": effectiveGrade,
        }),
      );

      if (response.statusCode == 200) {
        widget.story['story_type'] = effectiveType;
        widget.story['grade_level'] = effectiveGrade;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                newType != null
                    ? "Na-update ang Story Type sa ${effectiveType == 'post_test' ? 'Post Test' : 'Pre Test'}! 🎯"
                    : "Na-update ang Grade Level sa $effectiveGrade! 🎯",
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception("Failed to update story info. Status: ${response.statusCode}");
      }
    } catch (e) {
      // I-revert ang UI kapag nabigo ang save sa backend
      setState(() {
        _storyType = previousType;
        _gradeLevel = previousGrade;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error sa pag-update ng Story Info: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _scanTextFromImage() async {
    if (_pages.isEmpty || _currentPage >= _pages.length) return;

    String rawPath = _pages[_currentPage]['image_path'] ?? '';
    if (rawPath.startsWith('public/')) {
      rawPath = rawPath.replaceFirst('public/', '');
    }
    String cleanBaseUrl = widget.baseUrl.endsWith('/api')
        ? widget.baseUrl.substring(0, widget.baseUrl.length - 4)
        : widget.baseUrl;
    String imageUrl = "$cleanBaseUrl/api/get-image?path=$rawPath";

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Downloading image for scanning...")),
        );
      }

      final response = await http.get(
        Uri.parse(imageUrl),
        headers: {"ngrok-skip-browser-warning": "69420"},
      );

      if (response.statusCode != 200) {
        throw Exception(
          "Failed to download image. Status: ${response.statusCode}",
        );
      }

      if (kIsWeb) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Extracting text via Cloud OCR...")),
          );
        }
        final String base64Img = base64Encode(response.bodyBytes);
        final ocrResponse = await http.post(
          Uri.parse('https://api.ocr.space/parse/image'),
          body: {
            'apikey': 'helloworld',
            'language': 'eng',
            'base64Image': 'data:image/jpeg;base64,$base64Img',
          },
        );

        if (ocrResponse.statusCode == 200) {
          final data = jsonDecode(ocrResponse.body);
          if (data['IsErroredOnProcessing'] == false &&
              data['ParsedResults'] != null) {
            String extracted = "";
            for (var result in data['ParsedResults']) {
              extracted += (result['ParsedText'] ?? "") + "\n";
            }
            if (mounted) {
              setState(() {
                if (_scriptControllers.isNotEmpty) {
                  _scriptControllers[0].text = extracted.trim();
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Text extracted successfully!")),
              );
            }
          } else {
            throw Exception("Could not read text from image.");
          }
        } else {
          throw Exception("Cloud OCR failed (${ocrResponse.statusCode})");
        }
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/temp_ocr_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(response.bodyBytes);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Extracting text...")));
      }

      final inputImage = InputImage.fromFilePath(file.path);
      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );

      if (mounted) {
        setState(() {
          if (_scriptControllers.isNotEmpty) {
            _scriptControllers[0].text = recognizedText.text;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Text extracted successfully!")),
        );
      }

      textRecognizer.close();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to extract text: $e")));
      }
    }
  }

  void _goToPreviousSlide() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNextSlide() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _toggleAudioPlayback() async {
    if (_isPlayingAudio) {
      await _audioPlayer.pause();
      setState(() {
        _isPlayingAudio = false;
      });
    } else {
      try {
        String cleanBaseUrl = widget.baseUrl.endsWith('/api')
            ? widget.baseUrl.substring(0, widget.baseUrl.length - 4)
            : widget.baseUrl;

        final audioUri = Uri.parse("$cleanBaseUrl/api/get-audio").replace(
          queryParameters: {
            "story_id": widget.story['id'].toString(),
            "page_index": _currentPage.toString(),
            "script_index": "0",
          },
        );

        setState(() {
          _isPlayingAudio = true;
        });

        final response = await http.get(
          audioUri,
          headers: const {"ngrok-skip-browser-warning": "69420"},
        );

        if (!mounted) return;

        if (response.statusCode == 200) {
          await _audioPlayer.play(BytesSource(response.bodyBytes));
        } else if (response.statusCode == 404) {
          throw Exception(
            "Audio not found on server for Slide ${_currentPage + 1}. Click 'Create Voice' first!",
          );
        } else {
          throw Exception(
            "Failed to download audio. Status: ${response.statusCode}",
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isPlayingAudio = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll("Exception: ", "")),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _saveSlideScript() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final int slideIndex = _currentPage;
      final scripts = _getScriptsList();

      final url = Uri.parse(
        "${widget.baseUrl}/api/stories/${widget.story['id']}/slides/$slideIndex/update-script",
      );

      final response = await http.put(
        url,
        headers: {
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "69420",
        },
        body: jsonEncode({"scripts": scripts}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _pages[_currentPage]['audio_scripts'] = scripts;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Slide ${_currentPage + 1} scripts saved! 💾"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception(
          "Failed to save script. Status: ${response.statusCode}",
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving script: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _generateAiVoice() async {
    final scripts = _getScriptsList();
    if (scripts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please type at least one script segment before generating AI voice! ⚠️",
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isGeneratingVoice = true;
    });

    try {
      final int slideIndex = _currentPage;

      final url = Uri.parse(
        "${widget.baseUrl}/api/stories/${widget.story['id']}/slides/$slideIndex/generate-tts",
      );

      int failedCount = 0;
      String? firstErrorDetail;
      for (int i = 0; i < scripts.length; i++) {
        final response = await http.post(
          url,
          headers: {
            "Content-Type": "application/json",
            "ngrok-skip-browser-warning": "69420",
          },
          body: jsonEncode({
            "text": scripts[i],
            "script_index": i,
            "lang": "tl",
          }),
        );
        if (response.statusCode != 200) {
          failedCount++;
          firstErrorDetail ??=
              "${response.statusCode}: ${response.body}".trim();
        }
      }

      if (!mounted) return;

      if (failedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Voice created for Slide ${_currentPage + 1}! Press 'Play Voice Preview' to test. 🤖🎙️",
            ),
            backgroundColor: Colors.blueAccent,
          ),
        );
      } else {
        String detail = firstErrorDetail ?? "unknown error";
        if (detail.length > 300) detail = "${detail.substring(0, 300)}...";
        throw Exception(
          "$failedCount of ${scripts.length} script segment(s) failed to generate voice.\n$detail",
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error generating voice: $e"),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingVoice = false;
        });
      }
    }
  }

  // Widget para sa Story Type selection
  Widget _storyTypeSelector() {
    Widget buildOption(String value, String label, IconData icon) {
      final bool selected = _storyType == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => _updateStoryMeta(newType: value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFDE047) : Colors.grey[800],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? Colors.amberAccent : Colors.grey[700]!,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: selected ? Colors.black : Colors.white70,
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: selected ? Colors.black : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "STORY TYPE:",
          style: TextStyle(
            color: Colors.amberAccent,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            buildOption('pre_test', "Pre Test", Icons.edit_note_rounded),
            const SizedBox(width: 10),
            buildOption('post_test', "Post Test", Icons.fact_check_rounded),
          ],
        ),
      ],
    );
  }

  // Widget para sa Grade Level selection (Grade 5 / Grade 6) -- teachers
  // label this themselves, shown as a badge on the library cover later.
  Widget _gradeLevelSelector() {
    Widget buildOption(String value) {
      final bool selected = _gradeLevel == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => _updateStoryMeta(newGrade: value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFDE047) : Colors.grey[800],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? Colors.amberAccent : Colors.grey[700]!,
                width: 2,
              ),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: selected ? Colors.black : Colors.white70,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "GRADE LEVEL:",
          style: TextStyle(
            color: Colors.amberAccent,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            buildOption('Grade 5'),
            const SizedBox(width: 10),
            buildOption('Grade 6'),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _clearScriptControllers();
    _audioPlayer.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // DESKTOP / LAPTOP LAYOUT (SIDE-BY-SIDE 2 COLUMNS)
  // ---------------------------------------------------------------------------
  Widget _buildDesktopLayout(String cleanBaseUrl, String combinedText) {
    return Row(
      children: [
        // LEFT COLUMN: SLIDE PREVIEW & NAVIGATION (50% WIDTH)
        Expanded(
          flex: 5,
          child: Container(
            color: const Color(0xFF141414),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // 1. QUICK JUMP SLIDE CHIPS (TOP)
                Container(
                  height: 44,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _pages.length,
                    itemBuilder: (context, idx) {
                      bool isSelected = idx == _currentPage;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text("Slide ${idx + 1}"),
                          selected: isSelected,
                          selectedColor: Colors.amber[700],
                          backgroundColor: Colors.grey[850],
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              _pageController.animateToPage(
                                idx,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),

                // 2. SLIDE IMAGE & SUBTITLE OVERLAY PREVIEW
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[800]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _pages.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                        _loadCurrentSlideScript();
                      },
                      itemBuilder: (context, index) {
                        String pageImagePath =
                            _pages[index]['image_path'] ?? "";
                        String imageUrl =
                            "$cleanBaseUrl/api/get-image?path=$pageImagePath";

                        return Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Center(
                              child: Image.network(
                                imageUrl,
                                headers: const {
                                  "ngrok-skip-browser-warning": "69420",
                                },
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (c, o, s) => Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(
                                      Icons.image_not_supported_outlined,
                                      color: Colors.white38,
                                      size: 64,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      "Image preview unavailable",
                                      style: TextStyle(color: Colors.white38),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (combinedText.isNotEmpty)
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.all(16),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.amberAccent.withOpacity(0.4),
                                  ),
                                ),
                                child: Text(
                                  combinedText,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 3. PREVIOUS / NEXT SLIDE NAVIGATION BAR
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF222222),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed:
                            _currentPage > 0 ? _goToPreviousSlide : null,
                        icon: const Icon(Icons.arrow_back_ios, size: 14),
                        label: const Text("Previous"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[800],
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[900],
                        ),
                      ),
                      Text(
                        "Slide ${_currentPage + 1} of ${_pages.length}",
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _currentPage < _pages.length - 1
                            ? _goToNextSlide
                            : null,
                        icon: const Icon(Icons.arrow_forward_ios, size: 14),
                        label: const Text("Next"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[800],
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[900],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // DIVIDER
        Container(width: 1, color: Colors.grey[800]),

        // RIGHT COLUMN: EDITING & CONTROL PANEL (50% WIDTH)
        Expanded(
          flex: 5,
          child: Container(
            color: const Color(0xFF1E1E1E),
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SECTION TITLE
                  Row(
                    children: [
                      const Icon(
                        Icons.edit_note_rounded,
                        color: Colors.amberAccent,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Slide ${_currentPage + 1} Editor",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // STORY TYPE SELECTOR CARD
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF282828),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _storyTypeSelector(),
                        const SizedBox(height: 16),
                        _gradeLevelSelector(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // SCRIPT & TEXT EDITING CARD
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF282828),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "SCRIPTS / TEXT SEGMENTS",
                              style: TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  tooltip: "Extract Text from Image (OCR)",
                                  icon: const Icon(
                                    Icons.document_scanner,
                                    color: Colors.blueAccent,
                                  ),
                                  onPressed: _scanTextFromImage,
                                ),
                                IconButton(
                                  tooltip: "Add Text Segment",
                                  icon: const Icon(
                                    Icons.add_circle,
                                    color: Colors.greenAccent,
                                  ),
                                  onPressed: _addScriptSegment,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // DYNAMIC SCRIPT FIELDS LIST
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _scriptControllers.length,
                          itemBuilder: (context, idx) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12.0),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E1E),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Segment #${idx + 1}",
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (_scriptControllers.length > 1)
                                        GestureDetector(
                                          onTap: () =>
                                              _removeScriptSegment(idx),
                                          child: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.redAccent,
                                            size: 18,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _scriptControllers[idx],
                                    maxLines: null,
                                    minLines: 2,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: "Enter story text here...",
                                      hintStyle: TextStyle(
                                        color: Colors.white30,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ACTIONS CARD (PLAY / SAVE / CREATE VOICE)
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isPlayingAudio
                                ? Colors.orange[800]
                                : Colors.teal[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: Icon(
                            _isPlayingAudio ? Icons.pause : Icons.play_arrow,
                          ),
                          label: Text(
                            _isPlayingAudio
                                ? "Pause Audio Preview"
                                : "Play Voice Preview",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          onPressed: _isSaving || _isGeneratingVoice
                              ? null
                              : _toggleAudioPlayback,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber[700],
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(
                                _isSaving ? "Saving..." : "Save Texts",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              onPressed: _isSaving || _isGeneratingVoice
                                  ? null
                                  : _saveSlideScript,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[700],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: _isGeneratingVoice
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.record_voice_over),
                              label: Text(
                                _isGeneratingVoice
                                    ? "Creating..."
                                    : "Create Voices",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              onPressed: _isSaving || _isGeneratingVoice
                                  ? null
                                  : _generateAiVoice,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // MOBILE LAYOUT (SINGLE COLUMN FALLBACK FOR SMALL SCREENS)
  // ---------------------------------------------------------------------------
  Widget _buildMobileLayout(String cleanBaseUrl, String combinedText) {
    return Column(
      children: [
        // 1. TOP SLIDE NAVIGATION CONTROLS
        Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _currentPage > 0 ? _goToPreviousSlide : null,
                icon: const Icon(Icons.arrow_back_ios),
                color:
                    _currentPage > 0 ? Colors.amberAccent : Colors.grey[700],
              ),
              Text(
                "Editing Slide ${_currentPage + 1} of ${_pages.length}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              IconButton(
                onPressed:
                    _currentPage < _pages.length - 1 ? _goToNextSlide : null,
                icon: const Icon(Icons.arrow_forward_ios),
                color: _currentPage < _pages.length - 1
                    ? Colors.amberAccent
                    : Colors.grey[700],
              ),
            ],
          ),
        ),

        // 2. QUICK JUMP SLIDE CHIPS
        Container(
          height: 48,
          color: Colors.grey[850],
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _pages.length,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemBuilder: (context, idx) {
              bool isSelected = idx == _currentPage;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text("Slide ${idx + 1}"),
                  selected: isSelected,
                  selectedColor: Colors.amber[700],
                  backgroundColor: Colors.grey[800],
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      _pageController.animateToPage(
                        idx,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                ),
              );
            },
          ),
        ),

        // 3. SLIDE IMAGE & SUBTITLE PREVIEW AREA
        Expanded(
          flex: 2,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            scrollBehavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {
                PointerDeviceKind.mouse,
                PointerDeviceKind.touch,
                PointerDeviceKind.trackpad,
                PointerDeviceKind.stylus,
              },
            ),
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
              _loadCurrentSlideScript();
            },
            itemBuilder: (context, index) {
              String pageImagePath = _pages[index]['image_path'] ?? "";
              String imageUrl =
                  "$cleanBaseUrl/api/get-image?path=$pageImagePath";

              return Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Image.network(
                    imageUrl,
                    headers: const {
                      "ngrok-skip-browser-warning": "69420",
                    },
                    fit: BoxFit.contain,
                    width: double.infinity,
                    errorBuilder: (c, o, s) => const Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                  if (combinedText.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.amberAccent.withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        combinedText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),

        // 4. BOTTOM EDITING CONTROLS
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.black,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _storyTypeSelector(),
                  const SizedBox(height: 16),
                  _gradeLevelSelector(),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "SCRIPTS / TEXTS FOR SLIDE ${_currentPage + 1}:",
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            tooltip: "Extract Text from Image",
                            icon: const Icon(
                              Icons.document_scanner,
                              color: Colors.blueAccent,
                            ),
                            onPressed: _scanTextFromImage,
                          ),
                          IconButton(
                            tooltip: "Add Text Segment",
                            icon: const Icon(
                              Icons.add_circle,
                              color: Colors.greenAccent,
                            ),
                            onPressed: _addScriptSegment,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _scriptControllers.length,
                    itemBuilder: (context, idx) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _scriptControllers[idx],
                                maxLines: null,
                                style: const TextStyle(
                                  color: Colors.white,
                                ),
                                decoration: InputDecoration(
                                  hintText: "Text Segment ${idx + 1}...",
                                  hintStyle: const TextStyle(
                                    color: Colors.white30,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[800],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            if (_scriptControllers.length > 1)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => _removeScriptSegment(idx),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPlayingAudio
                          ? Colors.orange[800]
                          : Colors.teal[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: Icon(
                      _isPlayingAudio ? Icons.pause : Icons.play_arrow,
                    ),
                    label: Text(
                      _isPlayingAudio ? "Pause Audio" : "Play Voice Preview",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _isSaving || _isGeneratingVoice
                        ? null
                        : _toggleAudioPlayback,
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber[700],
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(
                            _isSaving ? "Saving..." : "Save Texts",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: _isSaving || _isGeneratingVoice
                              ? null
                              : _saveSlideScript,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: _isGeneratingVoice
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.record_voice_over),
                          label: Text(
                            _isGeneratingVoice ? "Creating..." : "Create Voices",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: _isSaving || _isGeneratingVoice
                              ? null
                              : _generateAiVoice,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    String cleanBaseUrl = widget.baseUrl.endsWith('/api')
        ? widget.baseUrl.substring(0, widget.baseUrl.length - 4)
        : widget.baseUrl;

    String combinedText = _scriptControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .join("\n\n");

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          "Edit: ${widget.story['title'] ?? 'Story'}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, true);
          },
        ),
      ),
      body: _pages.isEmpty
          ? const Center(
              child: Text(
                "No slides to edit.",
                style: TextStyle(color: Colors.white),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                // Pinapagana ang side-by-side layout kapag nasa laptop/desktop width (850px at pataas)
                if (constraints.maxWidth >= 850) {
                  return _buildDesktopLayout(cleanBaseUrl, combinedText);
                } else {
                  return _buildMobileLayout(cleanBaseUrl, combinedText);
                }
              },
            ),
    );
  }
}
