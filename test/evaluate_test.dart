import 'package:lua/src/ast.dart';
import 'package:lua/src/evaluator.dart';
import 'package:test/test.dart';

void main() {
  group('expressions', () {
    test('basic literals', () {
      expect(Nil().evaluate(), null);
      expect(Bool(true).evaluate(), true);
      expect(Bool(false).evaluate(), false);
      expect(Number(1).evaluate(), 1);
      expect(Number(1.2).evaluate(), 1.2);
      expect(LuaString('x').evaluate(), 'x');
      expect(Table([]).evaluate(), TableInstance());
      expect(
        Table([
          Field(value: Bool(true)),
          Field(name: 'x', value: Bool(false)),
          Field(index: Number(4), value: Nil()),
        ]).evaluate(),
        TableInstance.fromMap({1: true, 'x': false, 4: null}),
      );
    });

    test('boolean operators', () {
      expect(Bool(false).and(Bool(true)).evaluate(), false);
      expect(Bool(true).and(Bool(true)).evaluate(), true);
      expect(Bool(false).or(Bool(true)).evaluate(), true);
      expect(Bool(false).or(Bool(false)).evaluate(), false);
      expect(Bool(true).not().evaluate(), false);
    });

    test('comparisons', () {
      expect(true.lua().equals(false.lua()).evaluate(), false);
      expect(2.lua().equals(2.lua()).evaluate(), true);
      expect(2.lua().notEquals(2.lua()).evaluate(), false);
      expect(1.lua().lessThan(2.lua()).evaluate(), true);
      expect(2.lua().lessThanOrEquals(2.lua()).evaluate(), true);
      expect(3.lua().lessThanOrEquals(2.lua()).evaluate(), false);
      expect(1.lua().greaterThan(2.lua()).evaluate(), false);
      expect(2.lua().greaterThanOrEquals(2.lua()).evaluate(), true);
      expect(3.lua().greaterThanOrEquals(2.lua()).evaluate(), true);
    });

    test('concatenate', () {
      expect(1.lua().concatenate('x'.lua()).evaluate(), '1x');
    });

    test('maths', () {
      expect(1.lua().plus(2.4.lua()).evaluate(), 3.4);
      expect(1.lua().minus(2.4.lua()).evaluate(), -1.4);
      expect(2.lua().multiply(2.4.lua()).evaluate(), 4.8);
      expect(2.4.lua().divide(2.lua()).evaluate(), 1.2);
      expect(4.lua().modulo(3.lua()).evaluate(), 1);
      expect(2.lua().exponent(3.lua()).evaluate(), 8);
    });

    test('integer operators', () {
      expect(2.lua().negative().evaluate(), -2);
      expect(Length(Table([Field(value: 1.lua())])).evaluate(), 1);
    });

    test('assign and ref', () {
      expect(
        Block([
          Assign.single('a', 2.lua(), isLocal: true),
          Assign.single('b', 1.lua(), isLocal: true),
          Assign(['a', 'b'], [VarRef('b'), VarRef('a')]),
        ]).evaluate(),
        [1, 2],
      );
    });

    test('return from block', () {
      expect(
          Block([
            Return(values: [1.lua(), 2.lua()]),
          ]).evaluate(),
          [1, 2]);
    });

    test('while', () {
      expect(
          While(
            VarRef<int>('a').lessThan(5.lua()),
            Block([Assign.single('a', VarRef<int>('a').plus(1.lua()))]),
          ).evaluate(env: LuaEnv(variables: {'a': 1})),
          5);
    });

    test('repeat', () {
      expect(
          Repeat(
            Block([Assign.single('a', VarRef<int>('a').plus(1.lua()))]),
            VarRef<int>('a').lessThan(5.lua()),
          ).evaluate(env: LuaEnv(variables: {'a': 1})),
          5);
    });
  });

  group('arithmetic expressions', () {
    test('numbers evaluation', () {
      expect(Number(0).evaluate(), 0);
      expect(Number(42).evaluate(), 42);
      expect(Number(3.14).evaluate(), 3.14);
      expect(Number(-5).evaluate(), -5);
    });

    test('strings evaluation', () {
      expect(LuaString('hello').evaluate(), 'hello');
      expect(LuaString('').evaluate(), '');
      expect(LuaString('test').evaluate(), 'test');
    });

    test('variable references with environment', () {
      final env = LuaEnv(variables: {'x': 42, 'name': 'test'});
      expect(VarRef('x').evaluate(env: env), 42);
      expect(VarRef('name').evaluate(env: env), 'test');
    });

    test('variable reference error for unknown variable', () {
      expect(
        () => VarRef('unknown').evaluate(),
        throwsA(isA<EvaluationException>()),
      );
    });

    test('local variable assignment', () {
      final result = Assign.single('x', Number(42), isLocal: true).evaluate();
      expect(result, 42);
    });

    test('multiple variable assignment', () {
      final result =
          Assign(['a', 'b'], [Number(1), Number(2)], isLocal: true).evaluate();
      expect(result, [1, 2]);
    });

    test('assignment with fewer values than names', () {
      final result =
          Assign(['a', 'b', 'c'], [Number(1)], isLocal: true).evaluate();
      expect(result, [1, null, null]);
    });

    test('variable assignment and reference', () {
      final block = Block([
        Assign.single('x', Number(10), isLocal: true),
        VarRef('x'),
      ]);
      expect(block.evaluate(), 10);
    });

    test('complex variable operations', () {
      final block = Block([
        Assign.single('a', Number(5), isLocal: true),
        Assign.single('b', Number(3), isLocal: true),
        Add([VarRef('a'), VarRef('b')]),
      ]);
      expect(block.evaluate(), 8);
    });

    test('function call throws not implemented', () {
      expect(
        () => Call('print', []).evaluate(),
        throwsA(isA<EvaluationException>()),
      );

      expect(
        () =>
            Call('unknown_function', [Number(1), LuaString('test')]).evaluate(),
        throwsA(isA<EvaluationException>()),
      );
    });

    test('assignment scoping', () {
      final env = LuaEnv(variables: {'global': 'initial'});

      // Try to assign to non-existent variable (should throw)
      expect(
        () => Assign.single('nonexistent', Number(42)).evaluate(env: env),
        throwsA(isA<ArgumentError>()),
      );

      // Local assignment should work
      expect(
        Assign.single('local_var', Number(42), isLocal: true)
            .evaluate(env: env),
        42,
      );
    });
  });

  group('table evaluation', () {
    test('empty table', () {
      expect(Table([]).evaluate(), TableInstance());
    });

    test('array-style tables', () {
      expect(Table([Field(value: Number(1))]).evaluate(),
          TableInstance.fromMap({1: 1}));
      expect(
          Table([Field(value: Number(1)), Field(value: Number(2))]).evaluate(),
          TableInstance.fromMap({1: 1, 2: 2}));
      expect(
          Table([
            Field(value: Number(42)),
            Field(value: LuaString('hello')),
            Field(value: Bool(true))
          ]).evaluate(),
          TableInstance.fromMap({1: 42, 2: 'hello', 3: true}));
    });

    test('named field tables', () {
      expect(Table([Field(name: 'a', value: Number(1))]).evaluate(),
          TableInstance.fromMap({'a': 1}));
      expect(
          Table([
            Field(name: 'name', value: LuaString('test')),
            Field(name: 'age', value: Number(25))
          ]).evaluate(),
          TableInstance.fromMap({'name': 'test', 'age': 25}));
    });

    test('indexed field tables', () {
      expect(
          Table([Field(index: Number(1), value: LuaString('first'))])
              .evaluate(),
          TableInstance.fromMap({1: 'first'}));
      expect(
          Table([
            Field(index: LuaString('key1'), value: Number(1)),
            Field(index: LuaString('key2'), value: Number(2))
          ]).evaluate(),
          TableInstance.fromMap({'key1': 1, 'key2': 2}));
    });

    test('mixed table syntax', () {
      expect(
          Table([
            Field(value: Number(1)),
            Field(name: 'a', value: Number(2)),
            Field(index: Number(3), value: LuaString('third'))
          ]).evaluate(),
          TableInstance.fromMap({1: 1, 'a': 2, 3: 'third'}));

      expect(
          Table([
            Field(value: LuaString('first')),
            Field(value: LuaString('second')),
            Field(name: 'named', value: Number(42)),
            Field(index: LuaString('key'), value: Bool(true))
          ]).evaluate(),
          TableInstance.fromMap(
              {1: 'first', 2: 'second', 'named': 42, 'key': true}));
    });

    test('nested tables', () {
      expect(Table([Field(value: Table([]))]).evaluate(),
          TableInstance.fromMap({1: TableInstance()}));

      final inner1 = TableInstance.fromMap({1: 1});
      final inner2 = TableInstance.fromMap({1: 2});
      expect(
          Table([
            Field(value: Table([Field(value: Number(1))])),
            Field(value: Table([Field(value: Number(2))]))
          ]).evaluate(),
          TableInstance.fromMap({1: inner1, 2: inner2}));

      final nestedTable = TableInstance.fromMap({'value': 42});
      expect(
          Table([
            Field(
                name: 'inner',
                value: Table([Field(name: 'value', value: Number(42))]))
          ]).evaluate(),
          TableInstance.fromMap({'inner': nestedTable}));
    });

    test('table with variable references', () {
      final env = LuaEnv(
          variables: {'x': 10, 'y': 'hello', 'key': 'mykey', 'value': 99});

      expect(Table([Field(value: VarRef('x'))]).evaluate(env: env),
          TableInstance.fromMap({1: 10}));

      expect(Table([Field(name: 'a', value: VarRef('y'))]).evaluate(env: env),
          TableInstance.fromMap({'a': 'hello'}));

      expect(
          Table([Field(index: VarRef('key'), value: VarRef('value'))])
              .evaluate(env: env),
          TableInstance.fromMap({'mykey': 99}));
    });

    test('table assignments', () {
      final result = Assign.single('x', Table([]), isLocal: true).evaluate();
      expect(result, TableInstance());

      final block = Block([
        Assign.single(
            'config',
            Table([
              Field(name: 'name', value: LuaString('app')),
              Field(name: 'version', value: Number(1))
            ]),
            isLocal: true),
        VarRef('config')
      ]);
      expect(block.evaluate(),
          TableInstance.fromMap({'name': 'app', 'version': 1}));
    });

    test('table length operation', () {
      expect(Length(Table([])).evaluate(), 0);
      expect(Length(Table([Field(value: Number(1))])).evaluate(), 1);
      expect(
          Length(Table([
            Field(value: Number(1)),
            Field(value: Number(2)),
            Field(value: Number(3))
          ])).evaluate(),
          3);

      // Length only counts fields, not distinguished by type
      expect(
          Length(Table([
            Field(value: Number(1)),
            Field(name: 'a', value: Number(2)),
            Field(index: LuaString('key'), value: Number(3))
          ])).evaluate(),
          3);
    });

    test('complex table expressions', () {
      final env = LuaEnv(variables: {'multiplier': 2});

      final block = Block([
        Assign.single(
            'data',
            Table([
              Field(
                  name: 'values',
                  value: Table([
                    Field(value: Number(1)),
                    Field(value: Number(2)),
                    Field(value: Number(3))
                  ])),
              Field(
                  name: 'config',
                  value: Table(
                      [Field(name: 'scale', value: VarRef('multiplier'))]))
            ]),
            isLocal: true),
        VarRef('data')
      ]);

      final expectedInnerValues = TableInstance.fromMap({1: 1, 2: 2, 3: 3});
      final expectedInnerConfig = TableInstance.fromMap({'scale': 2});
      final expectedResult = TableInstance.fromMap(
          {'values': expectedInnerValues, 'config': expectedInnerConfig});

      expect(block.evaluate(env: env), expectedResult);
    });

    test('table equality', () {
      // Two identical empty tables
      final table1 = Table([]).evaluate();
      final table2 = Table([]).evaluate();
      expect(table1, table2);

      // Two identical tables with values
      final table3 =
          Table([Field(name: 'a', value: Number(1)), Field(value: Number(2))])
              .evaluate();
      final table4 =
          Table([Field(name: 'a', value: Number(1)), Field(value: Number(2))])
              .evaluate();
      expect(table3, table4);

      // Different tables
      final table5 = Table([Field(value: Number(1))]).evaluate();
      final table6 = Table([Field(value: Number(2))]).evaluate();
      expect(table5, isNot(table6));
    });
  });
}
