import 'dart:math' as math;

import 'package:lua/src/evaluator.dart';
import 'package:lua/src/grammar.dart';
import 'package:test/test.dart';

void main() {
  group('standard library functions', () {
    group('basic functions', () {
      test('rawget function', () {
        final luaCode =
            'local t = {hello = "world", count = 42}; return rawget(t, "hello"), rawget(t, "count"), rawget(t, "missing")';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, ['world', 42, null]);
      });

      test('rawset function', () {
        final luaCode =
            'local t = {}; rawset(t, "key1", "value1"); rawset(t, "key2", 123); return rawget(t, "key1"), rawget(t, "key2")';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, ['value1', 123]);
      });

      test('rawset returns table', () {
        final luaCode =
            'local t = {}; local result = rawset(t, "test", "value"); return rawget(result, "test")';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, 'value');
      });
    });

    group('metatable functions', () {
      test('setmetatable returns table', () {
        final luaCode =
            'local t = {}; local mt = {}; local result = setmetatable(t, mt); return result == t';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, true);
      });

      test('getmetatable returns nil for no metatable', () {
        final luaCode = 'local t = {}; return getmetatable(t)';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, null);
      });
    });

    group('math library constants', () {
      test('math.pi', () {
        final luaCode = 'return math.pi';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, closeTo(math.pi, 0.0001));
      });

      test('math.huge', () {
        final luaCode = 'return math.huge';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, double.infinity);
      });
    });

    group('math library basic arithmetic', () {
      test('math.abs', () {
        final luaCode = 'return math.abs(-5), math.abs(3.14), math.abs(0)';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, [5, 3.14, 0]);
      });

      test('math.ceil', () {
        final luaCode = 'return math.ceil(3.1), math.ceil(-2.9), math.ceil(5)';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, [4, -2, 5]);
      });

      test('math.floor', () {
        final luaCode =
            'return math.floor(3.9), math.floor(-2.1), math.floor(5)';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, [3, -3, 5]);
      });

      test('math.sqrt', () {
        final luaCode = 'return math.sqrt(16), math.sqrt(0)';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env) as List;

        expect(result[0], 4.0);
        expect(result[1], 0.0);
      });

      test('math.pow', () {
        final luaCode = 'return math.pow(2, 3), math.pow(4, 0.5)';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, [8, 2.0]);
      });
    });

    group('string library', () {
      test('string.len', () {
        final luaCode = 'return string.len("hello"), string.len("")';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, [5, 0]);
      });

      test('string.upper', () {
        final luaCode = 'return string.upper("Hello World"), string.upper("")';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, ['HELLO WORLD', '']);
      });

      test('string.lower', () {
        final luaCode = 'return string.lower("Hello World"), string.lower("")';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, ['hello world', '']);
      });

      test('string.reverse', () {
        final luaCode = 'return string.reverse("hello"), string.reverse("a")';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, ['olleh', 'a']);
      });

      test('string.rep', () {
        final luaCode = 'return string.rep("hi", 3), string.rep("x", 0)';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, ['hihihi', '']);
      });

      test('string.char', () {
        final luaCode = 'return string.char(65, 66, 67)';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, 'ABC');
      });

      test('string.byte', () {
        final luaCode = 'return string.byte("ABC", 1), string.byte("ABC", 2)';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, [65, 66]);
      });
    });

    group('error handling', () {
      test('rawget with non-table throws error', () {
        final luaCode = 'return rawget("not a table", "key")';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();

        expect(
          () => ast.evaluate(env: env),
          throwsA(isA<EvaluationException>()),
        );
      });

      test('math.abs with non-number throws error', () {
        final luaCode = 'return math.abs("not a number")';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();

        expect(
          () => ast.evaluate(env: env),
          throwsA(isA<EvaluationException>()),
        );
      });

      test('string.len with non-string throws error', () {
        final luaCode = 'return string.len(42)';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();

        expect(
          () => ast.evaluate(env: env),
          throwsA(isA<EvaluationException>()),
        );
      });
    });

    group('integration tests', () {
      test('mixed operations', () {
        final luaCode =
            'local x = math.abs(-5); local upper = string.upper("hello"); return x, upper';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, [5, 'HELLO']);
      });

      test('table operations with metatable', () {
        final luaCode =
            'local t = {}; local mt = {}; setmetatable(t, mt); rawset(t, "key", "value"); return rawget(t, "key")';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, 'value');
      });
    });
  });
}
