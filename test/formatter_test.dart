import 'package:lua/src/ast.dart';
import 'package:lua/src/formatter.dart';
import 'package:test/test.dart';

void main() {
  group('expressions', () {
    test('basic literals', () {
      expect(format(Nil()), 'nil');
      expect(format(Bool(true)), 'true');
      expect(format(Bool(false)), 'false');
      expect(format(Number(-1)), '-1');
      expect(format(Number(2.12)), '2.12');
      expect(format(LuaString('')), '""');
      expect(format(LuaString('x')), '"x"');
      expect(format(LuaString('\'"\\')), '"\'\\"\\\\"');
      expect(format(Table([])), '{}');
      expect(
        format(Table([
          Field(value: Bool(true)),
          Field(name: 'x', value: Bool(false)),
          Field(index: Number(3), value: Nil()),
        ])),
        '{true, x=false, [3]=nil}',
      );
    });

    test('bool expressions', () {
      expect(And([Bool(true), Bool(false)]).format(), 'true and false');
      expect(
          And([
            Bool(true),
            Or([Bool(false)])
          ]).format(),
          'true and (false)');
      expect(true.lua().equals(1.lua()).format(), 'true==1');
      expect(true.lua().notEquals(1.lua()).format(), 'true~=1');
    });
  });

  group('statements', () {
    test('empty block', () {
      expect(format(Block([])), '');
    });

    test('assignment', () {
      expect(
        format(Assign(['x', 'y'], [Number(1), Bool(false)])),
        'x, y=1, false',
      );
    });

    test('call', () {
      expect(
        format(Call('print', [VarRef('x'), LuaString('x')])),
        'print(x, "x")',
      );
    });

    test('do', () {
      expect(
        format(Do(Block([
          Call('print', [VarRef('x')])
        ]))),
        'do\n'
        '  print(x)\n'
        'end',
      );
    });

    test('while', () {
      expect(
        format(While(VarRef('x'), Block([Call('print', [])]))),
        'while x do \n'
        '  print()\n'
        'end',
      );
    });

    test('repeat', () {
      expect(
        format(Repeat(Block([Call('print', [])]), VarRef('x'))),
        'repeat\n'
        '  print()\n'
        'until x',
      );
    });

    test('if', () {
      expect(
        format(If(VarRef('x'), Block([Call('print', [])]))),
        'if x then\n'
        '  print()\n'
        'end',
      );
    });

    test('if-else', () {
      expect(
        format(If(
          VarRef('x'),
          Block([Call('print', [])]),
          elseIfs: [
            ElseIf(VarRef('y'), Block([Call('z', [])]))
          ],
          elseBlock: Block([Call('zz', [])]),
        )),
        'if x then\n'
        '  print()\n'
        'elseif y\n'
        '  z()\n'
        'else\n'
        '  zz()\n'
        'end',
      );
    });

    test('for', () {
      expect(
        format(For(
          name: 'x',
          init: VarRef('a'),
          stop: VarRef('b'),
          increment: Number(2),
          block: Block([Call('print', [])]),
        )),
        'for x = a, b, 2 do\n'
        '  print()\n'
        'end',
      );
    });

    test('foreach', () {
      expect(
        format(ForEach(
          ['i', 'v'],
          [
            Call('items', [Table([])])
          ],
          Block([Call('print', [])]),
        )),
        'for i, v in items({}) do\n'
        '  print()\n'
        'end',
      );
    });

    test('function', () {
      expect(
        format(
          FunctionDef(
            'add',
            ['a', 'b'],
            Block([
              Return(values: [BinOp(VarRef('a'), '+', VarRef('b'))]),
            ]),
          ),
        ),
        'function add(a, b)\n'
        '  return a+b\n'
        'end',
      );
    });

    test('return', () {
      expect(format(Return()), 'return');
      expect(format(Return(values: [Number(2)])), 'return 2');
    });
  });

  group('samples', () {
    test('sample #1', () {});
  });
}
