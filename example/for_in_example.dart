import 'package:lua/lua.dart';

void main() {
  print('=== For-In Loop Examples ===\n');

  // Example 1: pairs() iteration
  print('1. Pairs iteration:');
  final pairsCode =
      'local t = {name = "Lua", version = 5.4, type = "language"}; for k, v in pairs(t) do print(k, "=", v) end';
  demonstrateCode(pairsCode);

  print('\n${'=' * 50}\n');

  // Example 2: ipairs() iteration
  print('2. Ipairs iteration:');
  final ipairsCode =
      'local arr = {"apple", "banana", "cherry"}; for i, v in ipairs(arr) do print(i, v) end';
  demonstrateCode(ipairsCode);

  print('\n${'=' * 50}\n');

  // Example 3: Single variable iteration
  print('3. Single variable iteration:');
  final singleVarCode =
      'local colors = {red = 255, green = 128, blue = 64}; for color in pairs(colors) do print("Color:", color) end';
  demonstrateCode(singleVarCode);

  print('\n${'=' * 50}\n');

  // Example 4: Empty table
  print('4. Empty table iteration:');
  final emptyCode =
      'local empty = {}; print("Before loop"); for k, v in pairs(empty) do print("This should not print") end; print("After loop")';
  demonstrateCode(emptyCode);
}

void demonstrateCode(String luaCode) {
  print('Lua code: $luaCode\n');

  try {
    final ast = parse(luaCode);
    final formattedCode = format(ast);
    print('Formatted:\n$formattedCode\n');

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
