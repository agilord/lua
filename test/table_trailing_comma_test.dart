import 'package:lua/lua.dart';
import 'package:test/test.dart';

void main() {
  group('table trailing comma basic tests', () {
    test('parse table with trailing comma after single element', () {
      final code = 'local t = {1,}';
      final ast = parse(code);

      expect(ast.statements.length, 1);
      expect(ast.statements.first, isA<Assign>());

      final assignment = ast.statements.first as Assign;
      final table = assignment.values.first as Table;
      expect(table.fields.length, 1);
      expect((table.fields.first.value as Number).value, 1);
    });

    test('parse table with trailing comma after multiple elements', () {
      final code = 'local t = {1, 2, 3,}';
      final ast = parse(code);

      final assignment = ast.statements.first as Assign;
      final table = assignment.values.first as Table;
      expect(table.fields.length, 3);
      expect((table.fields[0].value as Number).value, 1);
      expect((table.fields[1].value as Number).value, 2);
      expect((table.fields[2].value as Number).value, 3);
    });

    test('parse table with trailing comma after named fields', () {
      final code = 'local t = {a = 1, b = 2,}';
      final ast = parse(code);

      final assignment = ast.statements.first as Assign;
      final table = assignment.values.first as Table;
      expect(table.fields.length, 2);
      expect(table.fields[0].name, 'a');
      expect((table.fields[0].value as Number).value, 1);
      expect(table.fields[1].name, 'b');
      expect((table.fields[1].value as Number).value, 2);
    });

    test('parse table with trailing comma after mixed fields', () {
      final code = 'local t = {1, a = 2, [3] = "three",}';
      final ast = parse(code);

      final assignment = ast.statements.first as Assign;
      final table = assignment.values.first as Table;
      expect(table.fields.length, 3);

      // First field: unnamed (positional)
      expect(table.fields[0].name, isNull);
      expect(table.fields[0].index, isNull);
      expect((table.fields[0].value as Number).value, 1);

      // Second field: named
      expect(table.fields[1].name, 'a');
      expect((table.fields[1].value as Number).value, 2);

      // Third field: indexed
      expect(table.fields[2].index, isA<Number>());
      expect((table.fields[2].index as Number).value, 3);
      expect((table.fields[2].value as LuaString).value, 'three');
    });

    test('parse empty table still works', () {
      final code = 'local t = {}';
      final ast = parse(code);

      final assignment = ast.statements.first as Assign;
      final table = assignment.values.first as Table;
      expect(table.fields.length, 0);
    });

    test('parse table without trailing comma still works', () {
      final code = 'local t = {1, 2, a = 3}';
      final ast = parse(code);

      final assignment = ast.statements.first as Assign;
      final table = assignment.values.first as Table;
      expect(table.fields.length, 3);
      expect((table.fields[0].value as Number).value, 1);
      expect((table.fields[1].value as Number).value, 2);
      expect(table.fields[2].name, 'a');
      expect((table.fields[2].value as Number).value, 3);
    });
  });

  group('table trailing comma evaluation tests', () {
    test('evaluate table with trailing comma using return', () {
      final code = 'return {1, 2, 3,}';
      final ast = parse(code);
      final result = ast.evaluate();

      expect(result, TableInstance.fromMap({1: 1, 2: 2, 3: 3}));
    });

    test('evaluate named fields with trailing comma using return', () {
      final code = 'return {name = "test", value = 42,}';
      final ast = parse(code);
      final result = ast.evaluate();

      expect(result, TableInstance.fromMap({'name': 'test', 'value': 42}));
    });

    test('evaluate mixed fields with trailing comma using return', () {
      final code = 'return {"first", second = "value", [100] = "indexed",}';
      final ast = parse(code);
      final result = ast.evaluate();

      expect(
          result,
          TableInstance.fromMap({
            1: 'first', // positional field
            'second': 'value', // named field
            100: 'indexed' // indexed field
          }));
    });
  });
}
