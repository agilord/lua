import 'package:lua/lua.dart';

void main() {
  parseEvalAndFormat('local x = 3 * 4 + 2');
  parseEvalAndFormat('local result = 10 + 5; print("Result:", result)');
}

void parseEvalAndFormat(String input) {
  print('\nOriginal Lua code:\n\n$input');

  try {
    final ast = parse(input);
    final formattedCode = format(ast);
    print('\nFormatted code:\n\n$formattedCode');

    // Execute the code
    final env = LuaEnv.withStdlib();
    final result = ast.evaluate(env: env);

    print('Return value: $result');
    final output = env.getOutput().trim();
    if (output.isNotEmpty) {
      print('Output: $output');
    }
  } catch (e) {
    print('Error: $e');
  }
}
