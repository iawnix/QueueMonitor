import 'package:flutter/material.dart';

import '../models/bash_syntax.dart';

class ScriptEditorScreen extends StatefulWidget {
  const ScriptEditorScreen({super.key, required this.initialScript});

  final String initialScript;

  @override
  State<ScriptEditorScreen> createState() => _ScriptEditorScreenState();
}

class _ScriptEditorScreenState extends State<ScriptEditorScreen> {
  late final _controller = _BashTextEditingController(
    text: widget.initialScript,
  );
  final _textScroll = ScrollController();
  final _lineScroll = ScrollController();
  var _line = 1;
  var _column = 1;
  var _syncingLineScroll = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateCursorPosition);
    _textScroll.addListener(_syncLineScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_updateCursorPosition);
    _textScroll.removeListener(_syncLineScroll);
    _controller.dispose();
    _textScroll.dispose();
    _lineScroll.dispose();
    super.dispose();
  }

  void _syncLineScroll() {
    if (_syncingLineScroll || !_lineScroll.hasClients) {
      return;
    }
    final maxOffset = _lineScroll.position.maxScrollExtent;
    final offset = _textScroll.offset.clamp(0.0, maxOffset);
    _syncingLineScroll = true;
    _lineScroll.jumpTo(offset);
    _syncingLineScroll = false;
  }

  void _updateCursorPosition() {
    final offset = _controller.selection.baseOffset.clamp(
      0,
      _controller.text.length,
    );
    final beforeCursor = _controller.text.substring(0, offset);
    final line = '\n'.allMatches(beforeCursor).length + 1;
    final lastNewline = beforeCursor.lastIndexOf('\n');
    final column = offset - lastNewline;
    if (line == _line && column == _column) {
      return;
    }
    setState(() {
      _line = line;
      _column = column;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lineCount = _lineCount(_controller.text);
    final textStyle =
        Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontFamily: 'monospace',
          height: 1.45,
        ) ??
        const TextStyle(fontFamily: 'monospace', height: 1.45);
    _controller.syntaxTheme = _BashSyntaxTheme.fromTheme(Theme.of(context));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bash script'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(_controller.text),
            icon: const Icon(Icons.check),
            label: const Text('Save'),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Text(
              'Line $_line, Col $_column  |  $lineCount lines',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 54,
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  child: IgnorePointer(
                    child: SingleChildScrollView(
                      controller: _lineScroll,
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                      child: Text(
                        _lineNumbers(lineCount),
                        textAlign: TextAlign.right,
                        style: textStyle.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    scrollController: _textScroll,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(12),
                    ),
                    style: textStyle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _lineCount(String text) {
    if (text.isEmpty) {
      return 1;
    }
    return '\n'.allMatches(text).length + 1;
  }

  String _lineNumbers(int count) {
    return List.generate(count, (index) => '${index + 1}').join('\n');
  }
}

class _BashTextEditingController extends TextEditingController {
  _BashTextEditingController({required super.text});

  var syntaxTheme = _BashSyntaxTheme.fallback();

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    return TextSpan(
      style: base,
      children: [
        for (final token in BashSyntaxTokenizer.tokenize(text))
          TextSpan(
            text: token.text,
            style: syntaxTheme.styleFor(token.type, base),
          ),
      ],
    );
  }
}

class _BashSyntaxTheme {
  const _BashSyntaxTheme({
    required this.keyword,
    required this.string,
    required this.comment,
    required this.variable,
  });

  final Color keyword;
  final Color string;
  final Color comment;
  final Color variable;

  factory _BashSyntaxTheme.fromTheme(ThemeData theme) {
    final dark = theme.brightness == Brightness.dark;
    return _BashSyntaxTheme(
      keyword: dark ? const Color(0xff93c5fd) : const Color(0xff1d4ed8),
      string: dark ? const Color(0xfffbbf24) : const Color(0xffb45309),
      comment: dark ? const Color(0xff86efac) : const Color(0xff15803d),
      variable: dark ? const Color(0xffc4b5fd) : const Color(0xff7c3aed),
    );
  }

  factory _BashSyntaxTheme.fallback() {
    return const _BashSyntaxTheme(
      keyword: Color(0xff1d4ed8),
      string: Color(0xffb45309),
      comment: Color(0xff15803d),
      variable: Color(0xff7c3aed),
    );
  }

  TextStyle? styleFor(BashTokenType type, TextStyle base) {
    return switch (type) {
      BashTokenType.keyword => base.copyWith(
        color: keyword,
        fontWeight: FontWeight.w600,
      ),
      BashTokenType.string => base.copyWith(color: string),
      BashTokenType.comment => base.copyWith(color: comment),
      BashTokenType.variable => base.copyWith(color: variable),
      BashTokenType.plain => null,
    };
  }
}
