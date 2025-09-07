import 'package:lua/src/ast.dart';
import 'package:lua/src/evaluator.dart';
import 'package:lua/src/grammar.dart';
import 'package:test/test.dart';

void main() {
  group('length operator (#)', () {
    group('string length', () {
      test('simple string length', () {
        final luaCode = 'return #"hello"';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, 5);
      });

      test('empty string length', () {
        final luaCode = 'return #""';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, 0);
      });

      test('single character string length', () {
        final luaCode = 'return #"a"';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, 1);
      });

      test('unicode string length', () {
        final luaCode = 'return #"🎉"';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, 2); // UTF-16 code units
      });

      test('string with spaces length', () {
        final luaCode = 'return #"hello world"';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, 11);
      });

      test('string variable length', () {
        final luaCode = 'local s = "testing"; return #s';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, 7);
      });

      test('concatenated string length', () {
        final luaCode = 'return #("hello" .. "world")';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, 10);
      });
    });

    group('table length', () {
      test('array-like table length', () {
        final luaCode = 'return #{1, 2, 3, 4}';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, 4);
      });

      test('empty table length', () {
        final luaCode = 'return #{}';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, 0);
      });

      test('table with named fields length', () {
        final luaCode = 'return #{a = 1, b = 2, c = 3}';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, 3);
      });

      test('mixed table length', () {
        final luaCode = 'return #{1, 2, a = "hello", b = "world"}';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, 4);
      });

      test('table variable length', () {
        final luaCode = 'local t = {10, 20, 30}; return #t';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, 3);
      });

      test('nested table length', () {
        final luaCode = 'return #{{1, 2}, {3, 4}, {5, 6}}';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, 3);
      });
    });

    group('length operator parsing', () {
      test('parse length expression', () {
        final luaCode = 'return #"test"';

        final ast = parse(luaCode);

        expect(ast.statements.length, 1);
        expect(ast.statements[0], isA<Return>());

        final returnStmt = ast.statements[0] as Return;
        expect(returnStmt.values!.length, 1);
        expect(returnStmt.values![0], isA<Length>());

        final lengthExpr = returnStmt.values![0] as Length;
        expect(lengthExpr.value, isA<LuaString>());
      });

      test('parse length with table literal', () {
        final luaCode = 'return #{1, 2, 3}';

        final ast = parse(luaCode);

        expect(ast.statements.length, 1);
        expect(ast.statements[0], isA<Return>());

        final returnStmt = ast.statements[0] as Return;
        final lengthExpr = returnStmt.values![0] as Length;
        expect(lengthExpr.value, isA<Table>());
      });

      test('parse length with variable reference', () {
        final luaCode = 'return #myVar';

        final ast = parse(luaCode);

        final returnStmt = ast.statements[0] as Return;
        final lengthExpr = returnStmt.values![0] as Length;
        expect(lengthExpr.value, isA<VarRef>());
      });

      test('parse length in expression', () {
        final luaCode = 'return #"hello" + #"world"';

        final ast = parse(luaCode);

        final returnStmt = ast.statements[0] as Return;
        expect(returnStmt.values![0], isA<Add>());

        final addExpr = returnStmt.values![0] as Add;
        expect(addExpr.values.length, 2);
        expect(addExpr.values[0], isA<Length>());
        expect(addExpr.values[1], isA<Length>());
      });
    });

    group('length operator error cases', () {
      test('length of number should throw error', () {
        final luaCode = 'return #42';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();

        expect(
            () => ast.evaluate(env: env), throwsA(isA<EvaluationException>()));
      });

      test('length of boolean should throw error', () {
        final luaCode = 'return #true';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();

        expect(
            () => ast.evaluate(env: env), throwsA(isA<EvaluationException>()));
      });

      test('length of nil should throw error', () {
        final luaCode = 'return #nil';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();

        expect(
            () => ast.evaluate(env: env), throwsA(isA<EvaluationException>()));
      });
    });

    group('length operator in expressions', () {
      test('length in arithmetic expression', () {
        final luaCode = 'return #"hello" * 2';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, 10); // 5 * 2
      });

      test('length in comparison expression', () {
        final luaCode = 'return #"hello" > 3';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, true); // 5 > 3
      });

      test('length in conditional expression', () {
        final luaCode =
            'if #"test" == 4 then return "correct" else return "wrong" end';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, 'correct');
      });
    });

    group('length with function parameters', () {
      test('length of function parameter', () {
        final luaCode =
            'function getLength(s) return #s end; return getLength("testing")';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, 7);
      });

      test('length in function with table parameter', () {
        final luaCode =
            'function countItems(t) return #t end; return countItems({1, 2, 3, 4, 5})';

        final ast = parse(luaCode);
        final env = LuaEnv.withStdlib();
        final result = ast.evaluate(env: env);

        expect(result, 5);
      });
    });
  });
}
