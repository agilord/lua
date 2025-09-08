import 'package:lua/lua.dart';
import 'package:test/test.dart';

void main() {
  group('field-level comment parsing tests', () {
    test('parse named field with comment', () {
      final code = 'return { a = 1 --comment }';
      final ast = parse(code);

      expect(ast.statements.length, 1);
      expect(ast.statements.first, isA<Return>());

      final returnStmt = ast.statements.first as Return;
      final table = returnStmt.values?.first as Table;
      expect(table.fields.length, 1);

      final field = table.fields[0];
      expect(field.name, 'a');
      expect((field.value as Number).value, 1);
      expect(field.comment, 'comment');
    });

    test('parse named field with spaced comment', () {
      final code = 'return { a = 1 -- spaced comment }';
      final ast = parse(code);

      final returnStmt = ast.statements.first as Return;
      final table = returnStmt.values?.first as Table;
      final field = table.fields[0];

      expect(field.comment, 'spaced comment');
    });

    test('parse array field with comment', () {
      final code = 'return { 42 --array comment }';
      final ast = parse(code);

      final returnStmt = ast.statements.first as Return;
      final table = returnStmt.values?.first as Table;
      final field = table.fields[0];

      expect(field.name, isNull);
      expect(field.index, isNull);
      expect((field.value as Number).value, 42);
      expect(field.comment, 'array comment');
    });

    test('parse indexed field with comment', () {
      final code = 'return { [10] = "value" --indexed comment }';
      final ast = parse(code);

      final returnStmt = ast.statements.first as Return;
      final table = returnStmt.values?.first as Table;
      final field = table.fields[0];

      expect(field.name, isNull);
      expect(field.index, isA<Number>());
      expect((field.index as Number).value, 10);
      expect((field.value as LuaString).value, 'value');
      expect(field.comment, 'indexed comment');
    });

    test('parse multiple fields with comments', () {
      final code = 'return { a = 1 --first, b = 2 --second, c = 3 --third }';
      final ast = parse(code);

      final returnStmt = ast.statements.first as Return;
      final table = returnStmt.values?.first as Table;
      expect(table.fields.length, 3);

      expect(table.fields[0].name, 'a');
      expect(table.fields[0].comment, 'first');

      expect(table.fields[1].name, 'b');
      expect(table.fields[1].comment, 'second');

      expect(table.fields[2].name, 'c');
      expect(table.fields[2].comment, 'third');
    });

    test('parse mixed field types with comments', () {
      final code =
          'return { 1 --positional, name = "test" --named, [100] = true --indexed }';
      final ast = parse(code);

      final returnStmt = ast.statements.first as Return;
      final table = returnStmt.values?.first as Table;
      expect(table.fields.length, 3);

      // Positional field
      expect(table.fields[0].name, isNull);
      expect(table.fields[0].index, isNull);
      expect((table.fields[0].value as Number).value, 1);
      expect(table.fields[0].comment, 'positional');

      // Named field
      expect(table.fields[1].name, 'name');
      expect((table.fields[1].value as LuaString).value, 'test');
      expect(table.fields[1].comment, 'named');

      // Indexed field
      expect((table.fields[2].index as Number).value, 100);
      expect((table.fields[2].value as Bool).value, true);
      expect(table.fields[2].comment, 'indexed');
    });

    test('parse field without comment', () {
      final code = 'return { a = 1 }';
      final ast = parse(code);

      final returnStmt = ast.statements.first as Return;
      final table = returnStmt.values?.first as Table;
      final field = table.fields[0];

      expect(field.comment, isNull);
    });

    test('parse mixed fields with and without comments', () {
      final code =
          'return { a = 1 --with comment, b = 2, c = 3 --another comment }';
      final ast = parse(code);

      final returnStmt = ast.statements.first as Return;
      final table = returnStmt.values?.first as Table;
      expect(table.fields.length, 3);

      expect(table.fields[0].comment, 'with comment');
      expect(table.fields[1].comment, isNull);
      expect(table.fields[2].comment, 'another comment');
    });

    test('parse nested tables with field comments', () {
      final code =
          'return { config = { debug = true --flag, port = 8080 --number } --settings }';
      final ast = parse(code);

      final returnStmt = ast.statements.first as Return;
      final table = returnStmt.values?.first as Table;
      final configField = table.fields[0];

      expect(configField.name, 'config');
      expect(configField.comment, 'settings');

      final nestedTable = configField.value as Table;
      expect(nestedTable.fields.length, 2);
      expect(nestedTable.fields[0].comment, 'flag');
      expect(nestedTable.fields[1].comment, 'number');
    });
  });

  group('field-level comment evaluation tests', () {
    test('evaluate table with field comments', () {
      final code = 'return { a = 10 --comment, b = 20 }';
      final ast = parse(code);
      final result = ast.evaluate();

      expect(result, TableInstance.fromMap({'a': 10, 'b': 20}));
    });

    test('evaluate nested tables with field comments', () {
      final code =
          'return { config = { x = 1 --x coord, y = 2 --y coord } --position }';
      final ast = parse(code);
      final result = ast.evaluate();

      expect(
        result,
        TableInstance.fromMap({
          'config': TableInstance.fromMap({'x': 1, 'y': 2}),
        }),
      );
    });

    test('evaluate complex structure with field comments', () {
      final code =
          'return { users = { { id = 1 --user id, name = "Alice" --user name } --user object } --user list }';
      final ast = parse(code);
      final result = ast.evaluate();

      expect(
        result,
        TableInstance.fromMap({
          'users': TableInstance.fromMap({
            1: TableInstance.fromMap({'id': 1, 'name': 'Alice'}),
          }),
        }),
      );
    });
  });

  group('field-level comment formatting tests', () {
    test('format field with comment', () {
      final field = Field(
        name: 'test',
        value: Number(42),
        comment: 'my comment',
      );
      final table = Table([field]);
      final formatted = format(table);

      expect(formatted, '{test=42 --my comment}');
    });

    test('format multiple fields with comments', () {
      final fields = [
        Field(name: 'a', value: Number(1), comment: 'first'),
        Field(name: 'b', value: Number(2), comment: 'second'),
      ];
      final table = Table(fields);
      final formatted = format(table);

      expect(formatted, '{a=1 --first, b=2 --second}');
    });

    test('format mixed fields with and without comments', () {
      final fields = [
        Field(name: 'a', value: Number(1), comment: 'with comment'),
        Field(name: 'b', value: Number(2)), // no comment
        Field(name: 'c', value: Number(3), comment: 'another comment'),
      ];
      final table = Table(fields);
      final formatted = format(table);

      expect(formatted, '{a=1 --with comment, b=2, c=3 --another comment}');
    });

    test('format array field with comment', () {
      final field = Field(value: Number(100), comment: 'array comment');
      final table = Table([field]);
      final formatted = format(table);

      expect(formatted, '{100 --array comment}');
    });

    test('format indexed field with comment', () {
      final field = Field(
        index: Number(5),
        value: LuaString('test'),
        comment: 'indexed comment',
      );
      final table = Table([field]);
      final formatted = format(table);

      expect(formatted, '{[5]="test" --indexed comment}');
    });
  });

  group('field-level comment with table trailing comments', () {
    test('parse field comments combined with table trailing comment', () {
      final code = 'return { a = 1 --field comment, b = 2 }--table comment';
      final ast = parse(code);

      expect(ast.statements.length, 2);
      expect(ast.statements[0], isA<Return>());
      expect(ast.statements[1], isA<SingleLineComment>());

      final returnStmt = ast.statements[0] as Return;
      final table = returnStmt.values?.first as Table;

      expect(table.fields[0].comment, 'field comment');
      expect(table.fields[1].comment, isNull);

      final tableComment = ast.statements[1] as SingleLineComment;
      expect(tableComment.text, 'table comment');
    });

    test('evaluate field comments with table trailing comment', () {
      final code =
          'return { name = "test" --field info, value = 42 }--config object';
      final ast = parse(code);
      final result = ast.evaluate();

      expect(result, TableInstance.fromMap({'name': 'test', 'value': 42}));
    });
  });
}
