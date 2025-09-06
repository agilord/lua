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

    test('table indexing with brackets', () {
      expect(parseExpr('t[1]'), Index(VarRef('t'), Number(1)));
      expect(parseExpr('t[key]'), Index(VarRef('t'), VarRef('key')));
      expect(parseExpr('t["name"]'), Index(VarRef('t'), LuaString('name')));
    });

    test('table field access with dot', () {
      expect(parseExpr('t.name'), FieldAccess(VarRef('t'), 'name'));
      expect(parseExpr('t.field'), FieldAccess(VarRef('t'), 'field'));
    });

    test('nested table indexing', () {
      expect(parseExpr('t[1][2]'),
          Index(Index(VarRef('t'), Number(1)), Number(2)));
      expect(
          parseExpr('t.a.b'), FieldAccess(FieldAccess(VarRef('t'), 'a'), 'b'));
      expect(parseExpr('t[key].field'),
          FieldAccess(Index(VarRef('t'), VarRef('key')), 'field'));
      expect(parseExpr('t.field[1]'),
          Index(FieldAccess(VarRef('t'), 'field'), Number(1)));
    });

    test('complex table indexing expressions', () {
      expect(parseExpr('({})[1]'), Index(Table([]), Number(1)));
      // Note: arithmetic expressions in index not yet supported due to operator precedence
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

  group('control flow statements', () {
    final grammar = LuaGrammarDefinition();
    final stmtParser = grammar.buildFrom(grammar.statement());
    Statement parseStmt(String input) => stmtParser.parse(input).value;

    test('if statement', () {
      expect(
        parseStmt('if x then\n  print()\nend'),
        If(VarRef('x'), Block([Call('print', [])])),
      );
    });

    test('if-else statement', () {
      expect(
        parseStmt('if x then\n  print()\nelse\n  call()\nend'),
        If(
          VarRef('x'),
          Block([Call('print', [])]),
          elseBlock: Block([Call('call', [])]),
        ),
      );
    });

    test('if-elseif-else statement', () {
      expect(
        parseStmt(
            'if x then\n  print()\nelseif y then\n  call()\nelse\n  other()\nend'),
        If(
          VarRef('x'),
          Block([Call('print', [])]),
          elseIfs: [
            ElseIf(VarRef('y'), Block([Call('call', [])]))
          ],
          elseBlock: Block([Call('other', [])]),
        ),
      );
    });

    test('while statement', () {
      expect(
        parseStmt('while x do\n  print()\nend'),
        While(VarRef('x'), Block([Call('print', [])])),
      );
    });

    test('for statement', () {
      expect(
        parseStmt('for i = 1, 10 do\n  print()\nend'),
        For(
          name: 'i',
          init: Number(1),
          stop: Number(10),
          block: Block([Call('print', [])]),
        ),
      );
    });

    test('for statement with increment', () {
      expect(
        parseStmt('for i = 1, 10, 2 do\n  print()\nend'),
        For(
          name: 'i',
          init: Number(1),
          stop: Number(10),
          increment: Number(2),
          block: Block([Call('print', [])]),
        ),
      );
    });

    test('function definition', () {
      expect(
        parseStmt('function add(a, b)\n  return a\nend'),
        FunctionDef(
          'add',
          ['a', 'b'],
          Block([
            Return(values: [VarRef('a')])
          ]),
        ),
      );
    });

    // TODO: Fix local function parsing
    // test('local function definition', () {
    //   expect(
    //     parseStmt('local function helper()\n  print()\nend'),
    //     FunctionDef(
    //       'helper',
    //       [],
    //       Block([Call('print', [])]),
    //       isLocal: true,
    //     ),
    //   );
    // });

    test('return statement', () {
      expect(parseStmt('return'), Return());
      expect(parseStmt('return 42'), Return(values: [Number(42)]));
      expect(
        parseStmt('return x, y'),
        Return(values: [VarRef('x'), VarRef('y')]),
      );
    });

    test('break statement', () {
      expect(parseStmt('break'), Break());
    });
  });
}
