import 'package:lua/src/ast.dart';
import 'package:lua/src/evaluator.dart';
import 'package:test/test.dart';
import '../example/hub.dart';

void main() {
  group('hub examples', () {
    test('static hub example', () {
      final staticHub = createStaticHub();
      final env = LuaEnv.withStdlib(variables: {'hub': staticHub});

      // Test add method
      final addFunc = FieldAccess(VarRef('hub'), 'add').evaluate(env: env)
          as Function(List);
      final sum = addFunc([10, 5]);
      expect(sum, 15);

      // Test greet method
      final greetFunc = FieldAccess(VarRef('hub'), 'greet').evaluate(env: env)
          as Function(List);
      final greeting = greetFunc(['Lua']);
      expect(greeting, 'Hello, Lua!');

      // Test version property
      final version = FieldAccess(VarRef('hub'), 'version').evaluate(env: env);
      expect(version, '1.0.0');

      // Test name property
      final name = FieldAccess(VarRef('hub'), 'name').evaluate(env: env);
      expect(name, 'StaticHub');

      // Test methodCount property
      final methodCount =
          FieldAccess(VarRef('hub'), 'methodCount').evaluate(env: env);
      expect(methodCount, 9);
    });

    test('flexible hub example', () {
      final dynamicHub = FlexibleHub()
        ..addMethod('double', (args) => (args[0] as num) * 2)
        ..addMethod(
            'reverse', (args) => (args[0] as String).split('').reversed.join())
        ..addMethod('factorial', (args) {
          final n = args[0] as int;
          return List.generate(n, (i) => i + 1).fold(1, (a, b) => a * b);
        })
        ..addProperty('status', 'ready')
        ..addProperty('count', 0);

      final env =
          LuaEnv.withStdlib(variables: {'flex': dynamicHub.toLuaObject()});

      // Test double method
      final doubleFunc = FieldAccess(VarRef('flex'), 'double')
          .evaluate(env: env) as Function(List);
      final doubled = doubleFunc([21]);
      expect(doubled, 42);

      // Test reverse method
      final reverseFunc = FieldAccess(VarRef('flex'), 'reverse')
          .evaluate(env: env) as Function(List);
      final reversed = reverseFunc(['hello']);
      expect(reversed, 'olleh');

      // Test factorial method
      final factorialFunc = FieldAccess(VarRef('flex'), 'factorial')
          .evaluate(env: env) as Function(List);
      final factorial = factorialFunc([5]);
      expect(factorial, 120);

      // Test status property
      final status = FieldAccess(VarRef('flex'), 'status').evaluate(env: env);
      expect(status, 'ready');

      // Test introspection methods
      final listMethodsFunc = FieldAccess(VarRef('flex'), 'listMethods')
          .evaluate(env: env) as Function(List);
      final methods = listMethodsFunc([]) as List;
      expect(methods, contains('double'));
      expect(methods, contains('reverse'));
      expect(methods, contains('factorial'));

      final hasMethodFunc = FieldAccess(VarRef('flex'), 'hasMethod')
          .evaluate(env: env) as Function(List);
      expect(hasMethodFunc(['double']), true);
      expect(hasMethodFunc(['nonexistent']), false);
    });

    test('nested hub example', () {
      final apiHub = createNestedHub();
      final env = LuaEnv.withStdlib(variables: {'api': apiHub});

      // Test math category
      final mathCategory = FieldAccess(VarRef('api'), 'math').evaluate(env: env)
          as LuaDartObject;
      final sqrtFunc = mathCategory.getProperty('sqrt') as Function(List);
      final sqrt = sqrtFunc([16]);
      expect(sqrt, 4.0);

      // Test math constants
      final pi = mathCategory.getProperty('pi');
      expect(pi, closeTo(3.14159, 0.001));

      // Test string category
      final stringCategory = FieldAccess(VarRef('api'), 'string')
          .evaluate(env: env) as LuaDartObject;
      final upperFunc = stringCategory.getProperty('upper') as Function(List);
      final upper = upperFunc(['hello']);
      expect(upper, 'HELLO');

      final lengthFunc = stringCategory.getProperty('length') as Function(List);
      final length = lengthFunc(['test']);
      expect(length, 4);

      // Test array category
      final arrayCategory = FieldAccess(VarRef('api'), 'array')
          .evaluate(env: env) as LuaDartObject;
      final joinFunc = arrayCategory.getProperty('join') as Function(List);
      final joined = joinFunc([
        ['a', 'b', 'c'],
        '-'
      ]);
      expect(joined, 'a-b-c');

      // Test hub methods
      final listCategoriesFunc = FieldAccess(VarRef('api'), 'listCategories')
          .evaluate(env: env) as Function(List);
      final categories = listCategoriesFunc([]) as List;
      expect(categories, containsAll(['math', 'string', 'array']));
    });

    test('plugin hub example', () {
      final pluginHub = PluginHub();

      // Register math plugin
      pluginHub.registerPlugin('math', <String, Function(List)>{
        'square': (args) => (args[0] as num) * (args[0] as num),
        'cube': (args) =>
            (args[0] as num) * (args[0] as num) * (args[0] as num),
        'isPrime': (args) {
          final n = args[0] as int;
          if (n < 2) return false;
          for (int i = 2; i * i <= n; i++) {
            if (n % i == 0) return false;
          }
          return true;
        }
      });

      // Register string plugin
      pluginHub.registerPlugin('string', <String, Function(List)>{
        'palindrome': (args) {
          final str = (args[0] as String).toLowerCase();
          return str == str.split('').reversed.join();
        },
        'wordCount': (args) => (args[0] as String).split(' ').length,
        'capitalize': (args) => (args[0] as String)
            .split(' ')
            .map((word) =>
                word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
            .join(' '),
      });

      final env =
          LuaEnv.withStdlib(variables: {'plugins': pluginHub.toLuaObject()});

      // Test math plugin
      final mathPlugin = FieldAccess(VarRef('plugins'), 'math')
          .evaluate(env: env) as LuaDartObject;
      final squareFunc = mathPlugin.getProperty('square') as Function(List);
      final squared = squareFunc([7]);
      expect(squared, 49);

      final isPrimeFunc = mathPlugin.getProperty('isPrime') as Function(List);
      expect(isPrimeFunc([17]), true);
      expect(isPrimeFunc([18]), false);

      // Test string plugin
      final stringPlugin = FieldAccess(VarRef('plugins'), 'string')
          .evaluate(env: env) as LuaDartObject;
      final palindromeFunc =
          stringPlugin.getProperty('palindrome') as Function(List);
      expect(palindromeFunc(['racecar']), true);
      expect(palindromeFunc(['hello']), false);

      final capitalizeFunc =
          stringPlugin.getProperty('capitalize') as Function(List);
      final capitalized = capitalizeFunc(['hello world']);
      expect(capitalized, 'Hello World');

      // Test plugin management
      final listPluginsFunc = FieldAccess(VarRef('plugins'), 'listPlugins')
          .evaluate(env: env) as Function(List);
      final plugins = listPluginsFunc([]) as List;
      expect(plugins, containsAll(['math', 'string']));

      final hasPluginFunc = FieldAccess(VarRef('plugins'), 'hasPlugin')
          .evaluate(env: env) as Function(List);
      expect(hasPluginFunc(['math']), true);
      expect(hasPluginFunc(['nonexistent']), false);
    });

    test('state hub example', () {
      final stateHub = StateHub();
      final env =
          LuaEnv.withStdlib(variables: {'state': stateHub.toLuaObject()});

      // Test storage methods
      final storeFunc = FieldAccess(VarRef('state'), 'store').evaluate(env: env)
          as Function(List);
      storeFunc(['user', 'Alice']);
      storeFunc(['score', 95]);

      final retrieveFunc = FieldAccess(VarRef('state'), 'retrieve')
          .evaluate(env: env) as Function(List);
      final user = retrieveFunc(['user']);
      final score = retrieveFunc(['score']);
      expect(user, 'Alice');
      expect(score, 95);

      // Test counter methods
      final incrementFunc = FieldAccess(VarRef('state'), 'increment')
          .evaluate(env: env) as Function(List);
      incrementFunc([]);
      incrementFunc([]);

      final counter =
          FieldAccess(VarRef('state'), 'counter').evaluate(env: env);
      expect(counter, 2);

      // Test storage properties
      final storageSize =
          FieldAccess(VarRef('state'), 'storageSize').evaluate(env: env);
      expect(storageSize, 2); // user and score

      final isEmpty =
          FieldAccess(VarRef('state'), 'isEmpty').evaluate(env: env);
      expect(isEmpty, false);

      // Test history
      final getHistoryFunc = FieldAccess(VarRef('state'), 'getHistory')
          .evaluate(env: env) as Function(List);
      final history = getHistoryFunc([]) as List;
      expect(history, contains('STORE user'));
      expect(history, contains('STORE score'));
      expect(history, contains('INCREMENT'));

      // Test key operations
      final keysFunc = FieldAccess(VarRef('state'), 'keys').evaluate(env: env)
          as Function(List);
      final keys = keysFunc([]) as List;
      expect(keys, containsAll(['user', 'score']));

      final hasFunc = FieldAccess(VarRef('state'), 'has').evaluate(env: env)
          as Function(List);
      expect(hasFunc(['user']), true);
      expect(hasFunc(['nonexistent']), false);

      // Test clear
      final clearFunc = FieldAccess(VarRef('state'), 'clear').evaluate(env: env)
          as Function(List);
      clearFunc([]);

      final isEmptyAfterClear =
          FieldAccess(VarRef('state'), 'isEmpty').evaluate(env: env);
      expect(isEmptyAfterClear, true);
    });

    test('all hub examples run without errors', () {
      // This test runs the main function from hub.dart to ensure it executes without throwing
      expect(() {
        // Create instances of all hub types
        createStaticHub();
        FlexibleHub().toLuaObject();
        createNestedHub();
        PluginHub().toLuaObject();
        StateHub().toLuaObject();
      }, returnsNormally);
    });

    test('hub integration with print function', () {
      final staticHub = createStaticHub();
      final env = LuaEnv.withStdlib(variables: {'hub': staticHub});

      // Test that we can use hub methods with print
      final addFunc = FieldAccess(VarRef('hub'), 'add').evaluate(env: env)
          as Function(List);
      final sum = addFunc([10, 5]);
      Call('print', [LuaString('Sum:'), Number(sum as num)]).evaluate(env: env);

      final output = env.getOutput();
      expect(output, 'Sum:\t15\n');
    });

    test('hub type checking with type function', () {
      final staticHub = createStaticHub();
      final env = LuaEnv.withStdlib(variables: {'hub': staticHub});

      // Test type function with external object
      final hubType = Call('type', [VarRef('hub')]).evaluate(env: env);
      expect(hubType, 'userdata');

      // Test that we can access method properties (functions are accessible as values)
      final addMethod = FieldAccess(VarRef('hub'), 'add').evaluate(env: env);
      expect(addMethod, isA<Function>());
    });
  });
}
