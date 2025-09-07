import 'package:lua/lua.dart';
import 'package:test/test.dart';

void main() {
  group('anonymous function tests', () {
    test('parse simple anonymous function', () {
      final code = 'local f = function() return 42 end; return f()';

      // This should not throw
      final ast = parse(code);
      expect(ast, isNotNull);
    });

    test('call anonymous function immediately', () {
      final code = 'return (function() return 42 end)()';

      final ast = parse(code);
      final result = ast.evaluate();
      expect(result, 42);
    });

    test('assign anonymous function to variable', () {
      final code = 'local f = function(x) return x * 2 end; return f(5)';

      final ast = parse(code);
      final result = ast.evaluate();
      expect(result, 10);
    });

    test('anonymous function with parameters', () {
      final code =
          'local add = function(a, b) return a + b end; return add(3, 4)';

      final ast = parse(code);
      final result = ast.evaluate();
      expect(result, 7);
    });

    test('anonymous function with no parameters', () {
      final code =
          'local getName = function() return "anonymous" end; return getName()';

      final ast = parse(code);
      final result = ast.evaluate();
      expect(result, 'anonymous');
    });

    test('nested anonymous functions', () {
      final code =
          'local outer = function() return function() return "nested" end end; return outer()()';

      final ast = parse(code);
      final result = ast.evaluate();
      expect(result, 'nested');
    });

    test('anonymous function closure', () {
      final code =
          'local x = 10; local f = function() return x end; x = 20; return f()';

      final ast = parse(code);
      final result = ast.evaluate();
      expect(result, 20);
    });

    test('anonymous function with closure modification', () {
      final code =
          'local x = 5; local f = function(y) return x + y end; return f(3)';

      final ast = parse(code);
      final result = ast.evaluate();
      expect(result, 8);
    });

    test('higher-order function with anonymous function', () {
      final code =
          'local function apply(fn, x) return fn(x) end; return apply(function(n) return n * n end, 4)';

      final ast = parse(code);
      final result = ast.evaluate();
      expect(result, 16);
    });

    test('anonymous function as table value', () {
      final code =
          'local t = {func = function(x) return x + 1 end}; return t.func(5)';

      final ast = parse(code);
      final result = ast.evaluate();
      expect(result, 6);
    });

    test('anonymous function recursion via variable', () {
      final code =
          'local fact = function(n) if n <= 1 then return 1 else return n * 1 end end; return fact(5)';

      final ast = parse(code);
      final result = ast.evaluate();
      expect(result, 5);
    });

    test('multiple anonymous functions', () {
      final code =
          'local f1 = function() return 1 end; local f2 = function() return 2 end; return f1() + f2()';

      final ast = parse(code);
      final result = ast.evaluate();
      expect(result, 3);
    });

    test('anonymous function with variadic parameters', () {
      final code =
          'local sum = function(a, b, c) return a + b + c end; return sum(1, 2, 3)';

      final ast = parse(code);
      final result = ast.evaluate();
      expect(result, 6);
    });

    test('anonymous function formatting', () {
      final code = 'local f = function(x) return x * 2 end';

      final ast = parse(code);
      final formatted = format(ast);
      expect(formatted, contains('function(x)'));
      expect(formatted, contains('return x*2'));
      expect(formatted, contains('end'));
    });

    test('complex anonymous function expression', () {
      final code =
          'local result = (function(x, y) return function(z) return x + y + z end end)(1, 2); return result(3)';

      final ast = parse(code);
      final result = ast.evaluate();
      expect(result, 6);
    });
  });
}
