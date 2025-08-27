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

    test('empty table', () {
      expect(parseExpr('{}'), Table([]));
    });

    test('array-style tables', () {
      expect(parseExpr('{1}'), Table([Field(value: Number(1))]));
      expect(parseExpr('{1, 2}'),
          Table([Field(value: Number(1)), Field(value: Number(2))]));
      expect(
          parseExpr('{1, 2, 3}'),
          Table([
            Field(value: Number(1)),
            Field(value: Number(2)),
            Field(value: Number(3))
          ]));
    });

    test('named field tables', () {
      expect(parseExpr('{a = 1}'), Table([Field(name: 'a', value: Number(1))]));
      expect(parseExpr('{name = "test"}'),
          Table([Field(name: 'name', value: LuaString('test'))]));
      expect(
          parseExpr('{a = 1, b = 2}'),
          Table([
            Field(name: 'a', value: Number(1)),
            Field(name: 'b', value: Number(2))
          ]));
    });

    test('indexed field tables', () {
      expect(parseExpr('{[1] = "first"}'),
          Table([Field(index: Number(1), value: LuaString('first'))]));
      expect(parseExpr('{[x] = y}'),
          Table([Field(index: VarRef('x'), value: VarRef('y'))]));
    });

    test('mixed table syntax', () {
      expect(
          parseExpr('{1, a = 2, [3] = "third"}'),
          Table([
            Field(value: Number(1)),
            Field(name: 'a', value: Number(2)),
            Field(index: Number(3), value: LuaString('third'))
          ]));
    });

    test('nested tables', () {
      expect(parseExpr('{{}}'), Table([Field(value: Table([]))]));
      expect(
          parseExpr('{{}, {1}}'),
          Table([
            Field(value: Table([])),
            Field(value: Table([Field(value: Number(1))]))
          ]));
    });

    test('table with variables', () {
      expect(parseExpr('{x}'), Table([Field(value: VarRef('x'))]));
      expect(
          parseExpr('{a = y}'), Table([Field(name: 'a', value: VarRef('y'))]));
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

    test('table assignments', () {
      expect(parseStmt('x = {}'), Assign.single('x', Table([])));
      expect(
          parseStmt('x = {1, 2}'),
          Assign.single(
              'x', Table([Field(value: Number(1)), Field(value: Number(2))])));
      expect(parseStmt('x = {a = y}'),
          Assign.single('x', Table([Field(name: 'a', value: VarRef('y'))])));
    });
  });
}
