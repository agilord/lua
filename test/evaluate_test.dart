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
}
