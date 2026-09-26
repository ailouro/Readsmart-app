import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../services/config.dart';
import '../services/cloudinary_service.dart';
import '../widgets/guide_comic_background.dart';

// Helper model para pagsamahin ang image file, bytes, at multiple script controllers
class SlideItem {
  final XFile file;
  final Uint8List bytes;
  final List<TextEditingController> scriptControllers;

  SlideItem({
    required this.file,
    required this.bytes,
    List<TextEditingController>? scriptControllers,
  }) : scriptControllers = scriptControllers ?? [TextEditingController()];

  void addScript() {
    scriptControllers.add(TextEditingController());
  }

  void removeScript(int index) {
    if (scriptControllers.length > 1) {
      scriptControllers[index].dispose();
      scriptControllers.removeAt(index);
    }
  }

  List<String> get scriptsList {
    return scriptControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  void dispose() {
    for (var controller in scriptControllers) {
      controller.dispose();
    }
  }
}

class QuizQuestion {
  final TextEditingController questionController = TextEditingController();
  final List<TextEditingController> optionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  int correctAnswerIndex = 0;
}

class UploadStoryScreen extends StatefulWidget {
  const UploadStoryScreen({super.key});

  @override
  State<UploadStoryScreen> createState() => _UploadStoryScreenState();
}

class _UploadStoryScreenState extends State<UploadStoryScreen> {
  final ImagePicker _picker = ImagePicker();

  XFile? _coverImage;
  Uint8List? _coverBytes;

  final List<SlideItem> _slides = [];
  final List<QuizQuestion> _quizQuestions = [];

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  // Which library shelf this story belongs to -- shown to the teacher as
  // two separate sections ("Pre Test" / "Post Test") in the Library tab.
  String _storyType = 'pre_test';

  // Grade level (Grade 2 - Grade 7, the Phil-IRI graded-passage range) and
  // Passage Set (A-D) -- left null until the teacher picks them; a story
  // can't be assigned to a student's assessment without both.
  String? _gradeLevel;
  String? _setLetter;

  static const List<String> _availableGrades = [
    'Grade 2',
    'Grade 3',
    'Grade 4',
    'Grade 5',
    'Grade 6',
    'Grade 7',
  ];
  static const List<String> _availableSets = [
    'Set A',
    'Set B',
    'Set C',
    'Set D',
  ];

  bool _isUploading = false;
  String _uploadStatus = "";

  void _addQuizQuestion() {
    setState(() {
      _quizQuestions.add(QuizQuestion());
    });
  }

  void _removeQuizQuestion(int index) {
    setState(() {
      _quizQuestions[index].questionController.dispose();
      for (var ctrl in _quizQuestions[index].optionControllers) {
        ctrl.dispose();
      }
      _quizQuestions.removeAt(index);
    });
  }

  Future<void> _pickCover() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _coverImage = image;
        _coverBytes = bytes;
      });
    }
  }

  Future<void> _pickPages() async {
    final List<XFile> images = await _picker.pickMultiImage(imageQuality: 50);
    if (images.isNotEmpty) {
      List<SlideItem> newSlides = [];
      for (var file in images) {
        final bytes = await file.readAsBytes();
        newSlides.add(SlideItem(file: file, bytes: bytes));
      }
      setState(() {
        _slides.addAll(newSlides);
      });
    }
  }

  void _removeSlide(int index) {
    setState(() {
      _slides[index].dispose();
      _slides.removeAt(index);
    });
  }

  Future<void> _scanTextFromImage(int index) async {
    final slide = _slides[index];
    try {
      if (kIsWeb) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Extracting text via Cloud OCR...")),
          );
        }

        // The free/demo OCR.space key rejects anything over ~1MB outright.
        // image_picker's imageQuality: 50 only re-compresses the JPEG --
        // it doesn't resize dimensions, so a normal phone photo (often
        // several MB at full resolution) can easily still land above that
        // limit even after compression. Catching it here, before the
        // network call, is what was silently failing every time on real
        // photos (the API's own rejection was getting swallowed below).
        if (slide.bytes.lengthInBytes > 1024 * 1024) {
          throw Exception(
            "This image is too large to scan (over 1MB). Try retaking the "
            "photo at a lower resolution, or crop it closer to the page.",
          );
        }

        final String base64Img = base64Encode(slide.bytes);

        // The 'helloworld' key is OCR.space's shared public demo key --
        // free, but pooled across every app that uses it worldwide, so it
        // returns 503 ("busy") fairly often even though the request itself
        // is fine. One quick retry clears most of those transient hits
        // instead of failing the teacher's very first attempt.
        http.Response? response;
        for (int attempt = 0; attempt < 2; attempt++) {
          response = await http.post(
            Uri.parse('https://api.ocr.space/parse/image'),
            body: {
              'apikey': 'helloworld',
              'language': 'eng',
              'base64Image': 'data:image/jpeg;base64,$base64Img',
              // Engine 1 (the default if this is left out) is the one that
              // throws "E502: Error during OCR" on a lot of otherwise-fine
              // images. Engine 2 is a different underlying OCR pipeline and
              // is the documented workaround for that error.
              'OCREngine': '2',
            },
          );
          if (response.statusCode != 503) break;
          if (attempt == 0) await Future.delayed(const Duration(seconds: 2));
        }

        if (response!.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['IsErroredOnProcessing'] == false &&
              data['ParsedResults'] != null) {
            String extracted = "";
            for (var result in data['ParsedResults']) {
              extracted += (result['ParsedText'] ?? "") + "\n";
            }
            setState(() {
              if (slide.scriptControllers.isNotEmpty) {
                slide.scriptControllers[0].text = extracted.trim();
              }
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Text extracted successfully!")),
              );
            }
          } else {
            final err = data['ErrorMessage'];
            final detail = err is List
                ? err.join(', ')
                : (err?.toString() ?? '');
            throw Exception(
              detail.isNotEmpty ? detail : "Could not read text from image.",
            );
          }
        } else if (response.statusCode == 503) {
          throw Exception(
            "The free OCR service is busy right now. Please try again in "
            "a moment, or type the text in manually.",
          );
        } else {
          throw Exception("Cloud OCR failed (${response.statusCode})");
        }
        return;
      }

      final inputImage = InputImage.fromFilePath(slide.file.path);
      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );

      setState(() {
        if (slide.scriptControllers.isNotEmpty) {
          slide.scriptControllers[0].text = recognizedText.text;
        }
      });

      textRecognizer.close();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Text extracted successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceAll("Exception: ", "");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to extract text: $message")),
        );
      }
    }
  }

  Future<void> _uploadToServer() async {
    if (_titleController.text.trim().isEmpty ||
        _coverImage == null ||
        _slides.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please fill in the title, cover image, and at least 1 slide page.",
          ),
        ),
      );
      return;
    }

    if (_gradeLevel == null || _setLetter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please pick a Grade Level and a Passage Set."),
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadStatus = "Uploading cover image...";
    });

    try {
      final String coverImageUrl = await CloudinaryService.uploadImageBytes(
        _coverBytes!,
        filename: _coverImage!.name,
      );

      final List<String> pageImageUrls = [];
      for (int i = 0; i < _slides.length; i++) {
        setState(
          () => _uploadStatus =
              "Uploading slide ${i + 1} of ${_slides.length}...",
        );
        final url = await CloudinaryService.uploadImageBytes(
          _slides[i].bytes,
          filename: _slides[i].file.name,
        );
        pageImageUrls.add(url);
      }

      setState(() => _uploadStatus = "Saving story...");

      final uri = Uri.parse("$baseUrl/api/stories");
      final request = http.MultipartRequest('POST', uri);

      request.headers.addAll(networkHeaders);
      request.headers["ngrok-skip-browser-warning"] = "69420";

      request.fields['title'] = _titleController.text.trim();
      request.fields['description'] = _descController.text.trim();
      request.fields['story_type'] = _storyType;
      request.fields['grade_level'] = _gradeLevel!;
      request.fields['set_letter'] = _setLetter!;

      List<List<String>> allScripts = _slides
          .map((s) => s.scriptsList)
          .toList();
      request.fields['audio_scripts'] = jsonEncode(allScripts);

      request.fields['cover_image'] = coverImageUrl;
      request.fields['pages'] = jsonEncode(pageImageUrls);

      for (int i = 0; i < pageImageUrls.length; i++) {
        request.fields['pages[$i]'] = pageImageUrls[i];
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final resData = jsonDecode(response.body);
        final storyId = resData['story']['id'];

        if (_quizQuestions.isNotEmpty) {
          List<Map<String, dynamic>> questionsPayload = _quizQuestions.map((q) {
            return {
              "question_text": q.questionController.text.trim(),
              "options": q.optionControllers.map((c) => c.text.trim()).toList(),
              "correct_answer": q.optionControllers[q.correctAnswerIndex].text
                  .trim(),
            };
          }).toList();

          try {
            await http.post(
              Uri.parse('$baseUrl/api/stories/$storyId/quiz'),
              headers: {
                ...networkHeaders,
                "ngrok-skip-browser-warning": "69420",
                "Content-Type": "application/json",
              },
              body: jsonEncode({
                "title": "${_titleController.text.trim()} Quiz",
                "questions": questionsPayload,
              }),
            );
          } catch (e) {
            debugPrint("Quiz upload error: $e");
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Story, scripts & quiz uploaded successfully! 🎉"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Server Error (${response.statusCode}): ${response.body}",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Connection Error: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatus = "";
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    for (var slide in _slides) {
      slide.dispose();
    }
    for (var q in _quizQuestions) {
      q.questionController.dispose();
      for (var opt in q.optionControllers) {
        opt.dispose();
      }
    }
    super.dispose();
  }

  InputDecoration _comicInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black, width: 3),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blueAccent, width: 4),
      ),
    );
  }

  static const double _desktopBreakpoint = 900;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          "Upload New Story",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: Container(color: Colors.black, height: 4.0),
        ),
      ),
      body: GuideComicBackground(
        child: _isUploading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 15),
                    Text(
                      _uploadStatus.isEmpty
                          ? "Uploading story & scripts, please wait..."
                          : _uploadStatus,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final bool isDesktop =
                      constraints.maxWidth >= _desktopBreakpoint;
                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 40 : 16,
                      vertical: 20,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isDesktop ? 1180 : 640,
                        ),
                        child: isDesktop
                            ? _buildDesktopLayout()
                            : _buildMobileLayout(),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _titleField(),
        const SizedBox(height: 15),
        _storyTypeSelector(),
        const SizedBox(height: 15),
        _gradeAndSetSelector(),
        const SizedBox(height: 15),
        _descriptionField(),
        const SizedBox(height: 25),
        _coverImageSection(),
        const SizedBox(height: 25),
        _slidesSection(),
        const SizedBox(height: 40),
        _quizSection(),
        const SizedBox(height: 24),
        _addQuizButton(fullWidth: true),
        const SizedBox(height: 40),
        _submitButton(fullWidth: true),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _titleField(),
                  const SizedBox(height: 15),
                  _storyTypeSelector(),
                  const SizedBox(height: 15),
                  _gradeAndSetSelector(),
                  const SizedBox(height: 15),
                  _descriptionField(),
                  const SizedBox(height: 25),
                  _coverImageSection(),
                ],
              ),
            ),
            const SizedBox(width: 28),
            Expanded(flex: 6, child: _slidesSection()),
          ],
        ),
        const SizedBox(height: 40),
        _quizSection(),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: _addQuizButton(fullWidth: false),
        ),
        const SizedBox(height: 40),
        Center(child: _submitButton(fullWidth: false)),
      ],
    );
  }

  Widget _titleField() {
    return TextField(
      controller: _titleController,
      style: const TextStyle(fontWeight: FontWeight.bold),
      decoration: _comicInputDecoration("Story Title *"),
    );
  }

  // Two-button toggle for choosing which shelf this story is filed under.
  // Defaults to Pre Test.
  Widget _storyTypeSelector() {
    Widget buildOption(String value, String label, IconData icon) {
      final bool selected = _storyType == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _storyType = value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFDE047) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black, width: 2.5),
              boxShadow: selected
                  ? const [BoxShadow(color: Colors.black, offset: Offset(3, 3))]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.black, size: 22),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: Colors.black,
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
        _sectionLabel("Story Type *"),
        Row(
          children: [
            buildOption('pre_test', "Pre Test", Icons.edit_note_rounded),
            const SizedBox(width: 12),
            buildOption('post_test', "Post Test", Icons.fact_check_rounded),
          ],
        ),
      ],
    );
  }

  // Grade Level + Passage Set dropdowns, side by side. Both are required
  // before a story can be assigned to a student's Phil-IRI assessment.
  Widget _gradeAndSetSelector() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel("Grade Level *"),
              DropdownButtonFormField<String>(
                value: _gradeLevel,
                decoration: _comicInputDecoration("Select grade"),
                items: _availableGrades
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) => setState(() => _gradeLevel = v),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel("Passage Set *"),
              DropdownButtonFormField<String>(
                value: _setLetter,
                decoration: _comicInputDecoration("Select set"),
                items: _availableSets
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _setLetter = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _descriptionField() {
    return TextField(
      controller: _descController,
      maxLines: 3,
      style: const TextStyle(fontWeight: FontWeight.bold),
      decoration: _comicInputDecoration("Description (Optional)"),
    );
  }

  Widget _sectionLabel(String text) {
    // Wrapped in an opaque white "sticker" -- GuideComicBackground paints
    // its zigzag/ray artwork directly behind this screen's content, and
    // plain unfilled text sitting on top of it gets visually crossed out
    // by those shapes (see "Cover Image" / "Story Quiz" in the screenshot).
    // A solid backing box guarantees the label stays legible regardless of
    // what the background is doing underneath.
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black, width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.black, offset: Offset(2, 2)),
            ],
          ),
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _comicButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    bool fullWidth = true,
  }) {
    final button = ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.black, width: 3),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
      ),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );

    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
      ),
      child: button,
    );

    return fullWidth
        ? SizedBox(width: double.infinity, child: decorated)
        : decorated;
  }

  Widget _emptyStateBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3))],
      ),
      child: Text(
        message,
        style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _coverImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel("Cover Image *"),
        _comicButton(
          onPressed: _pickCover,
          icon: Icons.image,
          label: _coverImage == null
              ? "Select Cover Image"
              : "Change Cover Image",
        ),
        if (_coverBytes != null) ...[
          const SizedBox(height: 15),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.memory(
                _coverBytes!,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _slidesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel("Story Pages (Slides) & Narrator Scripts *"),
        _comicButton(
          onPressed: _pickPages,
          icon: Icons.photo_library,
          label: "Select Pages from Gallery",
        ),
        const SizedBox(height: 12),
        if (_slides.isEmpty)
          _emptyStateBox("0 pages selected")
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _slides.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) => _buildSlideCard(index),
          ),
      ],
    );
  }

  Widget _buildSlideCard(int index) {
    final slide = _slides[index];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.memory(
                    slide.bytes,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Slide ${index + 1}",
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: "Extract Text from Image",
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(
                  Icons.document_scanner,
                  color: Colors.blueAccent,
                  size: 20,
                ),
                onPressed: () => _scanTextFromImage(index),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: "Add Script Segment",
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(
                  Icons.add_circle,
                  color: Colors.green,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    slide.addScript();
                  });
                },
              ),
              const SizedBox(width: 6),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(
                  Icons.delete,
                  color: Colors.redAccent,
                  size: 20,
                ),
                onPressed: () => _removeSlide(index),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(slide.scriptControllers.length, (sIdx) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: slide.scriptControllers[sIdx],
                      maxLines: null,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      decoration: _comicInputDecoration(
                        "Segment ${sIdx + 1}",
                      ).copyWith(hintText: "Type story segment..."),
                    ),
                  ),
                  if (slide.scriptControllers.length > 1)
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          slide.removeScript(sIdx);
                        });
                      },
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _quizSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel("Story Quiz (Optional)"),
        if (_quizQuestions.isEmpty)
          _emptyStateBox("No quiz questions added. Students won't take a quiz.")
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _quizQuestions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) => _buildQuizCard(index),
          ),
      ],
    );
  }

  Widget _buildQuizCard(int index) {
    final quiz = _quizQuestions[index];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDE047),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Question ${index + 1}",
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(
                  Icons.delete,
                  color: Colors.redAccent,
                  size: 20,
                ),
                onPressed: () => _removeQuizQuestion(index),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: quiz.questionController,
            style: const TextStyle(fontWeight: FontWeight.bold),
            decoration: _comicInputDecoration("Type question here..."),
          ),
          const SizedBox(height: 12),
          const Text(
            "Options & Correct Answer:",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ...List.generate(4, (optIndex) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Radio<int>(
                    value: optIndex,
                    groupValue: quiz.correctAnswerIndex,
                    activeColor: Colors.redAccent,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => quiz.correctAnswerIndex = val);
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: quiz.optionControllers[optIndex],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      decoration:
                          _comicInputDecoration(
                            "Option ${String.fromCharCode(65 + optIndex)}",
                          ).copyWith(
                            fillColor: quiz.correctAnswerIndex == optIndex
                                ? Colors.green[100]
                                : Colors.white,
                          ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _addQuizButton({required bool fullWidth}) {
    return _comicButton(
      onPressed: _addQuizQuestion,
      icon: Icons.add_task,
      label: "Add Quiz Question",
      fullWidth: fullWidth,
    );
  }

  Widget _submitButton({required bool fullWidth}) {
    final button = ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
        backgroundColor: const Color(0xFF9B0505),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: const BorderSide(color: Colors.black, width: 3),
        ),
      ),
      onPressed: _uploadToServer,
      child: const Text(
        "UPLOAD AND SAVE",
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      ),
    );

    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(5, 5))],
      ),
      child: button,
    );

    if (!fullWidth) return decorated;
    return SizedBox(width: double.infinity, child: decorated);
  }
}
