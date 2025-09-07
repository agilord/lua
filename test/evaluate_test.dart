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

      // Assign to non-existent variable (should create global)
      expect(
        Assign.single('nonexistent', Number(42)).evaluate(env: env),
        42,
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

  group('table indexing evaluation', () {
    test('basic table indexing with numbers', () {
      final env = LuaEnv(variables: {
        'table': TableInstance.fromMap({1: 'first', 2: 'second', 3: 'third'})
      });

      expect(Index(VarRef('table'), Number(1)).evaluate(env: env), 'first');
      expect(Index(VarRef('table'), Number(2)).evaluate(env: env), 'second');
      expect(Index(VarRef('table'), Number(3)).evaluate(env: env), 'third');
    });

    test('basic table indexing with string keys', () {
      final env = LuaEnv(variables: {
        'table':
            TableInstance.fromMap({'name': 'John', 'age': 30, 'city': 'NYC'})
      });

      expect(
          Index(VarRef('table'), LuaString('name')).evaluate(env: env), 'John');
      expect(Index(VarRef('table'), LuaString('age')).evaluate(env: env), 30);
      expect(
          Index(VarRef('table'), LuaString('city')).evaluate(env: env), 'NYC');
    });

    test('field access with dot notation', () {
      final env = LuaEnv(variables: {
        'table': TableInstance.fromMap({
          'name': 'Alice',
          'score': 95,
        })
      });

      expect(FieldAccess(VarRef('table'), 'name').evaluate(env: env), 'Alice');
      expect(FieldAccess(VarRef('table'), 'score').evaluate(env: env), 95);
    });

    test('nested table indexing', () {
      final env = LuaEnv(variables: {
        'table': TableInstance.fromMap({
          'point': TableInstance.fromMap({'x': 10, 'y': 20}),
          1: 42,
        })
      });

      expect(
          FieldAccess(FieldAccess(VarRef('table'), 'point'), 'x')
              .evaluate(env: env),
          10);
      expect(
          FieldAccess(FieldAccess(VarRef('table'), 'point'), 'y')
              .evaluate(env: env),
          20);
      expect(Index(VarRef('table'), Number(1)).evaluate(env: env), 42);
    });

    test('indexing with variable keys', () {
      final env = LuaEnv(variables: {
        'table': TableInstance.fromMap({'key1': 'value1', 'key2': 'value2'}),
        'k1': 'key1',
        'k2': 'key2',
      });

      expect(Index(VarRef('table'), VarRef('k1')).evaluate(env: env), 'value1');
      expect(Index(VarRef('table'), VarRef('k2')).evaluate(env: env), 'value2');
    });

    test('indexing non-existent keys returns nil', () {
      final env = LuaEnv(variables: {
        'table': TableInstance.fromMap({'existing': 1})
      });

      expect(Index(VarRef('table'), LuaString('missing')).evaluate(env: env),
          null);
      expect(FieldAccess(VarRef('table'), 'missing').evaluate(env: env), null);
    });

    test('mixed indexing and field access', () {
      final env = LuaEnv(variables: {
        'table': TableInstance.fromMap({
          'data': TableInstance.fromMap({1: 'item1', 2: 'item2'}),
          'config': TableInstance.fromMap({'enabled': true}),
        })
      });

      expect(
          Index(FieldAccess(VarRef('table'), 'data'), Number(1))
              .evaluate(env: env),
          'item1');
      expect(
          FieldAccess(FieldAccess(VarRef('table'), 'config'), 'enabled')
              .evaluate(env: env),
          true);
    });

    test('error on indexing non-table values', () {
      expect(() => Index(Number(42), Number(1)).evaluate(),
          throwsA(isA<EvaluationException>()));
      expect(() => FieldAccess(LuaString('not_a_table'), 'field').evaluate(),
          throwsA(isA<EvaluationException>()));
    });

    test('complex table access patterns', () {
      final env = LuaEnv(variables: {
        'users': TableInstance.fromMap({
          1: TableInstance.fromMap({'name': 'Alice', 'id': 101}),
          2: TableInstance.fromMap({'name': 'Bob', 'id': 102}),
        })
      });

      expect(
          FieldAccess(Index(VarRef('users'), Number(1)), 'name')
              .evaluate(env: env),
          'Alice');
      expect(
          FieldAccess(Index(VarRef('users'), Number(2)), 'id')
              .evaluate(env: env),
          102);
    });
  });

  group('control flow evaluation', () {
    test('if statement - true condition', () {
      final env = LuaEnv(variables: {'x': true, 'result': 0});
      final result = If(
        VarRef('x'),
        Block([Assign.single('result', Number(42))]),
      ).evaluate(env: env);
      expect(result, 42);
    });

    test('if statement - false condition', () {
      final env = LuaEnv(variables: {'x': false, 'result': 0});
      final result = If(
        VarRef('x'),
        Block([Assign.single('result', Number(42))]),
      ).evaluate(env: env);
      expect(result, null);
    });

    test('if-else statement', () {
      final env = LuaEnv(variables: {'condition': false});
      final result = If(
        VarRef('condition'),
        Block([
          Return(values: [Number(1)])
        ]),
        elseBlock: Block([
          Return(values: [Number(2)])
        ]),
      ).evaluate(env: env);
      expect(result, 2);
    });

    test('if-elseif-else statement', () {
      final env = LuaEnv(variables: {'x': false, 'y': true});
      final result = If(
        VarRef('x'),
        Block([
          Return(values: [Number(1)])
        ]),
        elseIfs: [
          ElseIf(
              VarRef('y'),
              Block([
                Return(values: [Number(2)])
              ]))
        ],
        elseBlock: Block([
          Return(values: [Number(3)])
        ]),
      ).evaluate(env: env);
      expect(result, 2);
    });

    test('for loop basic', () {
      final block = Block([
        Assign.single('sum', Number(0), isLocal: true),
        For(
          name: 'i',
          init: Number(1),
          stop: Number(5),
          block: Block([
            Assign.single('sum', Add([VarRef('sum'), VarRef('i')])),
          ]),
        ),
        VarRef('sum'),
      ]);
      expect(block.evaluate(), 15); // 1+2+3+4+5
    });

    test('for loop with increment', () {
      final block = Block([
        Assign.single('sum', Number(0), isLocal: true),
        For(
          name: 'i',
          init: Number(0),
          stop: Number(10),
          increment: Number(2),
          block: Block([
            Assign.single('sum', Add([VarRef('sum'), VarRef('i')])),
          ]),
        ),
        VarRef('sum'),
      ]);
      expect(block.evaluate(), 30); // 0+2+4+6+8+10
    });

    test('for loop with negative increment', () {
      final block = Block([
        Assign.single('sum', Number(0), isLocal: true),
        For(
          name: 'i',
          init: Number(5),
          stop: Number(1),
          increment: Number(-1),
          block: Block([
            Assign.single('sum', Add([VarRef('sum'), VarRef('i')])),
          ]),
        ),
        VarRef('sum'),
      ]);
      expect(block.evaluate(), 15); // 5+4+3+2+1
    });

    test('for loop with break', () {
      final block = Block([
        Assign.single('sum', Number(0), isLocal: true),
        For(
          name: 'i',
          init: Number(1),
          stop: Number(10),
          block: Block([
            If(
              Greater(VarRef('i'), Number(3)),
              Block([Break()]),
            ),
            Assign.single('sum', Add([VarRef('sum'), VarRef('i')])),
          ]),
        ),
        VarRef('sum'),
      ]);
      expect(block.evaluate(), 6); // 1+2+3, stops at 4
    });

    test('function definition and call', () {
      final block = Block([
        FunctionDef(
          'add',
          ['a', 'b'],
          Block([
            Return(values: [
              Add([VarRef('a'), VarRef('b')])
            ])
          ]),
        ),
        Call('add', [Number(5), Number(3)]),
      ]);
      expect(block.evaluate(), 8);
    });

    test('local function definition', () {
      final block = Block([
        FunctionDef(
          'multiply',
          ['x', 'y'],
          Block([
            Return(values: [
              Multiply([VarRef('x'), VarRef('y')])
            ])
          ]),
          isLocal: true,
        ),
        Call('multiply', [Number(4), Number(6)]),
      ]);
      expect(block.evaluate(), 24);
    });

    test('function with no parameters', () {
      final block = Block([
        FunctionDef(
          'getConstant',
          [],
          Block([
            Return(values: [Number(42)])
          ]),
        ),
        Call('getConstant', []),
      ]);
      expect(block.evaluate(), 42);
    });

    test('function with more arguments than parameters', () {
      final block = Block([
        FunctionDef(
          'first',
          ['a'],
          Block([
            Return(values: [VarRef('a')])
          ]),
        ),
        Call('first', [Number(1), Number(2), Number(3)]),
      ]);
      expect(block.evaluate(), 1); // Extra arguments ignored
    });

    test('function with fewer arguments than parameters', () {
      final block = Block([
        FunctionDef(
          'defaultParam',
          ['a', 'b'],
          Block([
            If(
              Equals(VarRef('b'), Nil()),
              Block([
                Return(values: [VarRef('a')])
              ]),
              elseBlock: Block([
                Return(values: [
                  Add([VarRef('a'), VarRef('b')])
                ])
              ]),
            ),
          ]),
        ),
        Call('defaultParam', [Number(5)]), // b will be nil
      ]);
      expect(block.evaluate(), 5);
    });

    test('recursive function', () {
      final block = Block([
        FunctionDef(
          'factorial',
          ['n'],
          Block([
            If(
              Less(VarRef('n'), Number(2)),
              Block([
                Return(values: [Number(1)])
              ]),
              elseBlock: Block([
                Return(values: [
                  Multiply([
                    VarRef('n'),
                    Call('factorial', [Subtract(VarRef('n'), Number(1))])
                  ])
                ])
              ]),
            ),
          ]),
        ),
        Call('factorial', [Number(5)]),
      ]);
      expect(block.evaluate(), 120); // 5! = 120
    });

    test('function closure captures variables', () {
      final block = Block([
        Assign.single('counter', Number(0), isLocal: true),
        FunctionDef(
          'increment',
          [],
          Block([
            Assign.single('counter', Add([VarRef('counter'), Number(1)])),
            Return(values: [VarRef('counter')]),
          ]),
          isLocal: true,
        ),
        Call('increment', []),
        Call('increment', []),
        Assign.single('result', Call('increment', []), isLocal: true),
        VarRef('result'),
      ]);
      expect(block.evaluate(), 3);
    });

    test('nested control structures', () {
      final block = Block([
        Assign.single('total', Number(0), isLocal: true),
        For(
          name: 'i',
          init: Number(1),
          stop: Number(3),
          block: Block([
            For(
              name: 'j',
              init: Number(1),
              stop: Number(2),
              block: Block([
                If(
                  Equals(VarRef('i'), Number(2)),
                  Block([
                    Assign.single('total', Add([VarRef('total'), Number(10)])),
                  ]),
                  elseBlock: Block([
                    Assign.single('total', Add([VarRef('total'), Number(1)])),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
        VarRef('total'),
      ]);
      expect(block.evaluate(), 24); // (1+1) + (10+10) + (1+1) = 24
    });
  });
}
