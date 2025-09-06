import 'package:lua/src/ast.dart';
import 'package:lua/src/evaluator.dart';
import 'package:lua/src/grammar.dart';
import 'package:test/test.dart';

void main() {
  group('string parsing', () {
    final grammar = LuaGrammarDefinition();
    final exprParser = grammar.buildFrom(grammar.expression());
    Expression parseExpr(String input) => exprParser.parse(input).value;

    test('double-quoted strings', () {
      expect(parseExpr('"hello"'), LuaString('hello'));
      expect(parseExpr('""'), LuaString(''));
      expect(parseExpr('"hello world"'), LuaString('hello world'));
    });

    test('single-quoted strings', () {
      expect(parseExpr("'hello'"), LuaString('hello'));
      expect(parseExpr("''"), LuaString(''));
      expect(parseExpr("'hello world'"), LuaString('hello world'));
    });

    test('long strings', () {
      expect(parseExpr('[[hello]]'), LuaString('hello'));
      expect(parseExpr('[[]]'), LuaString(''));
      expect(parseExpr('[[hello world]]'), LuaString('hello world'));
      expect(parseExpr('[[multi\nline\nstring]]'),
          LuaString('multi\nline\nstring'));
    });

    test('escape sequences', () {
      expect(parseExpr(r'"\n"'), LuaString('\n'));
      expect(parseExpr(r'"\t"'), LuaString('\t'));
      expect(parseExpr(r'"\r"'), LuaString('\r'));
      expect(parseExpr(r'"\b"'), LuaString('\b'));
      expect(parseExpr(r'"\f"'), LuaString('\f'));
      expect(parseExpr(r'"\a"'), LuaString('\x07'));
      expect(parseExpr(r'"\v"'), LuaString('\v'));
      expect(parseExpr(r'"\\"'), LuaString(r'\'));
      expect(parseExpr(r'"\""'), LuaString('"'));
      expect(parseExpr(r'"\0"'), LuaString('\x00'));
    });

    test('decimal escape sequences', () {
      expect(parseExpr(r'"\065"'), LuaString('A')); // ASCII 65 = 'A'
      expect(parseExpr(r'"\090"'), LuaString('Z')); // ASCII 90 = 'Z'
      expect(parseExpr(r'"\048"'), LuaString('0')); // ASCII 48 = '0'
    });

    test('hexadecimal escape sequences', () {
      expect(parseExpr(r'"\x41"'), LuaString('A')); // 0x41 = 65 = 'A'
      expect(parseExpr(r'"\x5A"'), LuaString('Z')); // 0x5A = 90 = 'Z'
      expect(parseExpr(r'"\x30"'), LuaString('0')); // 0x30 = 48 = '0'
      expect(parseExpr(r'"\x7E"'), LuaString('~')); // 0x7E = 126 = '~'
    });

    test('mixed escape sequences', () {
      expect(parseExpr(r'"Hello\nWorld"'), LuaString('Hello\nWorld'));
      expect(parseExpr(r'"Tab\tSeparated"'), LuaString('Tab\tSeparated'));
      expect(parseExpr(r'"Quote: \""'), LuaString('Quote: "'));
      expect(parseExpr(r'"Path\\to\\file"'), LuaString(r'Path\to\file'));
    });

    test('long strings preserve content literally', () {
      expect(parseExpr(r'[[No \n escape]]'), LuaString(r'No \n escape'));
      expect(parseExpr('[[Quotes "and" quotes]]'),
          LuaString('Quotes "and" quotes'));
      expect(parseExpr('[[Line 1\nLine 2\nLine 3]]'),
          LuaString('Line 1\nLine 2\nLine 3'));
    });

    test('complex string examples', () {
      expect(parseExpr(r'"\x48\x65\x6C\x6C\x6F"'), LuaString('Hello'));
      expect(parseExpr(r'"\072\101\108\108\111"'), LuaString('Hello'));
      expect(parseExpr(r'"Line 1\nLine 2\tIndented"'),
          LuaString('Line 1\nLine 2\tIndented'));
    });
  });

  group('string evaluation', () {
    test('basic string evaluation', () {
      final env = LuaEnv();

      expect(LuaString('hello').evaluate(env: env), 'hello');
      expect(LuaString('').evaluate(env: env), '');
      expect(LuaString('hello world').evaluate(env: env), 'hello world');
    });

    test('strings with special characters', () {
      final env = LuaEnv();

      expect(LuaString('hello\nworld').evaluate(env: env), 'hello\nworld');
      expect(LuaString('tab\there').evaluate(env: env), 'tab\there');
      expect(LuaString('quote"here').evaluate(env: env), 'quote"here');
      expect(LuaString("quote'here").evaluate(env: env), "quote'here");
    });
  });

  group('string integration with standard library', () {
    test('print with various string types', () {
      final env = LuaEnv.withStdlib();

      // Test double-quoted string
      Call('print', [LuaString('Hello World')]).evaluate(env: env);
      expect(env.getOutputLines().last, 'Hello World');
      env.clearOutput();

      // Test single-quoted equivalent
      Call('print', [LuaString('Hello World')]).evaluate(env: env);
      expect(env.getOutputLines().last, 'Hello World');
      env.clearOutput();

      // Test string with escapes
      Call('print', [LuaString('Line 1\nLine 2')]).evaluate(env: env);
      expect(env.getOutput(), 'Line 1\nLine 2\n');
      env.clearOutput();

      // Test long string
      Call('print', [LuaString('Multi\nline\nstring')]).evaluate(env: env);
      expect(env.getOutput(), 'Multi\nline\nstring\n');
    });

    test('type function with strings', () {
      final env = LuaEnv.withStdlib();

      expect(Call('type', [LuaString('hello')]).evaluate(env: env), 'string');
      expect(Call('type', [LuaString('')]).evaluate(env: env), 'string');
      expect(Call('type', [LuaString('with\nescapes')]).evaluate(env: env),
          'string');
    });

    test('tostring function with strings', () {
      final env = LuaEnv.withStdlib();

      expect(
          Call('tostring', [LuaString('hello')]).evaluate(env: env), 'hello');
      expect(Call('tostring', [LuaString('')]).evaluate(env: env), '');
      expect(Call('tostring', [LuaString('test\nstring')]).evaluate(env: env),
          'test\nstring');
    });
  });

  group('string concatenation', () {
    test('concatenate different string types', () {
      final env = LuaEnv();

      final result1 = Concatenate([LuaString('Hello'), LuaString(' World')])
          .evaluate(env: env);
      expect(result1, 'Hello World');

      final result2 = Concatenate([LuaString('Line 1\n'), LuaString('Line 2')])
          .evaluate(env: env);
      expect(result2, 'Line 1\nLine 2');
    });
  });

  group('string assignment and variables', () {
    test('string variables work correctly', () {
      final env = LuaEnv(variables: {
        'x': 'hello',
        'y': 'line1\nline2',
        'z': 'multiline\nstring'
      });

      expect(VarRef('x').evaluate(env: env), 'hello');
      expect(VarRef('y').evaluate(env: env), 'line1\nline2');
      expect(VarRef('z').evaluate(env: env), 'multiline\nstring');
    });
  });

  group('error handling', () {
    final grammar = LuaGrammarDefinition();
    final exprParser = grammar.buildFrom(grammar.expression());

    test('unterminated strings should fail parsing', () {
      expect(exprParser.parse('"unterminated').isFailure, true);
      expect(exprParser.parse("'unterminated").isFailure, true);
      expect(exprParser.parse('[[unterminated').isFailure, true);
    });

    test('invalid escape sequences are handled', () {
      final grammar = LuaGrammarDefinition();
      final exprParser = grammar.buildFrom(grammar.expression());

      // Invalid decimal escape (too high)
      expect(() {
        final result = exprParser.parse(r'"\999"');
        if (result.isSuccess) {
          final expr = result.value as LuaString;
          expr.evaluate(env: LuaEnv());
        }
      }, throwsA(isA<FormatException>()));
    });
  });
}
