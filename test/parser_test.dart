import 'package:lua/src/ast.dart';
import 'package:lua/src/grammar.dart';
import 'package:test/test.dart';

void main() {
  group('basic expressions', () {
    final grammar = LuaGrammarDefinition();
    final exprParser = grammar.buildFrom(grammar.expression());
    Expression parseExpr(String input) => exprParser.parse(input).value;

    test('basic literals', () {
      expect(parseExpr('nil'), Nil());
      expect(parseExpr('true'), Bool(true));
      expect(parseExpr('false'), Bool(false));
    });

    test('numbers', () {
      expect(parseExpr('42'), Number(42));
      expect(parseExpr('3.14'), Number(3.14));
    });

    test('strings', () {
      expect(parseExpr('"hello"'), LuaString('hello'));
      expect(parseExpr('""'), LuaString(''));
    });

    test('variables', () {
      expect(parseExpr('x'), VarRef('x'));
    });
  });

  group('statements', () {
    final grammar = LuaGrammarDefinition();
    final stmtParser = grammar.buildFrom(grammar.statement());
    Statement parseStmt(String input) => stmtParser.parse(input).value;

    test('assignment', () {
      expect(parseStmt('x = 1'), Assign.single('x', Number(1)));
    });

    test('function calls', () {
      expect(parseStmt('print()'), Call('print', []));
    });
  });
}
