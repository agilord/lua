import 'package:lua/lua.dart';
import 'package:test/test.dart';

void main() {
  group('comment parsing tests', () {
    test('parse single line comment', () {
      final code = '-- This is a single line comment';
      final ast = parse(code);
      expect(ast.statements.length, 1);
      expect(ast.statements.first, isA<SingleLineComment>());
      final comment = ast.statements.first as SingleLineComment;
      expect(comment.text, ' This is a single line comment');
    });

    test('parse single line comment with code after', () {
      final code = '-- Comment\nlocal x = 5';
      final ast = parse(code);
      expect(ast.statements.length, 2);
      expect(ast.statements.first, isA<SingleLineComment>());
      expect(ast.statements[1], isA<Assign>());
      final comment = ast.statements.first as SingleLineComment;
      expect(comment.text, ' Comment');
    });

    test('parse single line comment after code', () {
      final code = '-- Comment\nlocal x = 1';
      final ast = parse(code);
      expect(ast.statements.length, 2);
      expect(ast.statements.first, isA<SingleLineComment>());
      expect(ast.statements[1], isA<Assign>());
      final comment = ast.statements.first as SingleLineComment;
      expect(comment.text, ' Comment');
    });

    test('parse empty single line comment', () {
      final code = '--';
      final ast = parse(code);
      expect(ast.statements.length, 1);
      expect(ast.statements.first, isA<SingleLineComment>());
      final comment = ast.statements.first as SingleLineComment;
      expect(comment.text, '');
    });

    test('parse single line comment with special characters', () {
      final code = r'-- This has symbols: !@#$%^&*()_+{}|:"<>?';
      final ast = parse(code);
      expect(ast.statements.length, 1);
      expect(ast.statements.first, isA<SingleLineComment>());
      final comment = ast.statements.first as SingleLineComment;
      expect(comment.text, r' This has symbols: !@#$%^&*()_+{}|:"<>?');
    });

    test('parse multi-line comment', () {
      final code = '--[[This is a\nmulti-line comment]]';
      final ast = parse(code);
      expect(ast.statements.length, 1);
      expect(ast.statements.first, isA<MultiLineComment>());
      final comment = ast.statements.first as MultiLineComment;
      expect(comment.text, 'This is a\nmulti-line comment');
    });

    test('parse multi-line comment with code around', () {
      final code = '--[[Multi\nline]]\nlocal x = 1';
      final ast = parse(code);
      expect(ast.statements.length, 2);
      expect(ast.statements[0], isA<MultiLineComment>());
      expect(ast.statements[1], isA<Assign>());
      final comment = ast.statements[0] as MultiLineComment;
      expect(comment.text, 'Multi\nline');
    });

    test('parse empty multi-line comment', () {
      final code = '--[[]]';
      final ast = parse(code);
      expect(ast.statements.length, 1);
      expect(ast.statements.first, isA<MultiLineComment>());
      final comment = ast.statements.first as MultiLineComment;
      expect(comment.text, '');
    });

    test('parse multi-line comment with nested brackets', () {
      final code = '--[[This has [nested] brackets]]';
      final ast = parse(code);
      expect(ast.statements.length, 1);
      expect(ast.statements.first, isA<MultiLineComment>());
      final comment = ast.statements.first as MultiLineComment;
      expect(comment.text, 'This has [nested] brackets');
    });

    test('parse single line comment does not interfere with multi-line', () {
      final code = '-- Single line\n--[[Multi\nline]]';
      final ast = parse(code);
      expect(ast.statements.length, 2);
      expect(ast.statements[0], isA<SingleLineComment>());
      expect(ast.statements[1], isA<MultiLineComment>());
    });

    test('parse multiple single line comments', () {
      final code = '-- First comment\n-- Second comment\n-- Third comment';
      final ast = parse(code);
      expect(ast.statements.length, 3);
      for (int i = 0; i < 3; i++) {
        expect(ast.statements[i], isA<SingleLineComment>());
      }
      expect((ast.statements[0] as SingleLineComment).text, ' First comment');
      expect((ast.statements[1] as SingleLineComment).text, ' Second comment');
      expect((ast.statements[2] as SingleLineComment).text, ' Third comment');
    });

    test('parse multiple multi-line comments', () {
      final code = '--[[First\ncomment]]\n--[[Second\ncomment]]';
      final ast = parse(code);
      expect(ast.statements.length, 2);
      expect(ast.statements[0], isA<MultiLineComment>());
      expect(ast.statements[1], isA<MultiLineComment>());
      expect((ast.statements[0] as MultiLineComment).text, 'First\ncomment');
      expect((ast.statements[1] as MultiLineComment).text, 'Second\ncomment');
    });

    test('parse comments mixed with code', () {
      final code = '-- Comment before\n-- Comment after';
      final ast = parse(code);
      expect(ast.statements.length, 2);
      expect(ast.statements[0], isA<SingleLineComment>());
      expect(ast.statements[1], isA<SingleLineComment>());
      expect((ast.statements[0] as SingleLineComment).text, ' Comment before');
      expect((ast.statements[1] as SingleLineComment).text, ' Comment after');
    });

    test('parse comment with Lua code inside (should not parse as code)', () {
      final code = '--[[local x = 5\nif x > 0 then print("positive") end]]';
      final ast = parse(code);
      expect(ast.statements.length, 1);
      expect(ast.statements.first, isA<MultiLineComment>());
      final comment = ast.statements.first as MultiLineComment;
      expect(comment.text, 'local x = 5\nif x > 0 then print("positive") end');
    });
  });

  group('comment evaluation tests', () {
    test('single line comment evaluates to null', () {
      final comment = SingleLineComment(' This is a comment');
      final result = comment.evaluate();
      expect(result, isNull);
    });

    test('multi-line comment evaluates to null', () {
      final comment = MultiLineComment('This is a\nmulti-line comment');
      final result = comment.evaluate();
      expect(result, isNull);
    });

    test('comments do not affect program execution', () {
      final code = '-- Initialize variables\nlocal x = 5; return x + 10';
      final ast = parse(code);
      final result = ast.evaluate();
      expect(result, 15);
    });

    test('block with only comments returns null', () {
      final code =
          '-- Only comments\n--[[\nNo actual code here\n]]\n-- More comments';
      final ast = parse(code);
      final result = ast.evaluate();
      expect(result, isNull);
    });
  });

  group('comment edge cases', () {
    test('single line comment without newline at end', () {
      final code = '-- Comment without newline';
      final ast = parse(code);
      expect(ast.statements.length, 1);
      expect(ast.statements.first, isA<SingleLineComment>());
    });

    test('multi-line comment on single line', () {
      final code = '--[[Single line multi-comment]]';
      final ast = parse(code);
      expect(ast.statements.length, 1);
      expect(ast.statements.first, isA<MultiLineComment>());
      final comment = ast.statements.first as MultiLineComment;
      expect(comment.text, 'Single line multi-comment');
    });

    test('comment with tabs and spaces', () {
      final code = '--\t\tThis has tabs and   spaces';
      final ast = parse(code);
      expect(ast.statements.length, 1);
      expect(ast.statements.first, isA<SingleLineComment>());
      final comment = ast.statements.first as SingleLineComment;
      expect(comment.text, '\t\tThis has tabs and   spaces');
    });

    test('multi-line comment with various whitespace', () {
      final code = '--[[\t\nSpaces and\ttabs\n  ]]';
      final ast = parse(code);
      expect(ast.statements.length, 1);
      expect(ast.statements.first, isA<MultiLineComment>());
      final comment = ast.statements.first as MultiLineComment;
      expect(comment.text, '\t\nSpaces and\ttabs\n  ');
    });
  });

  group('comment AST equality tests', () {
    test('single line comments with same text are equal', () {
      final comment1 = SingleLineComment(' Same text');
      final comment2 = SingleLineComment(' Same text');
      expect(comment1, equals(comment2));
    });

    test('single line comments with different text are not equal', () {
      final comment1 = SingleLineComment(' Different');
      final comment2 = SingleLineComment(' Text');
      expect(comment1, isNot(equals(comment2)));
    });

    test('multi-line comments with same text are equal', () {
      final comment1 = MultiLineComment('Same\ntext');
      final comment2 = MultiLineComment('Same\ntext');
      expect(comment1, equals(comment2));
    });

    test('multi-line comments with different text are not equal', () {
      final comment1 = MultiLineComment('Different\ntext');
      final comment2 = MultiLineComment('Other\ntext');
      expect(comment1, isNot(equals(comment2)));
    });

    test('single line and multi-line comments are not equal', () {
      final singleLine = SingleLineComment(' Text');
      final multiLine = MultiLineComment('Text');
      expect(singleLine, isNot(equals(multiLine)));
    });
  });
}
