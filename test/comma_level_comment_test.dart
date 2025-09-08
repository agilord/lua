import 'package:lua/lua.dart';
import 'package:test/test.dart';

void main() {
  group('comma-level comment parsing tests', () {
    test('parse field with comma comment', () {
      final code = 'return { a = 1, -- comma comment }';
      final ast = parse(code);

      expect(ast.statements.length, 1);
      expect(ast.statements.first, isA<Return>());

      final returnStmt = ast.statements.first as Return;
      final table = returnStmt.values?.first as Table;
      expect(table.fields.length, 1);

      final field = table.fields[0];
      expect(field.name, 'a');
      expect((field.value as Number).value, 1);
      expect(field.comment, 'comma comment');
    });

    test('parse multiple fields with comma comments', () {
      final code =
          'return { a = 1, -- first comment\n  b = 2, -- second comment\n  c = 3 }';
      final ast = parse(code);

      final returnStmt = ast.statements.first as Return;
      final table = returnStmt.values?.first as Table;
      expect(table.fields.length, 3);

      expect(table.fields[0].name, 'a');
      expect(table.fields[0].comment, 'first comment');

      expect(table.fields[1].name, 'b');
      expect(table.fields[1].comment, 'second comment');

      expect(table.fields[2].name, 'c');
      expect(table.fields[2].comment, isNull);
    });

    test('parse mixed field types with comma comments', () {
      final code =
          'return { 1, -- array comment\n  name = "test", -- named comment\n  [100] = true -- indexed comment }';
      final ast = parse(code);

      final returnStmt = ast.statements.first as Return;
      final table = returnStmt.values?.first as Table;
      expect(table.fields.length, 3);

      // Array field with comma comment
      expect(table.fields[0].name, isNull);
      expect(table.fields[0].index, isNull);
      expect((table.fields[0].value as Number).value, 1);
      expect(table.fields[0].comment, 'array comment');

      // Named field with comma comment
      expect(table.fields[1].name, 'name');
      expect((table.fields[1].value as LuaString).value, 'test');
      expect(table.fields[1].comment, 'named comment');

      // Indexed field with field comment (no comma)
      expect((table.fields[2].index as Number).value, 100);
      expect((table.fields[2].value as Bool).value, true);
      expect(table.fields[2].comment, 'indexed comment');
    });

    test('parse field with both field and comma comments', () {
      final code = 'return { a = 1 --field comment, -- comma comment }';
      final ast = parse(code);

      final returnStmt = ast.statements.first as Return;
      final table = returnStmt.values?.first as Table;
      final field = table.fields[0];

      expect(field.name, 'a');
      expect(field.comment, 'field comment, comma comment');
    });

    test('parse user example: local defpos = { target = 0, -- x }', () {
      final code = 'local defpos = { target = 0, -- x }';
      final ast = parse(code);

      expect(ast.statements.length, 1);
      expect(ast.statements.first, isA<Assign>());

      final assignStmt = ast.statements.first as Assign;
      final table = assignStmt.values.first as Table;
      expect(table.fields.length, 1);

      final field = table.fields[0];
      expect(field.name, 'target');
      expect((field.value as Number).value, 0);
      expect(field.comment, 'x');
    });

    test('parse complex mixed comment scenario', () {
      final code =
          'return { x = 10 --coordinate, -- x axis\n  y = 20, -- y axis\n  z = 30 --depth }';
      final ast = parse(code);

      final returnStmt = ast.statements.first as Return;
      final table = returnStmt.values?.first as Table;
      expect(table.fields.length, 3);

      expect(table.fields[0].name, 'x');
      expect(table.fields[0].comment, 'coordinate, x axis');

      expect(table.fields[1].name, 'y');
      expect(table.fields[1].comment, 'y axis');

      expect(table.fields[2].name, 'z');
      expect(table.fields[2].comment, 'depth');
    });

    test('parse nested tables with comma comments', () {
      final code =
          'return { config = { debug = true, -- debug flag\n    port = 8080 -- server port\n  } -- configuration object }';
      final ast = parse(code);

      final returnStmt = ast.statements.first as Return;
      final table = returnStmt.values?.first as Table;
      final configField = table.fields[0];

      expect(configField.name, 'config');
      expect(configField.comment, 'configuration object');

      final nestedTable = configField.value as Table;
      expect(nestedTable.fields.length, 2);
      expect(nestedTable.fields[0].comment, 'debug flag');
      expect(nestedTable.fields[1].comment, 'server port');
    });
  });

  group('comma-level comment evaluation tests', () {
    test('evaluate table with comma comments', () {
      final code =
          'return { a = 10, -- first value\n  b = 20 -- second value }';
      final ast = parse(code);
      final result = ast.evaluate();

      expect(result, TableInstance.fromMap({'a': 10, 'b': 20}));
    });

    test('evaluate nested tables with comma comments', () {
      final code =
          'return { config = { x = 1, -- x coordinate\n    y = 2 -- y coordinate\n  } -- position data }';
      final ast = parse(code);
      final result = ast.evaluate();

      expect(
          result,
          TableInstance.fromMap({
            'config': TableInstance.fromMap({'x': 1, 'y': 2})
          }));
    });
  });

  group('comma-level comment formatting tests', () {
    test('format field with combined field and comma comments', () {
      final field = Field(
          name: 'test',
          value: Number(42),
          comment: 'field comment, comma comment');
      final table = Table([field]);
      final formatted = format(table);

      expect(formatted, '{test=42 --field comment, comma comment}');
    });

    test('format multiple fields with comma comments', () {
      final fields = [
        Field(name: 'a', value: Number(1), comment: 'first comment'),
        Field(name: 'b', value: Number(2), comment: 'second comment'),
      ];
      final table = Table(fields);
      final formatted = format(table);

      expect(formatted, '{a=1 --first comment, b=2 --second comment}');
    });
  });

  group('comma-level comment with table trailing comments', () {
    test('parse comma comments with table trailing comment', () {
      final code =
          'return { a = 1, -- field comment\n  b = 2 -- another comment\n}--table comment';
      final ast = parse(code);

      expect(ast.statements.length, 2);
      expect(ast.statements[0], isA<Return>());
      expect(ast.statements[1], isA<SingleLineComment>());

      final returnStmt = ast.statements[0] as Return;
      final table = returnStmt.values?.first as Table;

      expect(table.fields[0].comment, 'field comment');
      expect(table.fields[1].comment, 'another comment');

      final tableComment = ast.statements[1] as SingleLineComment;
      expect(tableComment.text, 'table comment');
    });

    test('evaluate comma comments with table trailing comment', () {
      final code =
          'return { name = "test", -- field info\n  value = 42 -- field value\n}--config object';
      final ast = parse(code);
      final result = ast.evaluate();

      expect(result, TableInstance.fromMap({'name': 'test', 'value': 42}));
    });
  });
}
