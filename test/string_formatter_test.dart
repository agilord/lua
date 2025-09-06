import 'package:lua/src/ast.dart';
import 'package:lua/src/formatter.dart';
import 'package:test/test.dart';

void main() {
  group('string formatting', () {
    test('basic strings are formatted with double quotes', () {
      expect(format(LuaString('hello')), '"hello"');
      expect(format(LuaString('world')), '"world"');
      expect(format(LuaString('')), '""');
    });

    test('strings with special characters are escaped', () {
      expect(format(LuaString('hello\nworld')), contains('hello'));
      expect(format(LuaString('tab\there')), contains('tab'));
      expect(format(LuaString('quote"here')), contains(r'quote\"here'));
      expect(
          format(LuaString(r'backslash\here')), contains(r'backslash\\here'));
    });

    test('strings with various content are handled', () {
      expect(format(LuaString('single\'quote')), '"single\'quote"');
      expect(format(LuaString('mixed "quotes" and \'apostrophes\'')),
          contains('mixed \\"quotes\\" and \'apostrophes\''));
    });

    test('multiline strings are formatted properly', () {
      final multiline = 'Line 1\nLine 2\nLine 3';
      expect(format(LuaString(multiline)), contains('Line 1'));
    });

    test('strings with control characters are escaped', () {
      expect(format(LuaString('\r\n')), contains('"'));
      expect(format(LuaString('\t')), contains('"'));
    });
  });
}
