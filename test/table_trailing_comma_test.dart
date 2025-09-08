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
          100: 'indexed', // indexed field
        }),
      );
    });
  });

  group('table comment parsing tests', () {
    test('parse table followed by inline comment', () {
      final code = 'return { 1, 2 }--comment';
      final ast = parse(code);

      expect(ast.statements.length, 2);
      expect(ast.statements[0], isA<Return>());
      expect(ast.statements[1], isA<SingleLineComment>());

      final returnStmt = ast.statements[0] as Return;
      final table = returnStmt.values?.first as Table;
      expect(table.fields.length, 2);

      final comment = ast.statements[1] as SingleLineComment;
      expect(comment.text, 'comment');
    });

    test('parse multi-line table with trailing comment', () {
      final code = 'return {\n  a = 1,\n  b = 2\n}--multiline';
      final ast = parse(code);

      expect(ast.statements.length, 2);
      expect(ast.statements[0], isA<Return>());
      expect(ast.statements[1], isA<SingleLineComment>());

      final returnStmt = ast.statements[0] as Return;
      final table = returnStmt.values?.first as Table;
      expect(table.fields.length, 2);
      expect(table.fields[0].name, 'a');
      expect(table.fields[1].name, 'b');

      final comment = ast.statements[1] as SingleLineComment;
      expect(comment.text, 'multiline');
    });

    test('evaluate table with trailing comment', () {
      final code = 'return { a = 1, b = 2 }--table';
      final ast = parse(code);
      final result = ast.evaluate();

      expect(result, TableInstance.fromMap({'a': 1, 'b': 2}));
    });

    test('evaluate multi-line table with comment', () {
      final code = 'return {\n  x = 10,\n  y = 20,\n}--coords';
      final ast = parse(code);
      final result = ast.evaluate();

      expect(result, TableInstance.fromMap({'x': 10, 'y': 20}));
    });

    test(
      'parse complex multi-line table with nested table and trailing comment',
      () {
        final code =
            'return {\n  name = "config",\n  values = { 1, 2, 3 },\n  enabled = true\n}--settings';
        final ast = parse(code);

        expect(ast.statements.length, 2);
        expect(ast.statements[0], isA<Return>());
        expect(ast.statements[1], isA<SingleLineComment>());

        final returnStmt = ast.statements[0] as Return;
        final table = returnStmt.values?.first as Table;
        expect(table.fields.length, 3);
        expect(table.fields[0].name, 'name');
        expect(table.fields[1].name, 'values');
        expect(table.fields[1].value, isA<Table>()); // Nested table
        expect(table.fields[2].name, 'enabled');

        final comment = ast.statements[1] as SingleLineComment;
        expect(comment.text, 'settings');
      },
    );

    test('evaluate complex multi-line table with nested table and comment', () {
      final code =
          'return {\n  title = "test",\n  items = { "a", "b", "c" },\n  active = true,\n}--metadata';
      final ast = parse(code);
      final result = ast.evaluate();

      expect(
        result,
        TableInstance.fromMap({
          'title': 'test',
          'items': TableInstance.fromMap({1: 'a', 2: 'b', 3: 'c'}),
          'active': true,
        }),
      );
    });
  });

  group('complex multi-line table scenarios', () {
    test('parse multi-line table with trailing comma and comment', () {
      final code =
          'return {\n  "first",\n  "second",\n  "third",\n}--array comment';
      final ast = parse(code);

      expect(ast.statements.length, 2);
      expect(ast.statements[0], isA<Return>());
      expect(ast.statements[1], isA<SingleLineComment>());

      final returnStmt = ast.statements[0] as Return;
      final table = returnStmt.values?.first as Table;
      expect(table.fields.length, 3);

      final comment = ast.statements[1] as SingleLineComment;
      expect(comment.text, 'array comment');
    });

    test('evaluate multi-line table with trailing comma and comment', () {
      final code =
          'return {\n  id = 1,\n  name = "config",\n  active = true,\n}--metadata object';
      final ast = parse(code);
      final result = ast.evaluate();

      expect(
        result,
        TableInstance.fromMap({'id': 1, 'name': 'config', 'active': true}),
      );
    });

    test('parse table with numeric values and trailing comment', () {
      final code =
          'return {\n  id = 100,\n  count = 42,\n  status = 1\n}--numeric table';
      final ast = parse(code);

      expect(ast.statements.length, 2);
      expect(ast.statements[0], isA<Return>());
      expect(ast.statements[1], isA<SingleLineComment>());

      final returnStmt = ast.statements[0] as Return;
      final table = returnStmt.values?.first as Table;
      expect(table.fields.length, 3);
      expect(table.fields[0].name, 'id');
      expect(table.fields[1].name, 'count');
      expect(table.fields[2].name, 'status');

      final comment = ast.statements[1] as SingleLineComment;
      expect(comment.text, 'numeric table');
    });

    test('evaluate table with numeric values and trailing comment', () {
      final code =
          'return {\n  width = 1920,\n  height = 1080,\n  depth = 32\n}--dimensions';
      final ast = parse(code);
      final result = ast.evaluate();

      expect(
        result,
        TableInstance.fromMap({'width': 1920, 'height': 1080, 'depth': 32}),
      );
    });

    test('parse table with mixed numeric field types and trailing comment', () {
      final code =
          'return {\n  1,\n  2,\n  count = 42,\n  [10] = 999,\n  3,\n}--mixed numeric table';
      final ast = parse(code);

      expect(ast.statements.length, 2);
      expect(ast.statements[0], isA<Return>());
      expect(ast.statements[1], isA<SingleLineComment>());

      final returnStmt = ast.statements[0] as Return;
      final table = returnStmt.values?.first as Table;
      expect(table.fields.length, 5);

      final comment = ast.statements[1] as SingleLineComment;
      expect(comment.text, 'mixed numeric table');
    });

    test('evaluate mixed numeric field types table with trailing comment', () {
      final code =
          'return {\n  100,\n  200, \n  total = 500,\n  [5] = 750,\n}--numeric data table';
      final ast = parse(code);
      final result = ast.evaluate();

      expect(
        result,
        TableInstance.fromMap({1: 100, 2: 200, 'total': 500, 5: 750}),
      );
    });

    // Documents current implementation capabilities and limitations
    test('documentation - table comment support capabilities', () {
      // WORKS: Single-line table with trailing comment
      final code1 = 'return { a = 1, b = 2 }--inline';
      final ast1 = parse(code1);
      expect(ast1.statements.length, 2);
      expect(ast1.statements[1], isA<SingleLineComment>());

      // WORKS: Multi-line table with trailing comment
      final code2 = 'return {\n  x = 10,\n  y = 20,\n  z = 30\n}--coordinates';
      final ast2 = parse(code2);
      expect(ast2.statements.length, 2);
      expect(ast2.statements[1], isA<SingleLineComment>());

      // WORKS: Multi-line table with trailing comma and comment
      final code3 =
          'return {\n  first = "value1",\n  second = "value2",\n}--config object';
      final ast3 = parse(code3);
      expect(ast3.statements.length, 2);
      expect(ast3.statements[1], isA<SingleLineComment>());

      // NOW SUPPORTED: Nested tables work correctly
      final code4 = 'return { inner = { x = 1 } }--nested';
      final ast4 = parse(code4);
      expect(ast4.statements.length, 2);
      expect(ast4.statements[1], isA<SingleLineComment>());

      // NOW SUPPORTED: String values in tables work correctly
      final code5 = 'return { name = "value" }--strings';
      final ast5 = parse(code5);
      expect(ast5.statements.length, 2);
      expect(ast5.statements[1], isA<SingleLineComment>());

      // LIMITATION: Field-level inline comments are not yet supported
      // This would need grammar extensions: 'return { a = 1, -- comment\n  b = 2 }'
    });
  });
}
