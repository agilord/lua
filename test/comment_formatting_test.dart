import 'package:lua/lua.dart';
import 'package:test/test.dart';

void main() {
  group('comment formatting tests', () {
    test('format single line comment', () {
      final comment = SingleLineComment(' This is a comment');
      expect(format(comment), '-- This is a comment');
    });

    test('format empty single line comment', () {
      final comment = SingleLineComment('');
      expect(format(comment), '--');
    });

    test('format single line comment with special characters', () {
      final comment = SingleLineComment(r' Special chars: !@#$%^&*()');
      expect(format(comment), r'-- Special chars: !@#$%^&*()');
    });

    test('format multi-line comment', () {
      final comment = MultiLineComment('This is a\nmulti-line comment');
      expect(format(comment), '--[[This is a\nmulti-line comment]]');
    });

    test('format empty multi-line comment', () {
      final comment = MultiLineComment('');
      expect(format(comment), '--[[]]');
    });

    test('format multi-line comment with special characters', () {
      final comment = MultiLineComment('Special chars: [nested] brackets');
      expect(format(comment), '--[[Special chars: [nested] brackets]]');
    });

    test('format block with single line comments', () {
      final block = Block([
        SingleLineComment(' First comment'),
        SingleLineComment(' Second comment'),
      ]);
      expect(format(block), '-- First comment\n-- Second comment');
    });

    test('format block with multi-line comments', () {
      final block = Block([
        MultiLineComment('First\ncomment'),
        MultiLineComment('Second comment'),
      ]);
      expect(format(block), '--[[First\ncomment]]\n--[[Second comment]]');
    });

    test('format block with mixed comments and code', () {
      final block = Block([
        SingleLineComment(' Start of program'),
        Assign.single('x', Number(5), isLocal: true),
        MultiLineComment('Variable x is now 5'),
        Call('print', [VarRef('x')]),
        SingleLineComment(' End of program'),
      ]);

      final expected =
          '-- Start of program\n'
          'local x=5\n'
          '--[[Variable x is now 5]]\n'
          'print(x)\n'
          '-- End of program';

      expect(format(block), expected);
    });

    test('format function with comments', () {
      final functionWithComments = Block([
        SingleLineComment(' Define a function'),
        FunctionDef(
          'test',
          ['x'],
          Block([
            MultiLineComment('This function\nprints the input'),
            Call('print', [VarRef('x')]),
            SingleLineComment(' Return nothing'),
            Return(),
          ]),
        ),
      ]);

      final formatted = format(functionWithComments);
      expect(formatted, contains('-- Define a function'));
      expect(formatted, contains('--[[This function\nprints the input]]'));
      expect(formatted, contains('-- Return nothing'));
    });

    test('format if statement with comments', () {
      final ifWithComments = Block([
        SingleLineComment(' Check if x is positive'),
        If(
          Greater(VarRef('x'), Number(0)),
          Block([
            MultiLineComment('x is positive\nprint a message'),
            Call('print', [LuaString('positive')]),
          ]),
          elseBlock: Block([
            SingleLineComment(' x is not positive'),
            Call('print', [LuaString('not positive')]),
          ]),
        ),
      ]);

      final formatted = format(ifWithComments);
      expect(formatted, contains('-- Check if x is positive'));
      expect(formatted, contains('--[[x is positive\nprint a message]]'));
      expect(formatted, contains('-- x is not positive'));
    });

    test('format while loop with comments', () {
      final whileWithComments = Block([
        SingleLineComment(' Initialize counter'),
        Assign.single('i', Number(1), isLocal: true),
        SingleLineComment(' Loop while i <= 3'),
        While(
          LessEq(VarRef('i'), Number(3)),
          Block([
            MultiLineComment('Print current value\nand increment'),
            Call('print', [VarRef('i')]),
            Assign.single('i', Add([VarRef('i'), Number(1)])),
          ]),
        ),
        SingleLineComment(' Loop finished'),
      ]);

      final formatted = format(whileWithComments);
      expect(formatted, contains('-- Initialize counter'));
      expect(formatted, contains('-- Loop while i <= 3'));
      expect(formatted, contains('--[[Print current value\nand increment]]'));
      expect(formatted, contains('-- Loop finished'));
    });

    test('format comments preserve original text', () {
      final originalCode =
          '-- This is a comment\n--[[Multi-line\ncomment here]]';

      final ast = parse(originalCode);
      final formatted = format(ast);

      expect(formatted, contains('-- This is a comment'));
      expect(formatted, contains('--[[Multi-line\ncomment here]]'));
    });

    test('format comment toString methods', () {
      final singleLine = SingleLineComment(' Test comment');
      final multiLine = MultiLineComment('Test\ncomment');

      expect(singleLine.toString(), '-- Test comment');
      expect(multiLine.toString(), '--[[Test\ncomment]]');
    });

    test('format comments with tabs and spaces', () {
      final singleLineWithTabs = SingleLineComment('\t\tTabbed comment');
      final multiLineWithSpaces = MultiLineComment('  Spaced\n\tcomment  ');

      expect(format(singleLineWithTabs), '--\t\tTabbed comment');
      expect(format(multiLineWithSpaces), '--[[  Spaced\n\tcomment  ]]');
    });

    test('format nested structure with comments', () {
      final nested = Block([
        SingleLineComment(' Outer comment'),
        Do(
          Block([
            MultiLineComment('Inner block\ncomment'),
            Assign.single('nested', Bool(true), isLocal: true),
          ]),
        ),
        SingleLineComment(' After do block'),
      ]);

      final formatted = format(nested);
      expect(formatted, contains('-- Outer comment'));
      expect(formatted, contains('--[[Inner block\ncomment]]'));
      expect(formatted, contains('-- After do block'));
    });
  });

  group('comment roundtrip tests', () {
    test('parse and format single line comment roundtrip', () {
      final originalComment = '-- This is a test comment';
      final ast = parse(originalComment);
      final formatted = format(ast);
      expect(formatted, originalComment);
    });

    test('parse and format multi-line comment roundtrip', () {
      final originalComment = '--[[This is a\nmulti-line comment]]';
      final ast = parse(originalComment);
      final formatted = format(ast);
      expect(formatted, originalComment);
    });

    test('parse and format empty comments roundtrip', () {
      final emptySingle = '--';
      final emptyMulti = '--[[]]';

      expect(format(parse(emptySingle)), emptySingle);
      expect(format(parse(emptyMulti)), emptyMulti);
    });

    test('parse and format complex code with comments roundtrip', () {
      final originalCode =
          '-- Program start\n--[[Calculate factorial\nrecursively]]\n-- End comment';

      final ast = parse(originalCode);
      final formatted = format(ast);

      // Parse the formatted version again to ensure it's valid
      final reparsed = parse(formatted);
      expect(reparsed, isNotNull);

      // Check that all comments are preserved
      expect(formatted, contains('-- Program start'));
      expect(formatted, contains('--[[Calculate factorial\nrecursively]]'));
      expect(formatted, contains('-- End comment'));
    });
  });
}
