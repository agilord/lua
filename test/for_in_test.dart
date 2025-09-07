import 'package:lua/src/ast.dart';
import 'package:lua/src/evaluator.dart';
import 'package:lua/src/grammar.dart';
import 'package:test/test.dart';

void main() {
  group('for-in loops', () {
    test('basic pairs iteration', () {
      final luaCode =
          'local t = {a = 1, b = 2, c = 3}; for k, v in pairs(t) do print(k, v) end';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();
      ast.evaluate(env: env);

      final output = env.getOutput();
      // Check that pairs were printed
      expect(output, isNotEmpty);
    });

    test('basic ipairs iteration', () {
      final luaCode =
          'local t = {10, 20, 30}; for i, v in ipairs(t) do print(i, v) end';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();
      ast.evaluate(env: env);

      final output = env.getOutput();
      expect(output, contains('1\t10'));
      expect(output, contains('2\t20'));
      expect(output, contains('3\t30'));
    });

    test('for-in with print output', () {
      final luaCode =
          'local fruits = {apple = "red", banana = "yellow"}; for fruit, color in pairs(fruits) do print(fruit, color) end';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();
      ast.evaluate(env: env);

      final output = env.getOutput();
      expect(output, isNotEmpty);
    });

    test('single variable for-in', () {
      final luaCode =
          'local t = {a = 1, b = 2}; for k in pairs(t) do print("key:", k) end';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();
      ast.evaluate(env: env);

      final output = env.getOutput();
      expect(output, contains('key:'));
    });

    test('error on non-iterator', () {
      final luaCode = 'for k, v in 42 do print(k, v) end';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();

      expect(() => ast.evaluate(env: env), throwsA(isA<EvaluationException>()));
    });

    test('empty table iteration', () {
      final luaCode =
          'local t = {}; for k, v in pairs(t) do print("should not print") end';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();
      ast.evaluate(env: env);

      final output = env.getOutput();
      expect(output.trim(),
          isEmpty); // Empty table should not iterate, so no output
    });
  });

  group('for-in parsing', () {
    test('parse for-in with pairs', () {
      final code = 'for k, v in pairs(t) do print(k, v) end';
      final ast = parse(code);
      final stmt = ast.statements.first as ForEach;

      expect(stmt.names, ['k', 'v']);
      expect(stmt.values.length, 1);
      expect(stmt.values.first, isA<Call>());
      final call = stmt.values.first as Call;
      expect(call.name, 'pairs');
    });

    test('parse for-in with single variable', () {
      final code = 'for k in pairs(t) do print(k) end';
      final ast = parse(code);
      final stmt = ast.statements.first as ForEach;

      expect(stmt.names, ['k']);
      expect(stmt.values.length, 1);
    });

    test('parse for-in with ipairs', () {
      final code = 'for i, v in ipairs(arr) do print(i, v) end';
      final ast = parse(code);
      final stmt = ast.statements.first as ForEach;

      expect(stmt.names, ['i', 'v']);
      final call = stmt.values.first as Call;
      expect(call.name, 'ipairs');
    });
  });
}
