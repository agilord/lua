import 'dart:math' as math;
import 'package:lua/src/ast.dart';
import 'package:lua/src/evaluator.dart';

void main() {
  print('=== External Object Hub Examples ===\n');

  // Example 1: Static Hub (Predefined Methods)
  print('1. Static Hub with Predefined Methods:');
  final staticHub = createStaticHub();
  final env1 = LuaEnv.withStdlib(variables: {'hub': staticHub});

  // Call methods through field access
  final addFunc = FieldAccess(VarRef('hub'), 'add').evaluate(env: env1) as Function;
  final sum = addFunc([10, 5]);
  Call('print', [LuaString('10 + 5 ='), Number(sum as num)]).evaluate(env: env1);

  final greetFunc = FieldAccess(VarRef('hub'), 'greet').evaluate(env: env1) as Function;
  final greeting = greetFunc(['Lua']);
  Call('print', [LuaString('Greeting:'), LuaString(greeting as String)]).evaluate(env: env1);

  // Access properties
  final version = FieldAccess(VarRef('hub'), 'version').evaluate(env: env1);
  Call('print', [LuaString('Version:'), LuaString(version as String)]).evaluate(env: env1);

  print('Output:\n${env1.getOutput()}');

  // Example 2: Dynamic Hub (Runtime Method Registration)
  print('2. Dynamic Hub - Add Methods at Runtime:');
  final dynamicHub = FlexibleHub()
    ..addMethod('double', (args) => (args[0] as num) * 2)
    ..addMethod('reverse', (args) => (args[0] as String).split('').reversed.join())
    ..addMethod('factorial', (args) {
      final n = args[0] as int;
      return List.generate(n, (i) => i + 1).fold(1, (a, b) => a * b);
    })
    ..addProperty('status', 'ready')
    ..addProperty('count', 0);

  final env2 = LuaEnv.withStdlib(variables: {'flex': dynamicHub.toLuaObject()});

  final doubleFunc = FieldAccess(VarRef('flex'), 'double').evaluate(env: env2) as Function;
  final doubled = doubleFunc([21]);
  Call('print', [LuaString('Double 21:'), Number(doubled as num)]).evaluate(env: env2);

  final factorialFunc = FieldAccess(VarRef('flex'), 'factorial').evaluate(env: env2) as Function;
  final factorial = factorialFunc([5]);
  Call('print', [LuaString('5! ='), Number(factorial as num)]).evaluate(env: env2);

  print('Output:\n${env2.getOutput()}');

  // Example 3: Nested Hub (Categories/Modules)
  print('3. Nested Hub with Categories:');
  final apiHub = createNestedHub();
  final env3 = LuaEnv.withStdlib(variables: {'api': apiHub});

  // Access nested methods: api.math.sqrt(16)
  final mathCategory = FieldAccess(VarRef('api'), 'math').evaluate(env: env3) as LuaDartObject;
  final sqrtFunc = mathCategory.getProperty('sqrt') as Function;
  final sqrt = sqrtFunc([16]);
  Call('print', [LuaString('sqrt(16) ='), Number(sqrt as num)]).evaluate(env: env3);

  // Access string methods: api.string.upper("hello")
  final stringCategory = FieldAccess(VarRef('api'), 'string').evaluate(env: env3) as LuaDartObject;
  final upperFunc = stringCategory.getProperty('upper') as Function;
  final upper = upperFunc(['hello']);
  Call('print', [LuaString('upper("hello") ='), LuaString(upper as String)]).evaluate(env: env3);

  print('Output:\n${env3.getOutput()}');

  // Example 4: Plugin System Hub
  print('4. Plugin System Hub:');
  final pluginHub = PluginHub();

  // Register math plugin
  pluginHub.registerPlugin('math', {
    'square': (args) => math.pow(args[0] as num, 2),
    'cube': (args) => math.pow(args[0] as num, 3),
    'isPrime': (args) {
      final n = args[0] as int;
      if (n < 2) return false;
      for (int i = 2; i <= math.sqrt(n); i++) {
        if (n % i == 0) return false;
      }
      return true;
    }
  });

  // Register string plugin
  pluginHub.registerPlugin('string', {
    'palindrome': (args) {
      final str = (args[0] as String).toLowerCase();
      return str == str.split('').reversed.join();
    },
    'wordCount': (args) => (args[0] as String).split(' ').length,
    'capitalize': (args) => (args[0] as String).split(' ')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' '),
  });

  final env4 = LuaEnv.withStdlib(variables: {'plugins': pluginHub.toLuaObject()});

  final mathPlugin = FieldAccess(VarRef('plugins'), 'math').evaluate(env: env4) as LuaDartObject;
  final squareFunc = mathPlugin.getProperty('square') as Function;
  final squared = squareFunc([7]);
  Call('print', [LuaString('Square of 7:'), Number(squared as num)]).evaluate(env: env4);

  final stringPlugin = FieldAccess(VarRef('plugins'), 'string').evaluate(env: env4) as LuaDartObject;
  final palindromeFunc = stringPlugin.getProperty('palindrome') as Function;
  final isPalindrome = palindromeFunc(['racecar']);
  Call('print', [LuaString('"racecar" is palindrome:'), Bool(isPalindrome as bool)]).evaluate(env: env4);

  print('Output:\n${env4.getOutput()}');

  // Example 5: Stateful Hub (With Data Storage)
  print('5. Stateful Hub with Data Storage:');
  final stateHub = StateHub();
  final env5 = LuaEnv.withStdlib(variables: {'state': stateHub.toLuaObject()});

  // Store some data
  final storeFunc = FieldAccess(VarRef('state'), 'store').evaluate(env: env5) as Function;
  storeFunc(['user', 'Alice']);
  storeFunc(['score', 95]);

  // Retrieve data
  final retrieveFunc = FieldAccess(VarRef('state'), 'retrieve').evaluate(env: env5) as Function;
  final user = retrieveFunc(['user']);
  final score = retrieveFunc(['score']);
  Call('print', [LuaString('User:'), LuaString(user as String), LuaString('Score:'), Number(score as num)]).evaluate(env: env5);

  // Increment counter
  final incrementFunc = FieldAccess(VarRef('state'), 'increment').evaluate(env: env5) as Function;
  incrementFunc([]);
  incrementFunc([]);

  final counter = FieldAccess(VarRef('state'), 'counter').evaluate(env: env5);
  Call('print', [LuaString('Counter:'), Number(counter as num)]).evaluate(env: env5);

  print('Output:\n${env5.getOutput()}');

  print('=== Summary ===');
  print('These examples demonstrate different hub patterns:');
  print('1. Static Hub - Fixed methods defined at creation');
  print('2. Dynamic Hub - Methods added at runtime');
  print('3. Nested Hub - Organized into categories/modules');
  print('4. Plugin Hub - Extensible plugin system');
  print('5. Stateful Hub - Maintains data between calls');
  print('\nAll approaches provide flexible ways to expose Dart functionality to Lua!');
}

/// 1. Static Hub - Predefined methods
LuaDartObject createStaticHub() {
  return LuaDartObject(
    'StaticHub',
    methods: {
      'add': (args) => (args[0] as num) + (args[1] as num),
      'subtract': (args) => (args[0] as num) - (args[1] as num),
      'multiply': (args) => (args[0] as num) * (args[1] as num),
      'divide': (args) => (args[0] as num) / (args[1] as num),
      'greet': (args) => 'Hello, ${args.isNotEmpty ? args[0] : 'World'}!',
      'max': (args) => args.cast<num>().reduce((a, b) => a > b ? a : b),
      'min': (args) => args.cast<num>().reduce((a, b) => a < b ? a : b),
      'join': (args) => args.join(' '),
      'random': (args) => math.Random().nextInt((args.isNotEmpty ? args[0] : 100) as int),
    },
    getters: {
      'version': () => '1.0.0',
      'name': () => 'StaticHub',
      'methodCount': () => 9,
    },
  );
}

/// 2. Dynamic Hub - Methods can be added/removed at runtime
class FlexibleHub {
  final Map<String, Function> _methods = {};
  final Map<String, Object?> _properties = {};

  FlexibleHub addMethod(String name, Function method) {
    _methods[name] = method;
    return this;
  }

  FlexibleHub addProperty(String name, Object? value) {
    _properties[name] = value;
    return this;
  }

  FlexibleHub removeMethod(String name) {
    _methods.remove(name);
    return this;
  }

  FlexibleHub removeProperty(String name) {
    _properties.remove(name);
    return this;
  }

  List<String> getMethodNames() => _methods.keys.toList();
  List<String> getPropertyNames() => _properties.keys.toList();

  LuaDartObject toLuaObject() {
    final allMethods = Map<String, Function>.from(_methods);
    
    // Add introspection methods
    allMethods['listMethods'] = (args) => getMethodNames();
    allMethods['listProperties'] = (args) => getPropertyNames();
    allMethods['hasMethod'] = (args) => _methods.containsKey(args[0] as String);
    allMethods['hasProperty'] = (args) => _properties.containsKey(args[0] as String);

    return LuaDartObject(
      'FlexibleHub',
      methods: allMethods,
      getters: _properties.map((key, value) => MapEntry(key, () => value)),
      setters: _properties.keys.fold<Map<String, void Function(Object?)>>(
        {},
        (map, key) => {...map, key: (value) => _properties[key] = value},
      ),
    );
  }
}

/// 3. Nested Hub - Organized into categories
LuaDartObject createNestedHub() {
  // Math category
  final mathHub = LuaDartObject(
    'MathAPI',
    methods: {
      'sqrt': (args) => math.sqrt(args[0] as num),
      'pow': (args) => math.pow(args[0] as num, args[1] as num),
      'sin': (args) => math.sin(args[0] as num),
      'cos': (args) => math.cos(args[0] as num),
      'tan': (args) => math.tan(args[0] as num),
      'abs': (args) => (args[0] as num).abs(),
      'round': (args) => (args[0] as num).round(),
      'floor': (args) => (args[0] as num).floor(),
      'ceil': (args) => (args[0] as num).ceil(),
    },
    getters: {
      'pi': () => math.pi,
      'e': () => math.e,
    },
  );

  // String category
  final stringHub = LuaDartObject(
    'StringAPI',
    methods: {
      'upper': (args) => (args[0] as String).toUpperCase(),
      'lower': (args) => (args[0] as String).toLowerCase(),
      'reverse': (args) => (args[0] as String).split('').reversed.join(),
      'length': (args) => (args[0] as String).length,
      'contains': (args) => (args[0] as String).contains(args[1] as String),
      'startsWith': (args) => (args[0] as String).startsWith(args[1] as String),
      'endsWith': (args) => (args[0] as String).endsWith(args[1] as String),
      'split': (args) => (args[0] as String).split(args[1] as String),
      'trim': (args) => (args[0] as String).trim(),
    },
  );

  // Array category
  final arrayHub = LuaDartObject(
    'ArrayAPI',
    methods: {
      'length': (args) => (args[0] as List).length,
      'join': (args) => (args[0] as List).join(args.length > 1 ? args[1] as String : ','),
      'reverse': (args) => (args[0] as List).reversed.toList(),
      'sort': (args) {
        final list = List.from(args[0] as List);
        list.sort();
        return list;
      },
      'contains': (args) => (args[0] as List).contains(args[1]),
      'indexOf': (args) => (args[0] as List).indexOf(args[1]),
    },
  );

  return LuaDartObject(
    'APIHub',
    getters: {
      'math': () => mathHub,
      'string': () => stringHub,
      'array': () => arrayHub,
      'version': () => '2.0.0',
      'categories': () => ['math', 'string', 'array'],
    },
    methods: {
      'listCategories': (args) => ['math', 'string', 'array'],
      'getCategory': (args) {
        switch (args[0] as String) {
          case 'math': return mathHub;
          case 'string': return stringHub;
          case 'array': return arrayHub;
          default: return null;
        }
      },
    },
  );
}

/// 4. Plugin System Hub - Extensible plugin architecture
class PluginHub {
  final Map<String, LuaDartObject> _plugins = {};

  void registerPlugin(String name, Map<String, Function> methods, [Map<String, Object? Function()>? getters]) {
    _plugins[name] = LuaDartObject(
      name,
      methods: methods,
      getters: getters ?? {},
    );
  }

  void unregisterPlugin(String name) {
    _plugins.remove(name);
  }

  List<String> getPluginNames() => _plugins.keys.toList();

  bool hasPlugin(String name) => _plugins.containsKey(name);

  LuaDartObject? getPlugin(String name) => _plugins[name];

  LuaDartObject toLuaObject() {
    final getters = <String, Object? Function()>{};
    final methods = <String, Function>{};

    // Add each plugin as a property
    for (final entry in _plugins.entries) {
      getters[entry.key] = () => entry.value;
    }

    // Add management methods
    methods['listPlugins'] = (args) => getPluginNames();
    methods['hasPlugin'] = (args) => hasPlugin(args[0] as String);
    methods['getPluginMethods'] = (args) {
      final plugin = getPlugin(args[0] as String);
      return plugin?.methods.keys.toList() ?? [];
    };
    methods['pluginCount'] = (args) => _plugins.length;

    // Add metadata
    getters['version'] = () => '1.0.0';
    getters['pluginCount'] = () => _plugins.length;

    return LuaDartObject('PluginHub', methods: methods, getters: getters);
  }
}

/// 5. Stateful Hub - Maintains state between calls
class StateHub {
  final Map<String, Object?> _storage = {};
  int _counter = 0;
  final List<String> _history = [];

  LuaDartObject toLuaObject() {
    return LuaDartObject(
      'StateHub',
      methods: {
        // Storage methods
        'store': (args) {
          final key = args[0] as String;
          final value = args[1];
          _storage[key] = value;
          _history.add('STORE $key');
          return value;
        },
        'retrieve': (args) {
          final key = args[0] as String;
          final value = _storage[key];
          _history.add('RETRIEVE $key');
          return value;
        },
        'remove': (args) {
          final key = args[0] as String;
          final value = _storage.remove(key);
          _history.add('REMOVE $key');
          return value;
        },
        'clear': (args) {
          _storage.clear();
          _history.add('CLEAR_STORAGE');
          return null;
        },
        'keys': (args) => _storage.keys.toList(),
        'values': (args) => _storage.values.toList(),
        'has': (args) => _storage.containsKey(args[0] as String),
        
        // Counter methods
        'increment': (args) {
          _counter++;
          _history.add('INCREMENT');
          return _counter;
        },
        'decrement': (args) {
          _counter--;
          _history.add('DECREMENT');
          return _counter;
        },
        'setCounter': (args) {
          _counter = args[0] as int;
          _history.add('SET_COUNTER ${args[0]}');
          return _counter;
        },
        'resetCounter': (args) {
          _counter = 0;
          _history.add('RESET_COUNTER');
          return _counter;
        },
        
        // History methods
        'getHistory': (args) => _history,
        'clearHistory': (args) {
          _history.clear();
          return null;
        },
        'lastAction': (args) => _history.isNotEmpty ? _history.last : null,
      },
      getters: {
        'counter': () => _counter,
        'storageSize': () => _storage.length,
        'isEmpty': () => _storage.isEmpty,
        'isNotEmpty': () => _storage.isNotEmpty,
        'historyLength': () => _history.length,
      },
      setters: {
        'counter': (value) {
          _counter = value as int;
          _history.add('SET_COUNTER_DIRECT $value');
        },
      },
    );
  }
}