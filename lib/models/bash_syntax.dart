enum BashTokenType { plain, keyword, string, comment, variable }

class BashToken {
  const BashToken(this.type, this.text);

  final BashTokenType type;
  final String text;
}

class BashSyntaxTokenizer {
  static const _keywords = {
    'if',
    'then',
    'elif',
    'else',
    'fi',
    'for',
    'while',
    'do',
    'done',
    'case',
    'esac',
    'function',
    'select',
    'until',
    'in',
    'time',
    'coproc',
    'local',
    'readonly',
    'export',
    'return',
    'exit',
    'break',
    'continue',
    'shift',
    'set',
    'unset',
    'test',
    'true',
    'false',
  };

  static List<BashToken> tokenize(String source) {
    final tokens = <BashToken>[];
    var index = 0;
    while (index < source.length) {
      final char = source[index];

      if (char == '#') {
        final end = _lineEnd(source, index);
        _add(tokens, BashTokenType.comment, source.substring(index, end));
        index = end;
        continue;
      }

      if (char == "'" || char == '"') {
        final end = _quotedEnd(source, index, char);
        _add(tokens, BashTokenType.string, source.substring(index, end));
        index = end;
        continue;
      }

      if (char == r'$') {
        final end = _variableEnd(source, index);
        if (end > index + 1) {
          _add(tokens, BashTokenType.variable, source.substring(index, end));
          index = end;
          continue;
        }
      }

      if (_isWordStart(char)) {
        final end = _wordEnd(source, index);
        final text = source.substring(index, end);
        _add(
          tokens,
          _keywords.contains(text)
              ? BashTokenType.keyword
              : BashTokenType.plain,
          text,
        );
        index = end;
        continue;
      }

      _add(tokens, BashTokenType.plain, char);
      index += 1;
    }
    return tokens;
  }

  static void _add(List<BashToken> tokens, BashTokenType type, String text) {
    if (text.isEmpty) {
      return;
    }
    if (tokens.isNotEmpty && tokens.last.type == type) {
      final previous = tokens.removeLast();
      tokens.add(BashToken(type, previous.text + text));
      return;
    }
    tokens.add(BashToken(type, text));
  }

  static int _lineEnd(String source, int start) {
    final end = source.indexOf('\n', start);
    return end < 0 ? source.length : end;
  }

  static int _quotedEnd(String source, int start, String quote) {
    var index = start + 1;
    while (index < source.length) {
      if (quote == '"' && source[index] == '\\') {
        index += 2;
        continue;
      }
      if (source[index] == quote) {
        return index + 1;
      }
      index += 1;
    }
    return source.length;
  }

  static int _variableEnd(String source, int start) {
    if (start + 1 >= source.length) {
      return start + 1;
    }
    final next = source[start + 1];
    if (next == '{') {
      final end = source.indexOf('}', start + 2);
      return end < 0 ? source.length : end + 1;
    }
    if (next == '(') {
      return start + 2;
    }
    if (!_isVariableChar(next)) {
      return start + 1;
    }
    var index = start + 2;
    while (index < source.length && _isVariableChar(source[index])) {
      index += 1;
    }
    return index;
  }

  static int _wordEnd(String source, int start) {
    var index = start + 1;
    while (index < source.length && _isWordPart(source[index])) {
      index += 1;
    }
    return index;
  }

  static bool _isWordStart(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122) ||
        char == '_';
  }

  static bool _isWordPart(String char) {
    final code = char.codeUnitAt(0);
    return _isWordStart(char) || (code >= 48 && code <= 57) || char == '-';
  }

  static bool _isVariableChar(String char) {
    final code = char.codeUnitAt(0);
    return _isWordStart(char) || (code >= 48 && code <= 57);
  }
}
