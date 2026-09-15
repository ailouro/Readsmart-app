import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../services/config.dart'; // Mula sa config.dart (baseUrl at networkHeaders)
import '../services/cloudinary_service.dart'; // Mula sa cloudinary_service.dart (CloudinaryService)
import '../widgets/guide_comic_background.dart';

// Helper model para pagsamahin ang image file, bytes (para sa preview), at text controller
class SlideItem {
  final XFile file;
  final Uint8List bytes;
  final TextEditingController controller;

  SlideItem({
    required this.file,
    required this.bytes,
    required this.controller,
  });
}

class QuizQuestion {
  final TextEditingController questionController = TextEditingController();
  final List<TextEditingController> optionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  int correctAnswerIndex = 0; // Default to first option
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

  // List ng slides kasama ang script controllers
  final List<SlideItem> _slides = [];

  // List ng quiz questions
  final List<QuizQuestion> _quizQuestions = [];

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

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

  // --- 1. PICK COVER IMAGE ---
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

  // --- 2. PICK STORY PAGES (SLIDES) ---
  Future<void> _pickPages() async {
    final List<XFile> images = await _picker.pickMultiImage(imageQuality: 50);
    if (images.isNotEmpty) {
      List<SlideItem> newSlides = [];
      for (var file in images) {
        final bytes = await file.readAsBytes();
        newSlides.add(
          SlideItem(
            file: file,
            bytes: bytes,
            controller: TextEditingController(),
          ),
        );
      }
      setState(() {
        _slides.addAll(newSlides);
      });
    }
  }

  // --- 3. REMOVE SINGLE SLIDE ---
  void _removeSlide(int index) {
    setState(() {
      _slides[index].controller.dispose();
      _slides.removeAt(index);
    });
  }

  // --- 3.5 SCAN TEXT FROM IMAGE ---
  Future<void> _scanTextFromImage(int index) async {
    final slide = _slides[index];
    try {
      if (kIsWeb) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Extracting text via Cloud OCR...")),
          );
        }

        final String base64Img = base64Encode(slide.bytes);
        final response = await http.post(
          Uri.parse('https://api.ocr.space/parse/image'),
          body: {
            'apikey': 'helloworld',
            'language': 'eng',
            'base64Image': 'data:image/jpeg;base64,$base64Img',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['IsErroredOnProcessing'] == false &&
              data['ParsedResults'] != null) {
            String extracted = "";
            for (var result in data['ParsedResults']) {
              extracted += (result['ParsedText'] ?? "") + "\n";
            }
            setState(() {
              slide.controller.text = extracted.trim();
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Text extracted successfully!")),
              );
            }
          } else {
            throw Exception("Could not read text from image.");
          }
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
        slide.controller.text = recognizedText.text;
      });

      textRecognizer.close();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Text extracted successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to extract text: $e")));
      }
    }
  }

  // --- 4. CROSS-PLATFORM UPLOAD LOGIC ---
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

    setState(() {
      _isUploading = true;
      _uploadStatus = "Uploading cover image...";
    });

    try {
      // --- STEP 1: Upload images to Cloudinary FIRST ---
      // The backend no longer receives raw files for cover_image/pages —
      // it only ever gets back plain URL strings. This is what avoids the
      // "array offset on value of type null" crash: that error came from
      // the backend's file-handling code, so taking files out of the
      // request entirely sidesteps it.
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

      // --- STEP 2: Send story data (URLs only, no files) to the backend ---
      final uri = Uri.parse("$baseUrl/api/stories");
      final request = http.MultipartRequest('POST', uri);

      // Add Headers (Kasama ang ngrok bypass at iba pang headers)
      request.headers.addAll(networkHeaders);
      request.headers["ngrok-skip-browser-warning"] = "69420";

      // Story Text Fields
      request.fields['title'] = _titleController.text.trim();
      request.fields['description'] = _descController.text.trim();

      // Audio Scripts Packaging (Papadala bilang JSON array at indexed array para sa flexibility ng backend)
      List<String> scripts = _slides
          .map((s) => s.controller.text.trim())
          .toList();
      request.fields['audio_scripts'] = jsonEncode(scripts);

      for (int i = 0; i < _slides.length; i++) {
        request.fields['audio_scripts[$i]'] = _slides[i].controller.text.trim();
      }

      // Cover image: now a Cloudinary URL, sent as a normal text field.
      request.fields['cover_image'] = coverImageUrl;

      // Story Pages / Slides: now Cloudinary URLs, indexed like the old
      // pages[] file array so the backend field name can stay familiar
      // (pages[0], pages[1], ...) but read as strings instead of files.
      request.fields['pages'] = jsonEncode(pageImageUrls);
      for (int i = 0; i < pageImageUrls.length; i++) {
        request.fields['pages[$i]'] = pageImageUrls[i];
      }

      // Ipadala ang Request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final resData = jsonDecode(response.body);
        final storyId = resData['story']['id'];

        // Upload Quiz if we have any questions
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
        Navigator.pop(context, true); // Auto refresh dashboard
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
      slide.controller.dispose();
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

  // ---------------------------------------------------------------------
  // RESPONSIVE BREAKPOINT
  // ---------------------------------------------------------------------
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

  // ---------------------------------------------------------------------
  // MOBILE LAYOUT — single stacked column, full-width fields (touch friendly)
  // ---------------------------------------------------------------------
  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _titleField(),
        const SizedBox(height: 15),
        _descriptionField(),
        const SizedBox(height: 25),
        _coverImageSection(),
        const SizedBox(height: 25),
        _slidesSection(crossAxisCount: 1),
        const SizedBox(height: 40),
        _quizSection(crossAxisCount: 1),
        const SizedBox(height: 24),
        _addQuizButton(fullWidth: true),
        const SizedBox(height: 40),
        _submitButton(fullWidth: true),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // DESKTOP LAYOUT — two-column: details on the left, pages on the right,
  // quiz + submit span the full width below. Nothing stretches edge to edge.
  // ---------------------------------------------------------------------
  Widget _buildDesktopLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT: story details
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _titleField(),
                    const SizedBox(height: 15),
                    _descriptionField(),
                    const SizedBox(height: 25),
                    _coverImageSection(),
                  ],
                ),
              ),
              const SizedBox(width: 28),
              // RIGHT: pages / slides
              Expanded(flex: 6, child: _slidesSection(crossAxisCount: 2)),
            ],
          ),
        ),
        const SizedBox(height: 40),
        _quizSection(crossAxisCount: 2),
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

  // ---------------------------------------------------------------------
  // SHARED FIELD WIDGETS
  // ---------------------------------------------------------------------
  Widget _titleField() {
    return TextField(
      controller: _titleController,
      style: const TextStyle(fontWeight: FontWeight.bold),
      decoration: _comicInputDecoration("Story Title *"),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
      ),
    );
  }

  // A comic-style button that only stretches to full width when asked to —
  // on desktop it hugs its label instead of becoming a giant bar.
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

  // ---------------------------------------------------------------------
  // COVER IMAGE SECTION
  // ---------------------------------------------------------------------
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

  // ---------------------------------------------------------------------
  // STORY PAGES / SLIDES SECTION (single column on mobile, grid on desktop)
  // ---------------------------------------------------------------------
  Widget _slidesSection({required int crossAxisCount}) {
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
        else if (crossAxisCount > 1)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _slides.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 230,
            ),
            itemBuilder: (context, index) => _buildSlideCard(index),
          )
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
              const SizedBox(width: 8),
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
          Expanded(
            child: TextField(
              controller: slide.controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontWeight: FontWeight.bold),
              decoration: _comicInputDecoration(
                "Narrator Script for Slide ${index + 1}",
              ).copyWith(hintText: "Type story line for this slide..."),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // QUIZ SECTION (single column on mobile, grid on desktop)
  // ---------------------------------------------------------------------
  Widget _quizSection({required int crossAxisCount}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel("Story Quiz (Optional)"),
        if (_quizQuestions.isEmpty)
          _emptyStateBox("No quiz questions added. Students won't take a quiz.")
        else if (crossAxisCount > 1)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _quizQuestions.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 340,
            ),
            itemBuilder: (context, index) => _buildQuizCard(index),
          )
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
        color: const Color(0xFFFDE047), // comic yellow
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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

  // ---------------------------------------------------------------------
  // SUBMIT BUTTON
  // ---------------------------------------------------------------------
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
