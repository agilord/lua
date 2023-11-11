import 'package:lua/src/ast.dart';
import 'package:lua/src/grammar.dart';
import 'package:test/test.dart';

void main() {
  group('expressions', () {
    final grammar = LuaGrammarDefinition();
    final parser = grammar.buildFrom(grammar.expression());
    Expression parse(String input) => parser.parse(input).value;

    test('basic literals', () {
      expect(parse('nil'), Nil());
      expect(parse('true'), Bool(true));
      expect(parse('false'), Bool(false));
    });
  });
}
