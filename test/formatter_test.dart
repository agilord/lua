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
    });

    test('comparison', () {
      expect(true.lua().equals(1.lua()).format(), 'true==1');
      expect(true.lua().notEquals(1.lua()).format(), 'true~=1');
      expect(1.lua().lessThan(2.lua()).format(), '1<2');
      expect(1.lua().lessThanOrEquals(2.lua()).format(), '1<=2');
    });

    test('concatenate', () {
      expect(Concatenate([1.lua(), 'x'.lua(), 2.lua()]).format(), '1.."x"..2');
    });

    test('maths', () {
      expect(1.lua().plus(2.4.lua()).format(), '1+2.4');
      expect(1.lua().minus(2.4.lua()).format(), '1-2.4');
      expect(1.lua().multiply(2.4.lua()).format(), '1*2.4');
      expect(1.lua().divide(2.4.lua()).format(), '1/2.4');
      expect(1.lua().modulo(2.lua()).format(), '1%2');
      expect(2.lua().exponent(3.lua()).format(), '2^3');
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
              Return(values: [
                Add([VarRef('a'), VarRef('b')])
              ]),
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

  group('arithmetic expressions', () {
    test('integers and decimals', () {
      expect(format(Number(0)), '0');
      expect(format(Number(42)), '42');
      expect(format(Number(3.14)), '3.14');
      expect(format(Number(-5)), '-5');
    });

    test('string literals', () {
      expect(format(LuaString('hello')), '"hello"');
      expect(format(LuaString('')), '""');
      expect(format(LuaString('test')), '"test"');
    });

    test('variable references', () {
      expect(format(VarRef('x')), 'x');
      expect(format(VarRef('variable')), 'variable');
      expect(format(VarRef('test123')), 'test123');
    });

    test('single assignments', () {
      expect(format(Assign.single('x', Number(1))), 'x=1');
      expect(format(Assign.single('y', Bool(true))), 'y=true');
      expect(format(Assign.single('z', LuaString('hello'))), 'z="hello"');
      expect(format(Assign.single('var', VarRef('other'))), 'var=other');
    });

    test('local assignments', () {
      expect(format(Assign.single('x', Number(1), isLocal: true)), 'local x=1');
      expect(format(Assign.single('y', Bool(false), isLocal: true)),
          'local y=false');
    });

    test('function calls', () {
      expect(format(Call('print', [])), 'print()');
      expect(format(Call('func', [Number(1)])), 'func(1)');
      expect(format(Call('test', [Number(1), LuaString('hello')])),
          'test(1, "hello")');
      expect(format(Call('complex', [VarRef('x'), Bool(true), Nil()])),
          'complex(x, true, nil)');
    });
  });

  group('table formatting', () {
    test('empty table', () {
      expect(format(Table([])), '{}');
    });

    test('array-style tables', () {
      expect(format(Table([Field(value: Number(1))])), '{1}');
      expect(format(Table([Field(value: Number(1)), Field(value: Number(2))])),
          '{1, 2}');
      expect(
          format(Table([
            Field(value: Number(1)),
            Field(value: LuaString('hello')),
            Field(value: Bool(true))
          ])),
          '{1, "hello", true}');
    });

    test('named field tables', () {
      expect(format(Table([Field(name: 'a', value: Number(1))])), '{a=1}');
      expect(
          format(Table([
            Field(name: 'name', value: LuaString('test')),
            Field(name: 'age', value: Number(25))
          ])),
          '{name="test", age=25}');
    });

    test('indexed field tables', () {
      expect(
          format(Table([Field(index: Number(1), value: LuaString('first'))])),
          '{[1]="first"}');
      expect(
          format(Table([Field(index: VarRef('key'), value: VarRef('value'))])),
          '{[key]=value}');
      expect(
          format(Table([
            Field(index: LuaString('key1'), value: Number(1)),
            Field(index: LuaString('key2'), value: Number(2))
          ])),
          '{["key1"]=1, ["key2"]=2}');
    });

    test('mixed table syntax', () {
      expect(
          format(Table([
            Field(value: Number(1)),
            Field(name: 'a', value: Number(2)),
            Field(index: Number(3), value: LuaString('third'))
          ])),
          '{1, a=2, [3]="third"}');
    });

    test('nested tables', () {
      expect(format(Table([Field(value: Table([]))])), '{{}}');
      expect(
          format(Table([
            Field(value: Table([])),
            Field(value: Table([Field(value: Number(1))]))
          ])),
          '{{}, {1}}');
      expect(
          format(Table([
            Field(
                name: 'inner',
                value: Table([Field(name: 'value', value: Number(42))]))
          ])),
          '{inner={value=42}}');
    });

    test('table assignments', () {
      expect(format(Assign.single('x', Table([]))), 'x={}');
      expect(
          format(Assign.single(
              'config',
              Table([
                Field(name: 'name', value: LuaString('app')),
                Field(name: 'version', value: Number(1))
              ]))),
          'config={name="app", version=1}');
    });

    test('table with variables', () {
      expect(format(Table([Field(value: VarRef('x'))])), '{x}');
      expect(format(Table([Field(name: 'a', value: VarRef('y'))])), '{a=y}');
      expect(
          format(Table([
            Field(value: VarRef('first')),
            Field(name: 'second', value: VarRef('value')),
            Field(index: VarRef('key'), value: VarRef('val'))
          ])),
          '{first, second=value, [key]=val}');
    });
  });
}
