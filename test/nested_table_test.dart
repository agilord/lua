import 'package:lua/lua.dart';
import 'package:test/test.dart';

void main() {
  group('nested table parsing tests', () {
    test('parse simple nested table', () {
      final code = 'return { inner = {} }';
      final ast = parse(code);

      expect(ast.statements.length, 1);
      expect(ast.statements.first, isA<Return>());

      final returnStmt = ast.statements.first as Return;
      final table = returnStmt.values?.first as Table;
      expect(table.fields.length, 1);
      expect(table.fields[0].name, 'inner');
      expect(table.fields[0].value, isA<Table>());

      final nestedTable = table.fields[0].value as Table;
      expect(nestedTable.fields.length, 0);
    });

    test('parse nested table with values', () {
      final code = 'return { inner = { x = 1, y = 2 } }';
      final ast = parse(code);

      final returnStmt = ast.statements.first as Return;
      final table = returnStmt.values?.first as Table;
      final nestedTable = table.fields[0].value as Table;

      expect(nestedTable.fields.length, 2);
      expect(nestedTable.fields[0].name, 'x');
      expect((nestedTable.fields[0].value as Number).value, 1);
      expect(nestedTable.fields[1].name, 'y');
      expect((nestedTable.fields[1].value as Number).value, 2);
    });

    test('parse multiple nested tables', () {
      final code = 'return { a = { x = 1 }, b = { y = 2 } }';
      final ast = parse(code);

      final returnStmt = ast.statements.first as Return;
      final table = returnStmt.values?.first as Table;

      expect(table.fields.length, 2);
      expect(table.fields[0].name, 'a');
      expect(table.fields[1].name, 'b');

      final tableA = table.fields[0].value as Table;
      final tableB = table.fields[1].value as Table;

      expect((tableA.fields[0].value as Number).value, 1);
      expect((tableB.fields[0].value as Number).value, 2);
    });

    test('parse deeply nested tables', () {
      final code =
          'return { level1 = { level2 = { level3 = { value = 42 } } } }';
      final ast = parse(code);

      final returnStmt = ast.statements.first as Return;
      final table = returnStmt.values?.first as Table;
      final level1 = table.fields[0].value as Table;
      final level2 = level1.fields[0].value as Table;
      final level3 = level2.fields[0].value as Table;

      expect(table.fields[0].name, 'level1');
      expect(level1.fields[0].name, 'level2');
      expect(level2.fields[0].name, 'level3');
      expect(level3.fields[0].name, 'value');
      expect((level3.fields[0].value as Number).value, 42);
    });

    test('parse mixed field types with nested tables', () {
      final code = 'return { 1, 2, inner = { a = 3 }, 4 }';
      final ast = parse(code);

      final returnStmt = ast.statements.first as Return;
      final table = returnStmt.values?.first as Table;

      expect(table.fields.length, 4);
      expect((table.fields[0].value as Number).value, 1);
      expect((table.fields[1].value as Number).value, 2);
      expect(table.fields[2].name, 'inner');
      expect((table.fields[3].value as Number).value, 4);

      final nestedTable = table.fields[2].value as Table;
      expect(nestedTable.fields[0].name, 'a');
      expect((nestedTable.fields[0].value as Number).value, 3);
    });

    test('parse nested table arrays', () {
      final code = 'return { items = { 1, 2, 3 } }';
      final ast = parse(code);

      final returnStmt = ast.statements.first as Return;
      final table = returnStmt.values?.first as Table;
      final nestedTable = table.fields[0].value as Table;

      expect(nestedTable.fields.length, 3);
      expect((nestedTable.fields[0].value as Number).value, 1);
      expect((nestedTable.fields[1].value as Number).value, 2);
      expect((nestedTable.fields[2].value as Number).value, 3);
    });

    test('parse nested tables with string values', () {
      final code = 'return { config = { name = "test", type = "object" } }';
      final ast = parse(code);

      final returnStmt = ast.statements.first as Return;
      final table = returnStmt.values?.first as Table;
      final nestedTable = table.fields[0].value as Table;

      expect(nestedTable.fields.length, 2);
      expect(nestedTable.fields[0].name, 'name');
      expect((nestedTable.fields[0].value as LuaString).value, 'test');
      expect(nestedTable.fields[1].name, 'type');
      expect((nestedTable.fields[1].value as LuaString).value, 'object');
    });

    test('parse complex nested structure', () {
      final code =
          'return { users = { { id = 1, name = "Alice" }, { id = 2, name = "Bob" } } }';
      final ast = parse(code);

      final returnStmt = ast.statements.first as Return;
      final table = returnStmt.values?.first as Table;
      final usersArray = table.fields[0].value as Table;

      expect(usersArray.fields.length, 2);

      final user1 = usersArray.fields[0].value as Table;
      final user2 = usersArray.fields[1].value as Table;

      expect((user1.fields[0].value as Number).value, 1);
      expect((user1.fields[1].value as LuaString).value, 'Alice');
      expect((user2.fields[0].value as Number).value, 2);
      expect((user2.fields[1].value as LuaString).value, 'Bob');
    });
  });

  group('nested table evaluation tests', () {
    test('evaluate simple nested table', () {
      final code = 'return { inner = {} }';
      final ast = parse(code);
      final result = ast.evaluate();

      expect(
        result,
        TableInstance.fromMap({'inner': TableInstance.fromMap({})}),
      );
    });

    test('evaluate nested table with values', () {
      final code = 'return { config = { x = 10, y = 20 } }';
      final ast = parse(code);
      final result = ast.evaluate();

      expect(
        result,
        TableInstance.fromMap({
          'config': TableInstance.fromMap({'x': 10, 'y': 20}),
        }),
      );
    });

    test('evaluate multiple nested tables', () {
      final code =
          'return { math = { pi = 3.14 }, physics = { c = 299792458 } }';
      final ast = parse(code);
      final result = ast.evaluate();

      expect(
        result,
        TableInstance.fromMap({
          'math': TableInstance.fromMap({'pi': 3.14}),
          'physics': TableInstance.fromMap({'c': 299792458}),
        }),
      );
    });

    test('evaluate deeply nested tables', () {
      final code =
          'return { app = { config = { database = { host = "localhost" } } } }';
      final ast = parse(code);
      final result = ast.evaluate();

      expect(
        result,
        TableInstance.fromMap({
          'app': TableInstance.fromMap({
            'config': TableInstance.fromMap({
              'database': TableInstance.fromMap({'host': 'localhost'}),
            }),
          }),
        }),
      );
    });

    test('evaluate mixed field types with nested tables', () {
      final code = 'return { 100, 200, settings = { debug = true }, 300 }';
      final ast = parse(code);
      final result = ast.evaluate();

      expect(
        result,
        TableInstance.fromMap({
          1: 100,
          2: 200,
          'settings': TableInstance.fromMap({'debug': true}),
          4: 300,
        }),
      );
    });

    test('evaluate nested array tables', () {
      final code =
          'return { numbers = { 1, 2, 3 }, letters = { "a", "b", "c" } }';
      final ast = parse(code);
      final result = ast.evaluate();

      expect(
        result,
        TableInstance.fromMap({
          'numbers': TableInstance.fromMap({1: 1, 2: 2, 3: 3}),
          'letters': TableInstance.fromMap({1: 'a', 2: 'b', 3: 'c'}),
        }),
      );
    });
  });

  group('nested table comment tests', () {
    test('parse nested table with trailing comment', () {
      final code = 'return { config = { debug = true } }--settings';
      final ast = parse(code);

      expect(ast.statements.length, 2);
      expect(ast.statements[0], isA<Return>());
      expect(ast.statements[1], isA<SingleLineComment>());

      final comment = ast.statements[1] as SingleLineComment;
      expect(comment.text, 'settings');
    });

    test('parse multi-line nested table with comment', () {
      final code = '''return {
  database = {
    host = "localhost",
    port = 5432
  }
}--config''';
      final ast = parse(code);

      expect(ast.statements.length, 2);
      final returnStmt = ast.statements[0] as Return;
      final table = returnStmt.values?.first as Table;
      final nestedTable = table.fields[0].value as Table;

      expect(nestedTable.fields.length, 2);
      expect(nestedTable.fields[0].name, 'host');
      expect(nestedTable.fields[1].name, 'port');

      final comment = ast.statements[1] as SingleLineComment;
      expect(comment.text, 'config');
    });

    test('evaluate nested table with comment', () {
      final code =
          'return { server = { port = 8080, ssl = false } }--web config';
      final ast = parse(code);
      final result = ast.evaluate();

      expect(
        result,
        TableInstance.fromMap({
          'server': TableInstance.fromMap({'port': 8080, 'ssl': false}),
        }),
      );
    });

    test('parse complex nested structure with comment', () {
      final code =
          'return { users = { { name = "Alice" }, { name = "Bob" } } }--user data';
      final ast = parse(code);

      expect(ast.statements.length, 2);
      final comment = ast.statements[1] as SingleLineComment;
      expect(comment.text, 'user data');

      // Verify the nested structure parses correctly
      final returnStmt = ast.statements[0] as Return;
      final table = returnStmt.values?.first as Table;
      final usersArray = table.fields[0].value as Table;
      expect(usersArray.fields.length, 2);
    });
  });
}
