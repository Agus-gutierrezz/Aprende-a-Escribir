import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  runApp(const App());
}

// ============================================================
// APP
// ============================================================

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aprender a escribir',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF29B6F6),
          primary: const Color(0xFF0288D1),
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F6F9),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

// ============================================================
// HOME
// ============================================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController controller = TextEditingController(text: 'CASA');
  final FlutterTts flutterTts = FlutterTts();

  final GlobalKey<_TracingAreaState> tracingAreaKey =
      GlobalKey<_TracingAreaState>();

  String word = 'CASA';
  double spacing = 14;
  double dotRadius = 4;
  double speechRate = 0.55;

  double pencilWidth = 10;
  Color pencilColor = Colors.blue;

  bool eraserMode = false;
  double eraserWidth = 28;

  bool isSpeaking = false;
  bool loadingVoices = true;
  bool controlsVisible = true;

  List<Map<String, String>> spanishVoices = [];
  String? selectedVoice;

  @override
  void initState() {
    super.initState();
    configureTts();
  }

  Future<void> configureTts() async {
    try {
      await flutterTts.setVolume(1.0);
      await flutterTts.setSpeechRate(speechRate);
      await flutterTts.setPitch(1.05);
      await flutterTts.awaitSpeakCompletion(true);

      flutterTts.setStartHandler(() {
        if (!mounted) return;
        setState(() => isSpeaking = true);
      });

      flutterTts.setCompletionHandler(() {
        if (!mounted) return;
        setState(() => isSpeaking = false);
      });

      flutterTts.setCancelHandler(() {
        if (!mounted) return;
        setState(() => isSpeaking = false);
      });

      flutterTts.setErrorHandler((_) {
        if (!mounted) return;
        setState(() => isSpeaking = false);
      });

      await loadVoices();
    } catch (e) {
      debugPrint('Error configurando TTS: $e');
      if (!mounted) return;
      setState(() => loadingVoices = false);
    }
  }

  Future<void> loadVoices() async {
    try {
      final dynamic result = await flutterTts.getVoices;
      final List<Map<String, String>> voices = [];

      if (result is List) {
        for (final voice in result) {
          if (voice is! Map) continue;
          final name = voice['name']?.toString() ?? '';
          final locale = voice['locale']?.toString() ?? '';

          if (name.isNotEmpty && locale.isNotEmpty) {
            if (locale.toLowerCase().startsWith('es')) {
              voices.add({'name': name, 'locale': locale});
            }
          }
        }
      }

      int priority(Map<String, String> voice) {
        final locale = voice['locale']!.toLowerCase();
        if (locale == 'es-ar') return 0;
        if (locale == 'es-us') return 1;
        if (locale == 'es-mx') return 2;
        if (locale == 'es-es') return 3;
        return 4;
      }

      voices.sort((a, b) => priority(a).compareTo(priority(b)));

      if (!mounted) return;
      setState(() {
        spanishVoices = voices;
        loadingVoices = false;
      });

      if (voices.isNotEmpty) {
        await selectVoice(voiceKey(voices.first));
      } else {
        await configureFallbackLanguage();
      }
    } catch (e) {
      debugPrint('Error cargando voces: $e');
      if (!mounted) return;
      setState(() => loadingVoices = false);
      await configureFallbackLanguage();
    }
  }

  Future<void> configureFallbackLanguage() async {
    try {
      final available = await flutterTts.isLanguageAvailable('es-AR');
      await flutterTts.setLanguage(available == true ? 'es-AR' : 'es-ES');
    } catch (_) {
      await flutterTts.setLanguage('es-ES');
    }
  }

  String voiceKey(Map<String, String> voice) =>
      '${voice['name']}|||${voice['locale']}';

  Future<void> selectVoice(String key) async {
    Map<String, String>? selected;
    for (final voice in spanishVoices) {
      if (voiceKey(voice) == key) {
        selected = voice;
        break;
      }
    }
    if (selected == null) return;

    try {
      await flutterTts.stop();
      await flutterTts.setLanguage(selected['locale']!);
      await flutterTts.setVoice({
        'name': selected['name']!,
        'locale': selected['locale']!,
      });
      if (!mounted) return;
      setState(() => selectedVoice = key);
    } catch (e) {
      debugPrint('Error seleccionando voz: $e');
    }
  }

  Future<void> changeSpeechRate(double value) async {
    setState(() => speechRate = value);
    await flutterTts.setSpeechRate(value);
  }

  Future<void> speakWord() async {
    final text = word.trim().toLowerCase();
    if (text.isEmpty) return;

    try {
      await flutterTts.stop();
      await flutterTts.speak(text);
    } catch (_) {
      if (!mounted) return;
      setState(() => isSpeaking = false);
    }
  }

  void changeWord(String value) {
    setState(() => word = value.toUpperCase());
  }

  void clearDrawing() {
    tracingAreaKey.currentState?.clearDrawing();
  }

  void toggleControls() {
    setState(() {
      controlsVisible = !controlsVisible;
    });
  }

  bool get isLongWord => word.replaceAll(' ', '').length >= 7;

  void changePencilWidth(double value) => setState(() => pencilWidth = value);
  void changePencilColor(Color color) => setState(() => pencilColor = color);
  void toggleEraser() => setState(() => eraserMode = !eraserMode);
  void changeEraserWidth(double value) => setState(() => eraserWidth = value);

  @override
  void dispose() {
    flutterTts.stop();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        toolbarHeight: isLandscape ? 48 : 56,
        leading: IconButton(
          icon: Icon(controlsVisible ? Icons.fullscreen : Icons.tune, color: const Color(0xFF0288D1)),
          tooltip: controlsVisible ? 'Modo Practicar' : 'Mostrar controles',
          onPressed: toggleControls,
        ),
        title: Text(
          '✏️ Aprender a escribir',
          style: TextStyle(
            fontSize: isLandscape ? 18 : 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0288D1),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Créditos y Privacidad',
            icon: const Icon(
              Icons.info_outline,
              color: Color(0xFF0288D1),
            ),
            onPressed: showCreditsDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: isLandscape ? buildLandscape() : buildPortrait(),
      ),
    );
  }

  void showCreditsDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.school_outlined,
          size: 34,
          color: Color(0xFF0288D1),
        ),
        title: const Text(
          'Información y Privacidad',
          textAlign: TextAlign.center,
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'Aprender a escribir',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0288D1),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Institución',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text('ISC 6030 - Las Lajitas'),
              SizedBox(height: 14),
              Text(
                'Integrantes',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text('• Gutierrez Agustín'),
              Text('• Gomez Fernanda'),
              Text('• Calmejane Nelson'),
              Text('• Oña Joel'),
              SizedBox(height: 18),
              Divider(),
              SizedBox(height: 12),
              Text(
                'Política de Privacidad',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0288D1)),
              ),
              SizedBox(height: 6),
              Text(
                'Esta aplicación educativa no recopila, almacena ni comparte ningún tipo de información personal o sensible de los usuarios. Todo el procesamiento de los trazos, dibujos y la reproducción de voz se realiza de manera local en el dispositivo con fines netamente académicos.',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
              SizedBox(height: 18),
              Divider(),
              SizedBox(height: 8),
              Text(
                '© 2026 ISC 6030 - Las Lajitas. Todos los derechos reservados.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget buildPortrait() {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            height: controlsVisible && !keyboardOpen ? 300 : 0,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  buildWordField(),
                  const SizedBox(height: 6),
                  buildListenButton(),
                  const SizedBox(height: 6),
                  buildToolCard(),
                  buildSettingsCard(),
                ],
              ),
            ),
          ),
          if (isLongWord && controlsVisible && !keyboardOpen) ...[
            const SizedBox(height: 6),
            buildOrientationMessage(),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: TracingArea(
                    key: tracingAreaKey,
                    word: word,
                    spacing: spacing,
                    dotRadius: dotRadius,
                    isLandscape: false,
                    pencilWidth: pencilWidth,
                    pencilColor: pencilColor,
                    eraserMode: eraserMode,
                    eraserWidth: eraserWidth,
                    isDrawingEnabled: !controlsVisible,
                    hideStrokes: controlsVisible,
                  ),
                ),
                if (keyboardOpen)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color: Colors.white.withOpacity(0.95),
                        child: const Center(
                          child: Text(
                            'Escribí la palabra y presioná Listo',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!keyboardOpen) ...[
            const SizedBox(height: 8),
            buildControlButtons(),
          ],
        ],
      ),
    );
  }

  Widget buildLandscape() {
    final screenWidth = MediaQuery.of(context).size.width;
    final controlsWidth = math.max(250.0, math.min(300.0, screenWidth * 0.32));

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            width: controlsVisible ? controlsWidth : 0,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  buildWordField(),
                  const SizedBox(height: 8),
                  buildListenButton(),
                  const SizedBox(height: 8),
                  buildToolCard(),
                  buildSettingsCard(),
                  const SizedBox(height: 8),
                  buildControlButtons(),
                ],
              ),
            ),
          ),
          if (controlsVisible) const SizedBox(width: 8),
          Expanded(
            child: TracingArea(
              key: tracingAreaKey,
              word: word,
              spacing: spacing,
              dotRadius: dotRadius,
              isLandscape: true,
              pencilWidth: pencilWidth,
              pencilColor: pencilColor,
              eraserMode: eraserMode,
              eraserWidth: eraserWidth,
              isDrawingEnabled: !controlsVisible,
              hideStrokes: controlsVisible,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildWordField() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: TextField(
          controller: controller,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: Color(0xFF0288D1),
          ),
          decoration: const InputDecoration(
            hintText: 'Escribe aquí...',
            border: InputBorder.none,
            prefixIcon: Icon(Icons.edit_note, color: Color(0xFF0288D1)),
            isDense: true,
          ),
          onChanged: changeWord,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
        ),
      ),
    );
  }

  Widget buildListenButton() {
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF0288D1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: word.trim().isEmpty ? null : speakWord,
        icon: Icon(isSpeaking ? Icons.volume_up : Icons.record_voice_over, size: 18),
        label: Text(
          isSpeaking ? 'Escuchando...' : 'Escuchar Palabra',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }

  Widget buildToolCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: false,
                  label: Text('Lápiz'),
                  icon: Icon(Icons.edit, size: 16),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text('Goma'),
                  icon: Icon(Icons.auto_fix_high, size: 16),
                ),
              ],
              selected: {eraserMode},
              onSelectionChanged: (Set<bool> selection) {
                setState(() => eraserMode = selection.first);
              },
            ),
            const SizedBox(height: 4),
            if (eraserMode)
              Row(
                children: [
                  const SizedBox(width: 45, child: Text('Ancho', style: TextStyle(fontSize: 11))),
                  Expanded(
                    child: Slider(
                      min: 12,
                      max: 60,
                      value: eraserWidth,
                      onChanged: changeEraserWidth,
                    ),
                  ),
                ],
              )
            else ...[
              Row(
                children: [
                  const SizedBox(width: 45, child: Text('Grosor', style: TextStyle(fontSize: 11))),
                  Expanded(
                    child: Slider(
                      min: 3,
                      max: 18,
                      value: pencilWidth,
                      onChanged: changePencilWidth,
                    ),
                  ),
                ],
              ),
              buildPencilColorControl(),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildSettingsCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            buildVoiceSelector(),
            buildSpeechRate(),
            buildSpacingControl(),
            buildDotControl(),
          ],
        ),
      ),
    );
  }

  Widget buildPencilColorControl() {
    const colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.black,
    ];

    return Wrap(
      spacing: 6,
      alignment: WrapAlignment.center,
      children: colors.map((color) {
        final selected = pencilColor == color;
        return GestureDetector(
          onTap: () => changePencilColor(color),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: selected ? 28 : 24,
            height: selected ? 28 : 24,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? Colors.white : Colors.transparent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: selected ? 4 : 1,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget buildVoiceSelector() {
    if (loadingVoices) return const LinearProgressIndicator();
    if (spanishVoices.isEmpty) return const SizedBox.shrink();

    return DropdownButtonFormField<String>(
      value: selectedVoice,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Voz',
        border: InputBorder.none,
        prefixIcon: Icon(Icons.record_voice_over_outlined, size: 18),
        isDense: true,
      ),
      items: spanishVoices.map((voice) {
        final key = voiceKey(voice);
        return DropdownMenuItem<String>(
          value: key,
          child: Text(
            '${voice['name']} (${voice['locale']})',
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) selectVoice(value);
      },
    );
  }

  Widget buildSpeechRate() {
    return Row(
      children: [
        const SizedBox(width: 65, child: Text('Velocidad', style: TextStyle(fontSize: 11))),
        Expanded(
          child: Slider(
            min: 0.40,
            max: 0.75,
            divisions: 14,
            value: speechRate,
            onChanged: changeSpeechRate,
          ),
        ),
      ],
    );
  }

  Widget buildSpacingControl() {
    return Row(
      children: [
        const SizedBox(width: 65, child: Text('Separación', style: TextStyle(fontSize: 11))),
        Expanded(
          child: Slider(
            min: 7,
            max: 30,
            value: spacing,
            onChanged: (v) => setState(() => spacing = v),
          ),
        ),
      ],
    );
  }

  Widget buildDotControl() {
    return Row(
      children: [
        const SizedBox(width: 65, child: Text('Punto', style: TextStyle(fontSize: 11))),
        Expanded(
          child: Slider(
            min: 2,
            max: 8,
            value: dotRadius,
            onChanged: (v) => setState(() => dotRadius = v),
          ),
        ),
      ],
    );
  }

  Widget buildOrientationMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.screen_rotation, size: 16, color: Colors.orange),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Girá el celular para escribir mejor',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildControlButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: clearDrawing,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Limpiar'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: controlsVisible ? const Color(0xFF4CAF50) : const Color(0xFF0288D1),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: toggleControls,
            icon: Icon(controlsVisible ? Icons.play_arrow : Icons.tune, size: 18),
            label: Text(controlsVisible ? 'Practicar' : 'Controles'),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// DATOS DE TRAZO NORMALIZADOS
// ============================================================

class StrokeData {
  StrokeData({
    required this.normalizedPoints,
    required this.color,
    required this.width,
  });

  final List<Offset> normalizedPoints;
  final Color color;
  final double width;
}

// ============================================================
// ÁREA DE TRAZADO
// ============================================================

class TracingArea extends StatefulWidget {
  const TracingArea({
    super.key,
    required this.word,
    required this.spacing,
    required this.dotRadius,
    required this.isLandscape,
    required this.pencilWidth,
    required this.pencilColor,
    required this.eraserMode,
    required this.eraserWidth,
    required this.isDrawingEnabled,
    required this.hideStrokes,
  });

  final String word;
  final double spacing;
  final double dotRadius;
  final bool isLandscape;
  final double pencilWidth;
  final Color pencilColor;
  final bool eraserMode;
  final double eraserWidth;
  final bool isDrawingEnabled;
  final bool hideStrokes;

  @override
  State<TracingArea> createState() => _TracingAreaState();
}

class _TracingAreaState extends State<TracingArea> {
  final List<StrokeData> strokes = [];
  final ScrollController scrollController = ScrollController();

  double scrollOffset = 0;
  double accuracy = 0;
  double coverage = 0;
  double precision = 0;
  int movementCounter = 0;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(onScrollChanged);
  }

  @override
  void didUpdateWidget(covariant TracingArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.word != widget.word) clearDrawing();
  }

  void onScrollChanged() {
    if (!mounted) return;
    setState(() => scrollOffset = scrollController.offset);
  }

  void scrollBy(double offset) {
    final target = (scrollController.offset + offset).clamp(
      0.0,
      scrollController.hasClients ? scrollController.position.maxScrollExtent : 0.0,
    );
    scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void startStroke(Offset point, Size canvasSize) {
    if (!widget.isDrawingEnabled) return;
    if (widget.eraserMode) {
      eraseAt(point, canvasSize);
      return;
    }
    if (canvasSize.width == 0 || canvasSize.height == 0) return;

    final normPoint = Offset(
      point.dx / canvasSize.width,
      point.dy / canvasSize.height,
    );

    setState(() {
      strokes.add(
        StrokeData(
          normalizedPoints: [normPoint],
          color: widget.pencilColor,
          width: widget.pencilWidth,
        ),
      );
    });
  }

  void updateStroke(Offset point, Size canvasSize) {
    if (!widget.isDrawingEnabled) return;
    if (widget.eraserMode) {
      eraseAt(point, canvasSize);
      movementCounter++;
      if (movementCounter % 4 == 0) calculateScore(canvasSize);
      return;
    }

    if (strokes.isEmpty || canvasSize.width == 0 || canvasSize.height == 0) return;

    final normPoint = Offset(
      point.dx / canvasSize.width,
      point.dy / canvasSize.height,
    );

    setState(() => strokes.last.normalizedPoints.add(normPoint));
    movementCounter++;
    if (movementCounter % 4 == 0) calculateScore(canvasSize);
  }

  void finishStroke(Size canvasSize) {
    if (!widget.isDrawingEnabled) return;
    calculateScore(canvasSize);
  }

  void eraseAt(Offset point, Size canvasSize) {
    if (strokes.isEmpty || canvasSize.width == 0 || canvasSize.height == 0) return;
    final radius = widget.eraserWidth / 2;
    final newStrokes = <StrokeData>[];
    bool changed = false;

    for (final stroke in strokes) {
      final normPoints = stroke.normalizedPoints;
      if (normPoints.isEmpty) continue;

      final points = normPoints
          .map((np) => Offset(np.dx * canvasSize.width, np.dy * canvasSize.height))
          .toList();

      var currentNormPart = <Offset>[];
      for (var i = 0; i < points.length; i++) {
        final current = points[i];
        bool erasePoint = (current - point).distance <= radius;

        if (erasePoint) {
          changed = true;
          if (currentNormPart.length >= 2) {
            final converted = currentNormPart
                .map((p) => Offset(p.dx / canvasSize.width, p.dy / canvasSize.height))
                .toList();
            newStrokes.add(StrokeData(
              normalizedPoints: converted,
              color: stroke.color,
              width: stroke.width,
            ));
          }
          currentNormPart = <Offset>[];
        } else {
          currentNormPart.add(current);
        }
      }

      if (currentNormPart.length >= 2) {
        final converted = currentNormPart
            .map((p) => Offset(p.dx / canvasSize.width, p.dy / canvasSize.height))
            .toList();
        newStrokes.add(StrokeData(
          normalizedPoints: converted,
          color: stroke.color,
          width: stroke.width,
        ));
      }
    }

    if (!changed) return;
    setState(() {
      strokes
        ..clear()
        ..addAll(newStrokes);
    });
  }

  void clearDrawing() {
    if (!mounted) return;
    setState(() {
      strokes.clear();
      accuracy = 0;
      coverage = 0;
      precision = 0;
      movementCounter = 0;
    });
  }

  void calculateScore(Size canvasSize) {
    if (strokes.isEmpty) {
      setState(() {
        accuracy = 0;
        coverage = 0;
        precision = 0;
      });
      return;
    }

    final layout = WordGuideLayout.build(
      word: widget.word,
      size: canvasSize,
    );

    if (layout.paths.isEmpty) return;

    final guidePoints = samplePaths(layout.paths, 7);
    
    List<StrokeData> absoluteStrokes = strokes.map((s) {
      List<Offset> absPts = s.normalizedPoints
          .map((np) => Offset(np.dx * canvasSize.width, np.dy * canvasSize.height))
          .toList();
      return StrokeData(normalizedPoints: absPts, color: s.color, width: s.width);
    }).toList();

    final drawingPoints = sampleStrokes(absoluteStrokes, 6);

    if (guidePoints.isEmpty || drawingPoints.isEmpty) return;

    final tolerance = math.max(
        16.0, math.min(28.0, layout.letterWidth * 0.28));
    final toleranceSquared = tolerance * tolerance;

    int coveredGuidePoints = 0;
    for (final guidePoint in guidePoints) {
      if (isNearAnyPoint(guidePoint, drawingPoints, toleranceSquared)) {
        coveredGuidePoints++;
      }
    }

    int accurateDrawingPoints = 0;
    for (final drawingPoint in drawingPoints) {
      if (isNearAnyPoint(drawingPoint, guidePoints, toleranceSquared)) {
        accurateDrawingPoints++;
      }
    }

    final newCoverage = coveredGuidePoints / guidePoints.length;
    final newPrecision = accurateDrawingPoints / drawingPoints.length;

    double newAccuracy = (newCoverage * 0.65) + (newPrecision * 0.35);
    if (newCoverage < 0.15) {
      newAccuracy *= 0.55;
    } else if (newCoverage < 0.30) {
      newAccuracy *= 0.75;
    }

    newAccuracy = newAccuracy.clamp(0.0, 1.0);

    if (!mounted) return;
    setState(() {
      coverage = newCoverage;
      precision = newPrecision;
      accuracy = newAccuracy;
    });
  }

  bool isNearAnyPoint(
      Offset target, List<Offset> points, double toleranceSquared) {
    for (final point in points) {
      final dx = target.dx - point.dx;
      final dy = target.dy - point.dy;
      if ((dx * dx) + (dy * dy) <= toleranceSquared) return true;
    }
    return false;
  }

  List<Offset> samplePaths(List<Path> paths, double step) {
    final points = <Offset>[];
    for (final path in paths) {
      for (final metric in path.computeMetrics()) {
        double distance = 0;
        while (distance <= metric.length) {
          final tangent = metric.getTangentForOffset(distance);
          if (tangent != null) points.add(tangent.position);
          distance += step;
        }
      }
    }
    return points;
  }

  List<Offset> sampleStrokes(List<StrokeData> strokes, double step) {
    final result = <Offset>[];
    for (final stroke in strokes) {
      final points = stroke.normalizedPoints;
      if (points.isEmpty) continue;

      result.add(points.first);
      for (int i = 1; i < points.length; i++) {
        final start = points[i - 1];
        final end = points[i];
        final dx = end.dx - start.dx;
        final dy = end.dy - start.dy;
        final distance = math.sqrt(dx * dx + dy * dy);

        if (distance == 0) continue;
        final pieces = math.max(1, (distance / step).ceil());

        for (int j = 1; j <= pieces; j++) {
          final t = j / pieces;
          result.add(Offset(start.dx + dx * t, start.dy + dy * t));
        }
      }
    }
    return result;
  }

  String get scoreMessage {
    final percent = accuracy * 100;
    if (percent == 0) return 'Empezá a dibujar';
    if (percent >= 85) return '¡Excelente!';
    if (percent >= 65) return '¡Muy bien!';
    if (percent >= 40) return '¡Vas bien!';
    return 'Seguí intentando';
  }

  IconData get scoreIcon {
    final percent = accuracy * 100;
    if (percent >= 85) return Icons.stars_rounded;
    if (percent >= 65) return Icons.sentiment_very_satisfied;
    if (percent >= 40) return Icons.sentiment_satisfied;
    return Icons.edit_note;
  }

  double calculateRequiredWidth(double viewportWidth) {
    final characters = widget.word.trim().split('');
    int characterCount = characters.where((c) => c != ' ').length;
    if (characterCount == 0) return viewportWidth;

    final desiredLetterWidth = widget.isLandscape ? 80.0 : 45.0;
    const gapRatio = 0.22;
    const spaceRatio = 0.70;

    int spaces = characters.where((c) => c == ' ').length;
    final totalUnits = characterCount +
        (spaces * spaceRatio) +
        ((characters.length - 1) * gapRatio);

    final calculatedWidth = (totalUnits * desiredLetterWidth) + 100;
    return math.max(viewportWidth, calculatedWidth);
  }

  @override
  void dispose() {
    scrollController.removeListener(onScrollChanged);
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final contentWidth = calculateRequiredWidth(viewportWidth);
        final canvasSize = Size(contentWidth, constraints.maxHeight);
        final isScrollable = contentWidth > viewportWidth;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Positioned.fill(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: SizedBox(
                      width: contentWidth,
                      height: constraints.maxHeight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: widget.isDrawingEnabled
                            ? (details) => startStroke(details.localPosition, canvasSize)
                            : null,
                        onPanUpdate: widget.isDrawingEnabled
                            ? (details) => updateStroke(details.localPosition, canvasSize)
                            : null,
                        onPanEnd: widget.isDrawingEnabled
                            ? (_) => finishStroke(canvasSize)
                            : null,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: SingleLineWordPainter(
                                  word: widget.word,
                                  spacing: widget.spacing,
                                  dotRadius: widget.dotRadius,
                                ),
                              ),
                            ),
                            if (!widget.hideStrokes)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: ChildDrawingPainter(
                                      strokes: strokes,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (isScrollable) ...[
                  Positioned(
                    left: 4,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Material(
                        color: Colors.white.withOpacity(0.85),
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: IconButton(
                          icon: const Icon(Icons.chevron_left, color: Color(0xFF0288D1)),
                          onPressed: () => scrollBy(-150),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Material(
                        color: Colors.white.withOpacity(0.85),
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: IconButton(
                          icon: const Icon(Icons.chevron_right, color: Color(0xFF0288D1)),
                          onPressed: () => scrollBy(150),
                        ),
                      ),
                    ),
                  ),
                ],
                Positioned(
                  top: 12,
                  right: 12,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(scoreIcon, size: 20, color: Colors.amber),
                              const SizedBox(width: 4),
                              const Text(
                                'Acierto',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${(accuracy * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0288D1),
                            ),
                          ),
                          Text(
                            scoreMessage,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class WordGuideLayout {
  const WordGuideLayout({
    required this.paths,
    required this.letterWidth,
  });

  final List<Path> paths;
  final double letterWidth;

  static WordGuideLayout build({
    required String word,
    required Size size,
  }) {
    final cleanWord = word.trim().toUpperCase();
    if (cleanWord.isEmpty) {
      return const WordGuideLayout(paths: [], letterWidth: 0);
    }

    final characters = cleanWord.split('');
    const gapRatio = 0.22;
    const spaceRatio = 0.70;

    int visibleCharacters = characters.where((c) => c != ' ').length;
    int spaces = characters.where((c) => c == ' ').length;

    if (visibleCharacters == 0) {
      return const WordGuideLayout(paths: [], letterWidth: 0);
    }

    final totalUnits = visibleCharacters +
        (spaces * spaceRatio) +
        ((characters.length - 1) * gapRatio);

    final availableWidth = size.width * 0.94;
    final availableHeight = size.height * 0.90;

    final widthBasedLetter = availableWidth / totalUnits;
    final heightBasedLetter = availableHeight * 0.68;

    final letterWidth = math.min(widthBasedLetter, heightBasedLetter);
    final letterHeight = letterWidth / 0.68;

    final gap = letterWidth * gapRatio;
    final spaceWidth = letterWidth * spaceRatio;

    double totalWordWidth = 0;
    for (int i = 0; i < characters.length; i++) {
      totalWordWidth += (characters[i] == ' ') ? spaceWidth : letterWidth;
      if (i < characters.length - 1) totalWordWidth += gap;
    }

    double currentX = (size.width - totalWordWidth) / 2;
    final top = (size.height - letterHeight) / 2;

    final paths = <Path>[];
    for (final character in characters) {
      if (character == ' ') {
        currentX += spaceWidth + gap;
        continue;
      }

      final rect = Rect.fromLTWH(currentX, top, letterWidth, letterHeight);
      paths.addAll(LetterPaths.createForRect(character, rect));
      currentX += letterWidth + gap;
    }

    return WordGuideLayout(paths: paths, letterWidth: letterWidth);
  }
}

class SingleLineWordPainter extends CustomPainter {
  SingleLineWordPainter({
    required this.word,
    required this.spacing,
    required this.dotRadius,
  });

  final String word;
  final double spacing;
  final double dotRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = WordGuideLayout.build(word: word, size: size);
    if (layout.paths.isEmpty) return;

    final paint = Paint()
      ..color = Colors.grey.shade600
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (final path in layout.paths) {
      for (final metric in path.computeMetrics()) {
        double distance = 0;
        while (distance <= metric.length) {
          final tangent = metric.getTangentForOffset(distance);
          if (tangent != null) {
            canvas.drawCircle(tangent.position, dotRadius, paint);
          }
          distance += spacing;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant SingleLineWordPainter oldDelegate) {
    return oldDelegate.word != word ||
        oldDelegate.spacing != spacing ||
        oldDelegate.dotRadius != dotRadius;
  }
}

class ChildDrawingPainter extends CustomPainter {
  ChildDrawingPainter({required this.strokes});

  final List<StrokeData> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final normPoints = stroke.normalizedPoints;
      if (normPoints.isEmpty) continue;

      final points = normPoints
          .map((np) => Offset(np.dx * size.width, np.dy * size.height))
          .toList();

      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;

      if (points.length == 1) {
        canvas.drawCircle(
          points.first,
          stroke.width / 2,
          Paint()
            ..color = stroke.color
            ..isAntiAlias = true,
        );
        continue;
      }

      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length - 1; i++) {
        final current = points[i];
        final next = points[i + 1];
        final middle = Offset((current.dx + next.dx) / 2, (current.dy + next.dy) / 2);
        path.quadraticBezierTo(current.dx, current.dy, middle.dx, middle.dy);
      }
      path.lineTo(points.last.dx, points.last.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ChildDrawingPainter oldDelegate) => true;
}

class LetterPaths {
  static List<Path> createForRect(String character, Rect rect) {
    final original = character.toUpperCase();
    final base = baseCharacter(original);

    final hasAccent = {'Á', 'É', 'Í', 'Ó', 'Ú'}.contains(original);
    final hasUmlaut = original == 'Ü';
    final hasTilde = original == 'Ñ';
    final hasMark = hasAccent || hasUmlaut || hasTilde;

    final baseRect = hasMark
        ? Rect.fromLTWH(
            rect.left, rect.top + rect.height * 0.14, rect.width, rect.height * 0.86)
        : rect;

    final paths = createBasePaths(base, baseRect);

    if (hasAccent) {
      paths.add(Path()
        ..moveTo(rect.left + rect.width * 0.43, rect.top + rect.height * 0.10)
        ..lineTo(rect.left + rect.width * 0.62, rect.top));
    }

    if (hasUmlaut) {
      paths.add(Path()
        ..moveTo(rect.left + rect.width * 0.34, rect.top + rect.height * 0.05)
        ..lineTo(rect.left + rect.width * 0.34, rect.top + rect.height * 0.08));
      paths.add(Path()
        ..moveTo(rect.left + rect.width * 0.66, rect.top + rect.height * 0.05)
        ..lineTo(rect.left + rect.width * 0.66, rect.top + rect.height * 0.08));
    }

    if (hasTilde) {
      final tilde = Path()
        ..moveTo(rect.left + rect.width * 0.27, rect.top + rect.height * 0.08)
        ..cubicTo(
            rect.left + rect.width * 0.37,
            rect.top,
            rect.left + rect.width * 0.48,
            rect.top + rect.height * 0.14,
            rect.left + rect.width * 0.59,
            rect.top + rect.height * 0.07);
      paths.add(tilde);
    }

    return paths;
  }

  static String baseCharacter(String character) {
    switch (character) {
      case 'Á': return 'A';
      case 'É': return 'E';
      case 'Í': return 'I';
      case 'Ó': return 'O';
      case 'Ú':
      case 'Ü': return 'U';
      case 'Ñ': return 'N';
      default: return character;
    }
  }

  static List<Path> createBasePaths(String character, Rect rect) {
    Offset p(double x, double y) =>
        Offset(rect.left + x * rect.width, rect.top + y * rect.height);

    Path path() => Path();

    switch (character) {
      case 'A':
        return [
          path()..moveTo(p(.10, 1).dx, p(.10, 1).dy)..lineTo(p(.50, 0).dx, p(.50, 0).dy)..lineTo(p(.90, 1).dx, p(.90, 1).dy),
          path()..moveTo(p(.27, .60).dx, p(.27, .60).dy)..lineTo(p(.73, .60).dx, p(.73, .60).dy),
        ];
      case 'B':
        return [
          path()..moveTo(p(.20, 0).dx, p(.20, 0).dy)..lineTo(p(.20, 1).dx, p(.20, 1).dy),
          path()..moveTo(p(.20, 0).dx, p(.20, 0).dy)..cubicTo(p(.85, 0).dx, p(.85, 0).dy, p(.90, .48).dx, p(.90, .48).dy, p(.20, .48).dx, p(.20, .48).dy),
          path()..moveTo(p(.20, .48).dx, p(.20, .48).dy)..cubicTo(p(.90, .48).dx, p(.90, .48).dy, p(.90, 1).dx, p(.90, 1).dy, p(.20, 1).dx, p(.20, 1).dy),
        ];
      case 'C':
        return [
          path()..moveTo(p(.88, .14).dx, p(.88, .14).dy)..cubicTo(p(.70, -.03).dx, p(.70, -.03).dy, p(.25, -.03).dx, p(.25, -.03).dy, p(.15, .50).dx, p(.15, .50).dy)..cubicTo(p(.25, 1.03).dx, p(.25, 1.03).dy, p(.70, 1.03).dx, p(.70, 1.03).dy, p(.88, .86).dx, p(.88, .86).dy),
        ];
      case 'D':
        return [
          path()..moveTo(p(.20, 0).dx, p(.20, 0).dy)..lineTo(p(.20, 1).dx, p(.20, 1).dy),
          path()..moveTo(p(.20, 0).dx, p(.20, 0).dy)..cubicTo(p(.95, 0).dx, p(.95, 0).dy, p(.95, 1).dx, p(.95, 1).dy, p(.20, 1).dx, p(.20, 1).dy),
        ];
      case 'E':
        return [
          path()..moveTo(p(.20, 0).dx, p(.20, 0).dy)..lineTo(p(.20, 1).dx, p(.20, 1).dy),
          path()..moveTo(p(.20, 0).dx, p(.20, 0).dy)..lineTo(p(.85, 0).dx, p(.85, 0).dy),
          path()..moveTo(p(.20, .50).dx, p(.20, .50).dy)..lineTo(p(.72, .50).dx, p(.72, .50).dy),
          path()..moveTo(p(.20, 1).dx, p(.20, 1).dy)..lineTo(p(.85, 1).dx, p(.85, 1).dy),
        ];
      case 'F':
        return [
          path()..moveTo(p(.20, 1).dx, p(.20, 1).dy)..lineTo(p(.20, 0).dx, p(.20, 0).dy)..lineTo(p(.85, 0).dx, p(.85, 0).dy),
          path()..moveTo(p(.20, .48).dx, p(.20, .48).dy)..lineTo(p(.72, .48).dx, p(.72, .48).dy),
        ];
      case 'G':
        return [
          path()..moveTo(p(.88, .18).dx, p(.88, .18).dy)..cubicTo(p(.65, -.05).dx, p(.65, -.05).dy, p(.15, .05).dx, p(.15, .05).dy, p(.15, .52).dx, p(.15, .52).dy)..cubicTo(p(.15, .98).dx, p(.15, .98).dy, p(.65, 1.05).dx, p(.65, 1.05).dy, p(.88, .78).dx, p(.88, .78).dy)..lineTo(p(.88, .55).dx, p(.88, .55).dy)..lineTo(p(.60, .55).dx, p(.60, .55).dy),
        ];
      case 'H':
        return [
          path()..moveTo(p(.20, 0).dx, p(.20, 0).dy)..lineTo(p(.20, 1).dx, p(.20, 1).dy),
          path()..moveTo(p(.80, 0).dx, p(.80, 0).dy)..lineTo(p(.80, 1).dx, p(.80, 1).dy),
          path()..moveTo(p(.20, .50).dx, p(.20, .50).dy)..lineTo(p(.80, .50).dx, p(.80, .50).dy),
        ];
      case 'I':
        return [
          path()..moveTo(p(.50, 0).dx, p(.50, 0).dy)..lineTo(p(.50, 1).dx, p(.50, 1).dy),
        ];
      case 'J':
        return [
          path()..moveTo(p(.75, 0).dx, p(.75, 0).dy)..lineTo(p(.75, .76).dx, p(.75, .76).dy)..cubicTo(p(.75, 1).dx, p(.75, 1).dy, p(.25, 1.05).dx, p(.25, 1.05).dy, p(.20, .75).dx, p(.20, .75).dy),
        ];
      case 'K':
        return [
          path()..moveTo(p(.20, 0).dx, p(.20, 0).dy)..lineTo(p(.20, 1).dx, p(.20, 1).dy),
          path()..moveTo(p(.82, 0).dx, p(.82, 0).dy)..lineTo(p(.20, .52).dx, p(.20, .52).dy)..lineTo(p(.85, 1).dx, p(.85, 1).dy),
        ];
      case 'L':
        return [
          path()..moveTo(p(.20, 0).dx, p(.20, 0).dy)..lineTo(p(.20, 1).dx, p(.20, 1).dy)..lineTo(p(.85, 1).dx, p(.85, 1).dy),
        ];
      case 'M':
        return [
          path()..moveTo(p(.10, 1).dx, p(.10, 1).dy)..lineTo(p(.10, 0).dx, p(.10, 0).dy)..lineTo(p(.50, .55).dx, p(.50, .55).dy)..lineTo(p(.90, 0).dx, p(.90, 0).dy)..lineTo(p(.90, 1).dx, p(.90, 1).dy),
        ];
      case 'N':
        return [
          path()..moveTo(p(.18, 1).dx, p(.18, 1).dy)..lineTo(p(.18, 0).dx, p(.18, 0).dy)..lineTo(p(.82, 1).dx, p(.82, 1).dy)..lineTo(p(.82, 0).dx, p(.82, 0).dy),
        ];
      case 'O':
        return [
          path()..moveTo(p(.50, 0).dx, p(.50, 0).dy)..cubicTo(p(.10, 0).dx, p(.10, 0).dy, p(.10, 1).dx, p(.10, 1).dy, p(.50, 1).dx, p(.50, 1).dy)..cubicTo(p(.90, 1).dx, p(.90, 1).dy, p(.90, 0).dx, p(.90, 0).dy, p(.50, 0).dx, p(.50, 0).dy),
        ];
      case 'P':
        return [
          path()..moveTo(p(.20, 1).dx, p(.20, 1).dy)..lineTo(p(.20, 0).dx, p(.20, 0).dy)..cubicTo(p(.90, 0).dx, p(.90, 0).dy, p(.90, .52).dx, p(.90, .52).dy, p(.20, .52).dx, p(.20, .52).dy),
        ];
      case 'Q':
        return [
          path()..moveTo(p(.50, 0).dx, p(.50, 0).dy)..cubicTo(p(.10, 0).dx, p(.10, 0).dy, p(.10, 1).dx, p(.10, 1).dy, p(.50, 1).dx, p(.50, 1).dy)..cubicTo(p(.90, 1).dx, p(.90, 1).dy, p(.90, 0).dx, p(.90, 0).dy, p(.50, 0).dx, p(.50, 0).dy),
          path()..moveTo(p(.60, .70).dx, p(.60, .70).dy)..lineTo(p(.90, 1).dx, p(.90, 1).dy),
        ];
      case 'R':
        return [
          path()..moveTo(p(.20, 1).dx, p(.20, 1).dy)..lineTo(p(.20, 0).dx, p(.20, 0).dy)..cubicTo(p(.90, 0).dx, p(.90, 0).dy, p(.90, .50).dx, p(.90, .50).dy, p(.20, .50).dx, p(.20, .50).dy),
          path()..moveTo(p(.48, .50).dx, p(.48, .50).dy)..lineTo(p(.88, 1).dx, p(.88, 1).dy),
        ];
      case 'S':
        return [
          path()..moveTo(p(.82, .15).dx, p(.82, .15).dy)..cubicTo(p(.68, -.05).dx, p(.68, -.05).dy, p(.18, 0).dx, p(.18, 0).dy, p(.18, .28).dx, p(.18, .28).dy)..cubicTo(p(.18, .50).dx, p(.18, .50).dy, p(.82, .45).dx, p(.82, .45).dy, p(.82, .73).dx, p(.82, .73).dy)..cubicTo(p(.82, 1.02).dx, p(.82, 1.02).dy, p(.28, 1.05).dx, p(.28, 1.05).dy, p(.15, .85).dx, p(.15, .85).dy),
        ];
      case 'T':
        return [
          path()..moveTo(p(.10, 0).dx, p(.10, 0).dy)..lineTo(p(.90, 0).dx, p(.90, 0).dy),
          path()..moveTo(p(.50, 0).dx, p(.50, 0).dy)..lineTo(p(.50, 1).dx, p(.50, 1).dy),
        ];
      case 'U':
        return [
          path()..moveTo(p(.18, 0).dx, p(.18, 0).dy)..lineTo(p(.18, .72).dx, p(.18, .72).dy)..cubicTo(p(.18, 1.10).dx, p(.18, 1.10).dy, p(.82, 1.10).dx, p(.82, 1.10).dy, p(.82, .72).dx, p(.82, .72).dy)..lineTo(p(.82, 0).dx, p(.82, 0).dy),
        ];
      case 'V':
        return [
          path()..moveTo(p(.10, 0).dx, p(.10, 0).dy)..lineTo(p(.50, 1).dx, p(.50, 1).dy)..lineTo(p(.90, 0).dx, p(.90, 0).dy),
        ];
      case 'W':
        return [
          path()..moveTo(p(.05, 0).dx, p(.05, 0).dy)..lineTo(p(.25, 1).dx, p(.25, 1).dy)..lineTo(p(.50, .55).dx, p(.50, .55).dy)..lineTo(p(.75, 1).dx, p(.75, 1).dy)..lineTo(p(.95, 0).dx, p(.95, 0).dy),
        ];
      case 'X':
        return [
          path()..moveTo(p(.15, 0).dx, p(.15, 0).dy)..lineTo(p(.85, 1).dx, p(.85, 1).dy),
          path()..moveTo(p(.85, 0).dx, p(.85, 0).dy)..lineTo(p(.15, 1).dx, p(.15, 1).dy),
        ];
      case 'Y':
        return [
          path()..moveTo(p(.12, 0).dx, p(.12, 0).dy)..lineTo(p(.50, .48).dx, p(.50, .48).dy)..lineTo(p(.88, 0).dx, p(.88, 0).dy),
          path()..moveTo(p(.50, .48).dx, p(.50, .48).dy)..lineTo(p(.50, 1).dx, p(.50, 1).dy),
        ];
      case 'Z':
        return [
          path()..moveTo(p(.15, 0).dx, p(.15, 0).dy)..lineTo(p(.85, 0).dx, p(.85, 0).dy)..lineTo(p(.15, 1).dx, p(.15, 1).dy)..lineTo(p(.85, 1).dx, p(.85, 1).dy),
        ];
      case '0':
        return [
          path()..moveTo(p(.50, 0).dx, p(.50, 0).dy)..cubicTo(p(.15, 0).dx, p(.15, 0).dy, p(.15, 1).dx, p(.15, 1).dy, p(.50, 1).dx, p(.50, 1).dy)..cubicTo(p(.85, 1).dx, p(.85, 1).dy, p(.85, 0).dx, p(.85, 0).dy, p(.50, 0).dx, p(.50, 0).dy),
        ];
      case '1':
        return [
          path()..moveTo(p(.28, .23).dx, p(.28, .23).dy)..cubicTo(p(.42, .18).dx, p(.42, .18).dy, p(.55, .08).dx, p(.55, .08).dy, p(.62, 0).dx, p(.62, 0).dy)..lineTo(p(.62, 1).dx, p(.62, 1).dy),
        ];
      case '2':
        return [
          path()..moveTo(p(.18, .22).dx, p(.18, .22).dy)..cubicTo(p(.23, -.03).dx, p(.23, -.03).dy, p(.82, -.08).dx, p(.82, -.08).dy, p(.85, .24).dx, p(.85, .24).dy)..cubicTo(p(.87, .44).dx, p(.87, .44).dy, p(.28, .72).dx, p(.28, .72).dy, p(.15, 1).dx, p(.15, 1).dy)..lineTo(p(.88, 1).dx, p(.88, 1).dy),
        ];
      case '3':
        return [
          path()..moveTo(p(.20, .10).dx, p(.20, .10).dy)..cubicTo(p(.75, -.08).dx, p(.75, -.08).dy, p(.90, .23).dx, p(.90, .23).dy, p(.52, .48).dx, p(.52, .48).dy)..cubicTo(p(.93, .53).dx, p(.93, .53).dy, p(.88, 1.08).dx, p(.88, 1.08).dy, p(.18, .90).dx, p(.18, .90).dy),
        ];
      case '4':
        return [
          path()..moveTo(p(.70, 1).dx, p(.70, 1).dy)..lineTo(p(.70, 0).dx, p(.70, 0).dy),
          path()..moveTo(p(.70, 0).dx, p(.70, 0).dy)..lineTo(p(.15, .68).dx, p(.15, .68).dy)..lineTo(p(.90, .68).dx, p(.90, .68).dy),
        ];
      case '5':
        return [
          path()..moveTo(p(.82, 0).dx, p(.82, 0).dy)..lineTo(p(.22, 0).dx, p(.22, 0).dy)..lineTo(p(.18, .47).dx, p(.18, .47).dy)..cubicTo(p(.75, .34).dx, p(.75, .34).dy, p(.90, .55).dx, p(.90, .55).dy, p(.85, .74).dx, p(.85, .74).dy)..cubicTo(p(.80, 1.05).dx, p(.80, 1.05).dy, p(.30, 1.05).dx, p(.30, 1.05).dy, p(.15, .88).dx, p(.15, .88).dy),
        ];
      case '6':
        return [
          path()..moveTo(p(.78, .10).dx, p(.78, .10).dy)..cubicTo(p(.30, -.05).dx, p(.30, -.05).dy, p(.15, .35).dx, p(.15, .35).dy, p(.18, .65).dx, p(.18, .65).dy)..cubicTo(p(.20, 1.05).dx, p(.20, 1.05).dy, p(.82, 1.08).dx, p(.82, 1.08).dy, p(.85, .70).dx, p(.85, .70).dy)..cubicTo(p(.85, .42).dx, p(.85, .42).dy, p(.35, .38).dx, p(.35, .38).dy, p(.18, .65).dx, p(.18, .65).dy),
        ];
      case '7':
        return [
          path()..moveTo(p(.15, 0).dx, p(.15, 0).dy)..lineTo(p(.88, 0).dx, p(.88, 0).dy)..lineTo(p(.35, 1).dx, p(.35, 1).dy),
        ];
      case '8':
        return [
          path()..moveTo(p(.50, .50).dx, p(.50, .50).dy)..cubicTo(p(.12, .35).dx, p(.12, .35).dy, p(.15, 0).dx, p(.15, 0).dy, p(.50, 0).dx, p(.50, 0).dy)..cubicTo(p(.85, 0).dx, p(.85, 0).dy, p(.88, .35).dx, p(.88, .35).dy, p(.50, .50).dx, p(.50, .50).dy)..cubicTo(p(.10, .65).dx, p(.10, .65).dy, p(.15, 1).dx, p(.15, 1).dy, p(.50, 1).dx, p(.50, 1).dy)..cubicTo(p(.85, 1).dx, p(.85, 1).dy, p(.90, .65).dx, p(.90, .65).dy, p(.50, .50).dx, p(.50, .50).dy),
        ];
      case '9':
        return [
          path()..moveTo(p(.80, .43).dx, p(.80, .43).dy)..cubicTo(p(.65, .63).dx, p(.65, .63).dy, p(.18, .60).dx, p(.18, .60).dy, p(.15, .30).dx, p(.15, .30).dy)..cubicTo(p(.15, -.05).dx, p(.15, -.05).dy, p(.72, -.08).dx, p(.72, -.08).dy, p(.80, .25).dx, p(.80, .25).dy)..cubicTo(p(.90, .60).dx, p(.90, .60).dy, p(.72, .90).dx, p(.72, .90).dy, p(.35, 1).dx, p(.35, 1).dy),
        ];
      default:
        return [];
    }
  }
}