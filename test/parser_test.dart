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
      expect(parseExpr('t[x + y]'),
          Index(VarRef('t'), Add([VarRef('x'), VarRef('y')])));
    });
  });

  group('operator precedence', () {
    final grammar = LuaGrammarDefinition();
    final exprParser = grammar.buildFrom(grammar.expression());
    Expression parseExpr(String input) => exprParser.parse(input).value;

    test('arithmetic precedence - multiplication before addition', () {
      expect(
          parseExpr('2 + 3 * 4'),
          Add([
            Number(2),
            Multiply([Number(3), Number(4)])
          ]));
      expect(
          parseExpr('2 * 3 + 4'),
          Add([
            Multiply([Number(2), Number(3)]),
            Number(4)
          ]));
    });

    test('arithmetic precedence - division before subtraction', () {
      expect(parseExpr('10 - 8 / 2'),
          Subtract(Number(10), Divide(Number(8), Number(2))));
      expect(parseExpr('10 / 2 - 1'),
          Subtract(Divide(Number(10), Number(2)), Number(1)));
    });

    test('arithmetic precedence - modulo same as multiplication', () {
      expect(parseExpr('10 % 3 + 1'),
          Add([Modulo(Number(10), Number(3)), Number(1)]));
      expect(parseExpr('10 + 3 % 2'),
          Add([Number(10), Modulo(Number(3), Number(2))]));
    });

    test('arithmetic precedence - exponentiation before multiplication', () {
      expect(parseExpr('2 * 3 ^ 4'),
          Multiply([Number(2), Exponent(Number(3), Number(4))]));
      expect(parseExpr('2 ^ 3 * 4'),
          Multiply([Exponent(Number(2), Number(3)), Number(4)]));
    });

    test('arithmetic precedence - unary minus before addition', () {
      expect(parseExpr('-2 + 3'), Add([Negative(Number(2)), Number(3)]));
      expect(parseExpr('2 + -3'), Add([Number(2), Negative(Number(3))]));
    });

    test('arithmetic associativity - left associative for +, -, *, /, %', () {
      expect(
          parseExpr('1 + 2 + 3'),
          Add([
            Add([Number(1), Number(2)]),
            Number(3)
          ]));
      expect(parseExpr('1 - 2 - 3'),
          Subtract(Subtract(Number(1), Number(2)), Number(3)));
      expect(
          parseExpr('2 * 3 * 4'),
          Multiply([
            Multiply([Number(2), Number(3)]),
            Number(4)
          ]));
      expect(parseExpr('8 / 4 / 2'),
          Divide(Divide(Number(8), Number(4)), Number(2)));
    });

    test('arithmetic associativity - right associative for ^', () {
      expect(parseExpr('2 ^ 3 ^ 4'),
          Exponent(Number(2), Exponent(Number(3), Number(4))));
    });

    test('parentheses override precedence', () {
      expect(
          parseExpr('(2 + 3) * 4'),
          Multiply([
            Add([Number(2), Number(3)]),
            Number(4)
          ]));
      expect(
          parseExpr('2 * (3 + 4)'),
          Multiply([
            Number(2),
            Add([Number(3), Number(4)])
          ]));
    });

    test('comparison precedence - comparison before logical and', () {
      expect(parseExpr('1 < 2 and 3 > 2'),
          And([Less(Number(1), Number(2)), Greater(Number(3), Number(2))]));
      expect(
          parseExpr('x == y and a ~= b'),
          And([
            Equals(VarRef('x'), VarRef('y')),
            NotEquals(VarRef('a'), VarRef('b'))
          ]));
    });

    test('comparison precedence - comparison after arithmetic', () {
      expect(parseExpr('1 + 2 < 3 * 4'),
          Less(Add([Number(1), Number(2)]), Multiply([Number(3), Number(4)])));
      expect(
          parseExpr('x * 2 >= y - 1'),
          GreaterEq(Multiply([VarRef('x'), Number(2)]),
              Subtract(VarRef('y'), Number(1))));
    });

    test('logical precedence - and before or', () {
      expect(
          parseExpr('true or false and true'),
          Or([
            Bool(true),
            And([Bool(false), Bool(true)])
          ]));
      expect(
          parseExpr('a or b and c'),
          Or([
            VarRef('a'),
            And([VarRef('b'), VarRef('c')])
          ]));
    });

    test('logical precedence - not before and/or', () {
      expect(
          parseExpr('not true and false'), And([Not(Bool(true)), Bool(false)]));
      expect(parseExpr('not a or b'), Or([Not(VarRef('a')), VarRef('b')]));
    });

    test('concatenation precedence - before comparison', () {
      expect(
          parseExpr('"a" .. "b" == "ab"'),
          Equals(
              Concatenate([LuaString('a'), LuaString('b')]), LuaString('ab')));
    });

    test('concatenation associativity - right associative', () {
      expect(
          parseExpr('"a" .. "b" .. "c"'),
          Concatenate([
            LuaString('a'),
            Concatenate([LuaString('b'), LuaString('c')])
          ]));
    });

    test('length operator precedence - before arithmetic', () {
      expect(parseExpr('#t + 1'), Add([Length(VarRef('t')), Number(1)]));
      expect(parseExpr('1 + #t'), Add([Number(1), Length(VarRef('t'))]));
    });

    test('complex mixed precedence', () {
      // not x and y or z == w + v * u ^ 2
      expect(
          parseExpr('not x and y or z == w + v * u ^ 2'),
          Or([
            And([Not(VarRef('x')), VarRef('y')]),
            Equals(
                VarRef('z'),
                Add([
                  VarRef('w'),
                  Multiply([VarRef('v'), Exponent(VarRef('u'), Number(2))])
                ]))
          ]));
    });

    test('postfix operators have highest precedence', () {
      expect(parseExpr('t[1] + 2'),
          Add([Index(VarRef('t'), Number(1)), Number(2)]));
      expect(parseExpr('obj.field * 3'),
          Multiply([FieldAccess(VarRef('obj'), 'field'), Number(3)]));
      expect(parseExpr('func() ^ 2'), Exponent(Call('func', []), Number(2)));
    });
  });

  group('statements', () {
    final grammar = LuaGrammarDefinition();
    final stmtParser = grammar.buildFrom(grammar.statement());
    Statement parseStmt(String input) => stmtParser.parse(input).value;

    test('assignment', () {
      expect(parseStmt('x = 1'), Assign.single('x', Number(1)));
    });

    test('multiple assignment', () {
      expect(
          parseStmt('x, y = 1, 2'), Assign(['x', 'y'], [Number(1), Number(2)]));
      expect(parseStmt('a, b, c = true, false, nil'),
          Assign(['a', 'b', 'c'], [Bool(true), Bool(false), Nil()]));
    });

    test('multiple assignment with fewer values', () {
      expect(parseStmt('x, y = 1'), Assign(['x', 'y'], [Number(1)]));
    });

    test('multiple assignment with expressions', () {
      expect(
          parseStmt('x, y = a + b, c * d'),
          Assign([
            'x',
            'y'
          ], [
            Add([VarRef('a'), VarRef('b')]),
            Multiply([VarRef('c'), VarRef('d')])
          ]));
    });

    test('local assignment single', () {
      expect(parseStmt('local x = 1'),
          Assign.single('x', Number(1), isLocal: true));
    });

    test('local assignment multiple', () {
      expect(parseStmt('local x, y = 1, 2'),
          Assign(['x', 'y'], [Number(1), Number(2)], isLocal: true));
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
