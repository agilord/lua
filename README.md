Lua language utilities (parser, evaluator, formatter) in Dart.

## Features

- **Parser**: Parse Lua source code into Abstract Syntax Tree (AST)
- **Evaluator**: Execute Lua code with support for variables, expressions, and control flow
- **Formatter**: Format Lua AST back to clean source code
- **Standard Library**: Built-in functions like print, type, tostring, tonumber, pairs, ipairs (limited support, more to come)
- **External Objects**: Integrate Dart objects and functions into Lua environment

## Supported Lua Constructs

- Variables and assignments (local and global)
- Arithmetic expressions (`+, -, *, /, %, ^`)
- Comparison operators (`<, >, <=, >=, ==, ~=`)
- Logical operators (`and, or, not`)
- String operations and concatenation
- Tables (basic support)
- Function calls
- Control flow (if/else, while, numeric for, for-in with pairs/ipairs)
- Function definitions and returns
