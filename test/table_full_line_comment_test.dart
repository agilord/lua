import 'package:lua/lua.dart';
import 'package:test/test.dart';

void main() {
  group('table full line comment parsing tests', () {
    test('parse table with single full line comment', () {
      final code = 'return { -- this is a comment\n  a = 1 }';
      final ast = parse(code);

      expect(ast.statements.length, 1);
      expect(ast.statements.first, isA<Return>());

      final returnStmt = ast.statements.first as Return;
      final table = returnStmt.values?.first as Table;
      expect(table.fields.length, 1);
      expect(table.comment, 'this is a comment');
      expect(table.fields[0].name, 'a');
      expect((table.fields[0].value as Number).value, 1);
    });

    test('parse table with multiple full line comments', () {
      final code = '''return {
  -- first comment
  -- second comment
  a = 1,
  b = 2
}''';
      final ast = parse(code);

      final returnStmt = ast.statements.first as Return;
      final table = returnStmt.values?.first as Table;

      expect(table.fields.length, 2);
      expect(table.comment, 'first comment\nsecond comment');
    });

    test('parse table with leading comments and field comments', () {
      final code = '''return {
  -- configuration section
  debug = true, -- enable debugging
  port = 8080 -- server port
}''';
      final ast = parse(code);

      final returnStmt = ast.statements.first as Return;
      final table = returnStmt.values?.first as Table;

      expect(table.fields.length, 2);
      expect(table.comment, 'configuration section');
      expect(table.fields[0].comment, 'enable debugging');
      expect(table.fields[1].comment, 'server port');
    });

    test('parse empty table with full line comments', () {
      final code = '''return {
  -- empty table with comments
  -- another comment
}''';
      final ast = parse(code);

      final returnStmt = ast.statements.first as Return;
      final table = returnStmt.values?.first as Table;

      expect(table.fields.length, 0);
      expect(table.comment, 'empty table with comments\nanother comment');
    });

    test('parse table with leading comments only', () {
      final code = '''return {
  -- first leading comment
  -- second leading comment
  a = 1,
  b = 2,
  c = 3
}''';
      final ast = parse(code);

      final returnStmt = ast.statements.first as Return;
      final table = returnStmt.values?.first as Table;

      expect(table.fields.length, 3);
      expect(table.comment, 'first leading comment\nsecond leading comment');
      expect(table.fields[0].name, 'a');
      expect(table.fields[1].name, 'b');
      expect(table.fields[2].name, 'c');
    });
  });

  group('table full line comment evaluation tests', () {
    test('evaluate table with full line comments', () {
      final code = '''return {
  -- configuration
  name = "test",
  value = 42
}''';
      final ast = parse(code);
      final result = ast.evaluate();

      expect(result, TableInstance.fromMap({'name': 'test', 'value': 42}));
    });

    test('evaluate empty table with comments', () {
      final code = '''return {
  -- empty but commented
}''';
      final ast = parse(code);
      final result = ast.evaluate();

      expect(result, TableInstance.fromMap({}));
    });
  });

  group('table full line comment formatting tests', () {
    test('format table with full line comments', () {
      final fields = [
        Field(name: 'test', value: Number(42)),
      ];
      final table = Table(fields, comment: 'configuration comment');
      final formatted = format(table);

      expect(formatted, '{\n--configuration comment\ntest=42}');
    });

    test('format table with multiple full line comments', () {
      final fields = [
        Field(name: 'a', value: Number(1)),
        Field(name: 'b', value: Number(2)),
      ];
      final table = Table(fields, comment: 'first comment\nsecond comment');
      final formatted = format(table);

      expect(formatted, '{\n--first comment\n--second comment\na=1, b=2}');
    });

    test('format empty table with comments', () {
      final table = Table([], comment: 'empty table comment');
      final formatted = format(table);

      expect(formatted, '{\n--empty table comment\n}');
    });
  });
}
