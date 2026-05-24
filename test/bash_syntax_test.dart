import 'package:queue_monitor/models/bash_syntax.dart';
import 'package:test/test.dart';

void main() {
  test('tokenizes bash keywords comments strings and variables', () {
    final tokens = BashSyntaxTokenizer.tokenize(
      r'''if [[ "$USER" == root ]]; then # admin
echo ${HOME}
fi
''',
    );

    expect(
      tokens.any(
        (token) => token.type == BashTokenType.keyword && token.text == 'if',
      ),
      isTrue,
    );
    expect(
      tokens.any(
        (token) =>
            token.type == BashTokenType.string && token.text == r'"$USER"',
      ),
      isTrue,
    );
    expect(
      tokens.any(
        (token) =>
            token.type == BashTokenType.comment && token.text == '# admin',
      ),
      isTrue,
    );
    expect(
      tokens.any(
        (token) =>
            token.type == BashTokenType.variable && token.text == r'${HOME}',
      ),
      isTrue,
    );
  });
}
