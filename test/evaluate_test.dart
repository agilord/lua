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

    test('integer operators', () {
      expect(2.lua().negative().evaluate(), -2);
      expect(Length(Table([Field(value: 1.lua())])).evaluate(), 1);
    });
  });
}
