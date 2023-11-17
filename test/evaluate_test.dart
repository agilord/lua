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
}
