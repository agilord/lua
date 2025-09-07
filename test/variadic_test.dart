import 'package:lua/src/ast.dart';
import 'package:lua/src/evaluator.dart';
import 'package:lua/src/grammar.dart';
import 'package:test/test.dart';

void main() {
  group('variadic functions', () {
    test('function with only variadic parameters', () {
      final luaCode = 'function test(...) return ... end; return test(1, 2, 3)';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();
      final result = ast.evaluate(env: env);

      expect(result, [1, 2, 3]);
    });

    test('function with regular and variadic parameters', () {
      final luaCode =
          'function test(a, b, ...) return a, b, ... end; return test(10, 20, 30, 40)';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();
      final result = ast.evaluate(env: env);

      expect(result, [10, 20, 30, 40]);
    });

    test('variadic function with no extra arguments', () {
      final luaCode = 'function test(a, ...) return a end; return test(42)';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();
      final result = ast.evaluate(env: env);

      expect(result, 42);
    });

    test('pure variadic function with no arguments', () {
      final luaCode = 'function test(...) return "called" end; return test()';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();
      final result = ast.evaluate(env: env);

      expect(result, 'called');
    });

    test('variadic arguments accessible inside function', () {
      final luaCode =
          'function test(...) return ... end; return test("hello", "world")';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();
      final result = ast.evaluate(env: env);

      expect(result, ['hello', 'world']);
    });

    test('variadic function with single argument', () {
      final luaCode = 'function test(...) return ... end; return test(99)';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();
      final result = ast.evaluate(env: env);

      expect(result, 99);
    });

    test('variadic arguments in nested function calls', () {
      final luaCode =
          'function inner(...) return ... end; function outer(...) return inner(...) end; return outer(1, 2, 3)';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();
      final result = ast.evaluate(env: env);

      expect(result, [1, 2, 3]);
    });

    test('mixed regular and variadic parameters with multiple values', () {
      final luaCode =
          'function test(first, second, ...) return first, second, ... end; return test("a", "b", "c", "d", "e")';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();
      final result = ast.evaluate(env: env);

      expect(result, ['a', 'b', 'c', 'd', 'e']);
    });
  });

  group('variadic function parsing', () {
    test('parse function with only variadic parameters', () {
      final luaCode = 'function test(...) end';

      final ast = parse(luaCode);

      expect(ast.statements.length, 1);
      expect(ast.statements[0], isA<FunctionDef>());

      final funcDef = ast.statements[0] as FunctionDef;
      expect(funcDef.name, 'test');
      expect(funcDef.args, isEmpty);
      expect(funcDef.hasVariadicArgs, true);
    });

    test('parse function with regular and variadic parameters', () {
      final luaCode = 'function test(a, b, ...) end';

      final ast = parse(luaCode);

      expect(ast.statements.length, 1);
      expect(ast.statements[0], isA<FunctionDef>());

      final funcDef = ast.statements[0] as FunctionDef;
      expect(funcDef.name, 'test');
      expect(funcDef.args, ['a', 'b']);
      expect(funcDef.hasVariadicArgs, true);
    });

    test('parse regular function (no variadic args)', () {
      final luaCode = 'function test(a, b) end';

      final ast = parse(luaCode);

      expect(ast.statements.length, 1);
      expect(ast.statements[0], isA<FunctionDef>());

      final funcDef = ast.statements[0] as FunctionDef;
      expect(funcDef.name, 'test');
      expect(funcDef.args, ['a', 'b']);
      expect(funcDef.hasVariadicArgs, false);
    });

    test('parse empty parameter list', () {
      final luaCode = 'function test() end';

      final ast = parse(luaCode);

      expect(ast.statements.length, 1);
      expect(ast.statements[0], isA<FunctionDef>());

      final funcDef = ast.statements[0] as FunctionDef;
      expect(funcDef.name, 'test');
      expect(funcDef.args, isEmpty);
      expect(funcDef.hasVariadicArgs, false);
    });
  });

  group('variadic arguments expression', () {
    test('using ... outside variadic function should throw error', () {
      final luaCode = 'return ...';

      final ast = parse(luaCode);
      final env = LuaEnv.withStdlib();

      expect(() => ast.evaluate(env: env), throwsA(isA<EvaluationException>()));
    });

    test('... expression parsing', () {
      final luaCode = 'function test(...) return ... end';

      final ast = parse(luaCode);

      expect(ast.statements.length, 1);
      expect(ast.statements[0], isA<FunctionDef>());

      final funcDef = ast.statements[0] as FunctionDef;
      final returnStmt = funcDef.body.statements[0] as Return;
      expect(returnStmt.values![0], isA<VariadicArgs>());
    });
  });
}
