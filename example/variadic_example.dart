import 'package:lua/lua.dart';

void main() {
  print('=== Variadic Function Examples ===\n');

  // Example 1: Simple variadic function
  print('1. Simple variadic function:');
  final simpleCode =
      'function greet(...) print("Hello to:", ...) end; greet("Alice", "Bob", "Charlie")';
  demonstrateCode(simpleCode);

  print('\n${'=' * 50}\n');

  // Example 2: Mixed parameters and variadic args
  print('2. Mixed parameters with variadic args:');
  final mixedCode =
      'function log(level, ...) print("[" .. level .. "]", ...) end; log("INFO", "User logged in")';
  demonstrateCode(mixedCode);

  print('\n${'=' * 50}\n');

  // Example 3: Forwarding variadic args
  print('3. Forwarding variadic arguments:');
  final forwardCode =
      'function inner(...) print("Inner:", ...) end; function outer(prefix, ...) print("Outer:", prefix); inner(...) end; outer("Starting", "arg1", "arg2")';
  demonstrateCode(forwardCode);

  print('\n${'=' * 50}\n');

  // Example 4: Returning variadic args
  print('4. Returning variadic arguments:');
  final returnCode =
      'function identity(...) return ... end; local result = identity("hello", "world"); print("Returned:", result)';
  demonstrateCode(returnCode);
}

void demonstrateCode(String luaCode) {
  print('Lua code:');
  print(luaCode.trim());
  print('');

  try {
    final ast = parse(luaCode);
    final env = LuaEnv.withStdlib();
    ast.evaluate(env: env);

    print('Output:');
    final output = env.getOutput().trim();
    if (output.isNotEmpty) {
      print(output);
    } else {
      print('(no output)');
    }
  } catch (e) {
    print('Error: $e');
  }
}
