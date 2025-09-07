import 'package:lua/src/evaluator.dart';
import 'package:lua/src/grammar.dart';
import 'package:test/test.dart';

void main() {
  group('variable scoping', () {
    test('local variables in same block', () {
      final luaCode = 'local x = 10; local y = 20; return x + y';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();
      final result = ast.evaluate(env: env);

      expect(result, 30);
    });

    test('global variable assignment and access', () {
      final luaCode = 'x = 42; return x';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();
      final result = ast.evaluate(env: env);

      expect(result, 42);
    });

    test('function with parameters', () {
      final luaCode = 'function test(a, b) return a + b end; return test(5, 3)';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();
      final result = ast.evaluate(env: env);

      expect(result, 8);
    });

    test('function with local variables', () {
      final luaCode =
          'function test() local x = 10; return x end; return test()';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();
      final result = ast.evaluate(env: env);

      expect(result, 10);
    });

    test('function parameters shadow global variables', () {
      final luaCode =
          'x = "global"; function test(x) return x end; return test("param")';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();
      final result = ast.evaluate(env: env);

      expect(result, 'param');
    });

    test('for loop variables are locally scoped', () {
      final luaCode =
          'x = "outer"; for i = 1, 2 do print("loop", i) end; return x';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();
      final result = ast.evaluate(env: env);

      expect(result, 'outer');
      final output = env.getOutput();
      expect(output, contains('loop\t1'));
      expect(output, contains('loop\t2'));
    });

    test('for-in loop variables are locally scoped', () {
      final luaCode =
          'k = "outer"; local t = {a = 1, b = 2}; for k, v in pairs(t) do print("loop:", k) end; return k';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();
      final result = ast.evaluate(env: env);

      expect(result, 'outer');
      final output = env.getOutput();
      expect(output, contains('loop:'));
    });

    test('variable not found error', () {
      final luaCode =
          'function test() return nonexistent_var end; return test()';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();

      expect(() => ast.evaluate(env: env), throwsA(isA<EvaluationException>()));
    });

    test('local variable shadows global', () {
      final luaCode =
          'x = "global"; function test() local x = "local"; return x end; return test()';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();
      final result = ast.evaluate(env: env);

      expect(result, 'local');
    });

    test('global variable accessible from function', () {
      final luaCode =
          'global_var = 100; function test() return global_var end; return test()';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();
      final result = ast.evaluate(env: env);

      expect(result, 100);
    });

    test('assignment without local creates global', () {
      final luaCode =
          'function test() new_global = 42; return new_global end; return test()';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();
      final result = ast.evaluate(env: env);

      expect(result, 42);
    });

    test('if statement local scoping', () {
      final luaCode =
          'x = "outer"; if true then local x = "inner"; print(x) end; return x';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();
      final result = ast.evaluate(env: env);

      expect(result, 'outer');
      final output = env.getOutput();
      expect(output.trim(), 'inner');
    });

    test('while loop local scoping', () {
      final luaCode =
          'x = "outer"; i = 1; while i <= 1 do local x = "inner"; print(x); i = 2 end; return x';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();
      final result = ast.evaluate(env: env);

      expect(result, 'outer');
      final output = env.getOutput();
      expect(output.trim(), 'inner');
    });
  });

  group('function call scoping', () {
    test('function can modify global variables', () {
      final luaCode =
          'x = 1; function increment() x = x + 1; return x end; return increment()';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();
      final result = ast.evaluate(env: env);

      expect(result, 2);
    });

    test('function local variables do not affect globals', () {
      final luaCode =
          'x = 1; function test() local x = 10; return x end; local result = test(); return x + result';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();
      final result = ast.evaluate(env: env);

      expect(result, 11); // global x (1) + local x from function (10)
    });

    test('function creates proper local scope', () {
      final luaCode =
          'function outer() local a = 1; local b = 2; return a + b end; return outer()';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();
      final result = ast.evaluate(env: env);

      expect(result, 3);
    });

    test('function parameters are local', () {
      final luaCode =
          'a = "global"; function test(a, b) return a .. b end; return test("hello", "world")';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();
      final result = ast.evaluate(env: env);

      expect(result, 'helloworld');
    });

    test('nested function calls with local variables', () {
      final luaCode =
          'function add(x, y) return x + y end; function calc() local a = 5; local b = 3; return add(a, b) end; return calc()';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();
      final result = ast.evaluate(env: env);

      expect(result, 8);
    });
  });
}
