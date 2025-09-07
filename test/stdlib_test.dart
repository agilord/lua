import 'package:lua/src/ast.dart';
import 'package:lua/src/evaluator.dart';
import 'package:test/test.dart';

void main() {
  group('standard library', () {
    test('print function', () {
      final env = LuaEnv.withStdlib();
      final block = Block([
        Call('print', [LuaString('Hello'), LuaString('World')]),
      ]);

      block.evaluate(env: env);
      expect(env.getOutput(), 'Hello\tWorld\n');
    });

    test('print function captures output', () {
      final env = LuaEnv.withStdlib();

      // Test multiple print calls
      Call('print', [LuaString('Line 1')]).evaluate(env: env);
      Call('print', [Number(42)]).evaluate(env: env);
      Call('print', [Bool(true), Bool(false)]).evaluate(env: env);

      final output = env.getOutput();
      final lines = env.getOutputLines();

      expect(output, 'Line 1\n42\ntrue\tfalse\n');
      expect(lines, ['Line 1', '42', 'true\tfalse']);
    });

    test('output buffer operations', () {
      final env = LuaEnv.withStdlib();

      // Initially empty
      expect(env.getOutput(), '');
      expect(env.getOutputLines(), []);

      // Add some output
      Call('print', [LuaString('Test')]).evaluate(env: env);
      expect(env.getOutput(), 'Test\n');

      // Clear output
      env.clearOutput();
      expect(env.getOutput(), '');

      // Add more output after clear
      Call('print', [LuaString('After clear')]).evaluate(env: env);
      expect(env.getOutput(), 'After clear\n');
    });

    test('custom output writer', () {
      final customOutput = <String>[];
      final customWriter = _TestOutputWriter(customOutput.add);

      final env = LuaEnv.withStdlib(output: customWriter);

      Call('print', [LuaString('Custom output')]).evaluate(env: env);
      Call('print', [Number(123)]).evaluate(env: env);

      expect(customOutput, ['Custom output', '123']);
    });

    test('console output option', () {
      // Test that console output can be enabled without breaking tests
      final buffer =
          LuaOutputBuffer(alsoConsole: false); // Don't spam console in tests
      final env = LuaEnv.withStdlib(output: buffer);

      Call('print', [LuaString('Test console')]).evaluate(env: env);
      expect(buffer.output, 'Test console\n');
      expect(buffer.lines, ['Test console']);
      expect(buffer.isNotEmpty, true);
    });

    test('type function', () {
      final env = LuaEnv.withStdlib();

      expect(Call('type', [Nil()]).evaluate(env: env), 'nil');
      expect(Call('type', [Bool(true)]).evaluate(env: env), 'boolean');
      expect(Call('type', [Number(42)]).evaluate(env: env), 'number');
      expect(Call('type', [LuaString('hello')]).evaluate(env: env), 'string');
      expect(Call('type', [Table([])]).evaluate(env: env), 'table');
    });

    test('tostring function', () {
      final env = LuaEnv.withStdlib();

      expect(Call('tostring', [Nil()]).evaluate(env: env), 'nil');
      expect(Call('tostring', [Bool(true)]).evaluate(env: env), 'true');
      expect(Call('tostring', [Number(42)]).evaluate(env: env), '42');
      expect(Call('tostring', [Number(3.14)]).evaluate(env: env), '3.14');
      expect(Call('tostring', [LuaString('test')]).evaluate(env: env), 'test');
    });

    test('tonumber function', () {
      final env = LuaEnv.withStdlib();

      expect(Call('tonumber', [Number(42)]).evaluate(env: env), 42);
      expect(Call('tonumber', [LuaString('123')]).evaluate(env: env), 123);
      expect(Call('tonumber', [LuaString('3.14')]).evaluate(env: env), 3.14);
      expect(Call('tonumber', [LuaString('not_a_number')]).evaluate(env: env),
          null);
      expect(Call('tonumber', [Bool(true)]).evaluate(env: env), null);
    });

    test('custom builtin function', () {
      num? customAdd(List<Object?> args) {
        if (args.length != 2) return null;
        final a = args[0] as num?;
        final b = args[1] as num?;
        if (a == null || b == null) return null;
        return a + b;
      }

      final env = LuaEnv(builtins: {'add': customAdd});
      expect(Call('add', [Number(5), Number(3)]).evaluate(env: env), 8);
    });

    test('stdlib with custom variables', () {
      final env = LuaEnv.withStdlib(variables: {'x': 42});

      expect(VarRef('x').evaluate(env: env), 42);
      expect(Call('type', [VarRef('x')]).evaluate(env: env), 'number');
    });
  });

  group('external objects', () {
    test('dart object wrapper', () {
      // Create a simple calculator object
      final calculator = LuaDartObject(
        'Calculator',
        methods: {
          'add': (List<Object?> args) {
            final a = args[0] as num;
            final b = args[1] as num;
            return a + b;
          },
          'multiply': (List<Object?> args) {
            final a = args[0] as num;
            final b = args[1] as num;
            return a * b;
          },
        },
        getters: {
          'version': () => '1.0',
          'name': () => 'Calculator',
        },
      );

      final env = LuaEnv(variables: {'calc': calculator});

      // Test method calls via field access
      final addMethod = FieldAccess(VarRef('calc'), 'add').evaluate(env: env)
          as Function(List);
      expect(addMethod([5, 3]), 8);

      // Test property access
      expect(FieldAccess(VarRef('calc'), 'version').evaluate(env: env), '1.0');
      expect(
          FieldAccess(VarRef('calc'), 'name').evaluate(env: env), 'Calculator');
    });

    test('external object indexing', () {
      final testObject = LuaDartObject(
        'TestObject',
        getters: {
          'property1': () => 'value1',
          'property2': () => 42,
        },
      );

      final env = LuaEnv(variables: {'obj': testObject});

      expect(Index(VarRef('obj'), LuaString('property1')).evaluate(env: env),
          'value1');
      expect(
          Index(VarRef('obj'), LuaString('property2')).evaluate(env: env), 42);
    });

    test('external object error handling', () {
      final testObject = LuaDartObject('TestObject');
      final env = LuaEnv(variables: {'obj': testObject});

      // Should throw when accessing non-existent property
      expect(
        () => FieldAccess(VarRef('obj'), 'nonexistent').evaluate(env: env),
        throwsA(isA<EvaluationException>()),
      );

      // Should throw when indexing with non-string key
      expect(
        () => Index(VarRef('obj'), Number(123)).evaluate(env: env),
        throwsA(isA<EvaluationException>()),
      );
    });

    test('callable dart object', () {
      final callableObject = LuaDartObject((List<Object?> args) {
        return 'Called with ${args.length} arguments';
      });

      final env = LuaEnv(variables: {'func': callableObject});

      // Test direct call - this would require Call to work with external objects
      // For now, test that the object is callable
      expect(callableObject.call([1, 2, 3]), 'Called with 3 arguments');
    });
  });

  group('integration', () {
    test('stdlib functions with external objects', () {
      final calculator = LuaDartObject(
        'Calculator',
        methods: {
          'compute': (List<Object?> args) => (args[0] as num) * 2,
        },
      );

      final env = LuaEnv.withStdlib(variables: {'calc': calculator});

      // Use type function on external object
      expect(Call('type', [VarRef('calc')]).evaluate(env: env), 'userdata');

      // Use tostring on external object
      final result =
          Call('tostring', [VarRef('calc')]).evaluate(env: env) as String;
      expect(result, contains('Calculator'));
    });

    test('complex interaction example', () {
      // Create a more complex example showing standard library and external objects working together
      final logger = LuaDartObject(
        'Logger',
        methods: {
          'log': (List<Object?> args) {
            final message = args.isNotEmpty ? args.first.toString() : '';
            return 'Logged: $message';
          },
        },
      );

      final env = LuaEnv.withStdlib(variables: {
        'logger': logger,
        'data': 'test data',
      });

      final block = Block([
        Assign.single('message', Call('tostring', [VarRef('data')]),
            isLocal: true),
        VarRef('message'),
      ]);

      expect(block.evaluate(env: env), 'test data');
    });
  });
}

/// Test implementation of LuaOutputWriter for testing custom output handling
class _TestOutputWriter implements LuaOutputWriter {
  final void Function(String) _onWrite;

  _TestOutputWriter(this._onWrite);

  @override
  void write(String text) => _onWrite(text);

  @override
  void writeLine(String text) => _onWrite(text);
}
