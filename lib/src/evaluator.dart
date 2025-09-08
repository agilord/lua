import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:lua/src/ast.dart';

extension EvaluateExt on Ast {
  Object? evaluate({LuaEnv? env}) {
    final root = _Context.fromEnv(env ?? LuaEnv());
    return visit(root);
  }
}

typedef LuaFunction = Object? Function(List<Object?> args);

/// Interface for handling output from Lua programs
abstract class LuaOutputWriter {
  void write(String text);
  void writeLine(String text);
}

/// Default output writer that captures output in a buffer
class LuaOutputBuffer implements LuaOutputWriter {
  final StringBuffer _buffer = StringBuffer();
  final bool _alsoConsole;

  LuaOutputBuffer({bool alsoConsole = false}) : _alsoConsole = alsoConsole;

  @override
  void write(String text) {
    _buffer.write(text);
    if (_alsoConsole) {
      stdout.write(text);
    }
  }

  @override
  void writeLine(String text) {
    _buffer.writeln(text);
    if (_alsoConsole) {
      print(text);
    }
  }

  /// Get all captured output
  String get output => _buffer.toString();

  /// Get output lines as a list
  List<String> get lines =>
      output.split('\n')..removeLast(); // Remove empty last line

  /// Clear the output buffer
  void clear() => _buffer.clear();

  /// Check if buffer has any output
  bool get isEmpty => _buffer.isEmpty;
  bool get isNotEmpty => _buffer.isNotEmpty;
}

class LuaEnv {
  final Map<String, Object?>? variables;
  final Map<String, LuaFunction>? builtins;
  final LuaOutputWriter output;

  LuaEnv({this.variables, this.builtins, LuaOutputWriter? output})
    : output = output ?? LuaOutputBuffer();

  /// Create a LuaEnv with standard library functions
  factory LuaEnv.withStdlib({
    Map<String, Object?>? variables,
    LuaOutputWriter? output,
  }) {
    final envOutput = output ?? LuaOutputBuffer();
    final stdlibVars = <String, Object?>{};
    stdlibVars.addAll(variables ?? {});

    // Add math and string libraries as variables
    stdlibVars['math'] = _createMathLibrary();
    stdlibVars['string'] = _createStringLibrary();

    return LuaEnv(
      variables: stdlibVars,
      builtins: _getStandardLibrary(envOutput),
      output: envOutput,
    );
  }

  /// Get output as string (convenience method for LuaOutputBuffer)
  String getOutput() {
    if (output is LuaOutputBuffer) {
      return (output as LuaOutputBuffer).output;
    }
    return '';
  }

  /// Get output lines (convenience method for LuaOutputBuffer)
  List<String> getOutputLines() {
    if (output is LuaOutputBuffer) {
      return (output as LuaOutputBuffer).lines;
    }
    return [];
  }

  /// Clear output (convenience method for LuaOutputBuffer)
  void clearOutput() {
    if (output is LuaOutputBuffer) {
      (output as LuaOutputBuffer).clear();
    }
  }
}

class _Context extends Visitor<Object?> {
  final _Context? parent;
  final vars = <String, Object?>{};
  final Map<String, LuaFunction> builtins;
  final LuaOutputWriter output;

  _Context.fromEnv(LuaEnv env)
    : parent = null,
      builtins = env.builtins ?? {},
      output = env.output {
    vars.addAll(env.variables ?? const {});
  }

  _Context({required this.parent})
    : builtins = parent?.builtins ?? {},
      output = parent?.output ?? LuaOutputBuffer();

  _Context _fork() {
    return _Context(parent: this);
  }

  Object? lookup(String name) {
    if (vars.containsKey(name)) {
      return vars[name];
    } else if (parent != null) {
      return parent!.lookup(name);
    } else if (builtins.containsKey(name)) {
      return builtins[name];
    } else {
      throw EvaluationException('reference to unknown key: $name');
    }
  }

  @override
  Object? visitBlock(Block value) {
    Object? lastValue;
    for (final s in value.statements) {
      try {
        lastValue = s.visit(this);
      } on _ReturnException catch (e) {
        return e.value;
      }
    }
    return lastValue;
  }

  @override
  Object? visitReturn(Return value) {
    if (value.values == null || value.values!.isEmpty) {
      throw _ReturnException(null);
    }

    final flattenedValues = <Object?>[];
    bool hasVariadicArgs = false;

    for (final expr in value.values!) {
      final result = expr.visit(this);
      if (expr is VariadicArgs) {
        hasVariadicArgs = true;
        if (result is List) {
          // Flatten variadic arguments
          flattenedValues.addAll(result);
        }
      } else {
        flattenedValues.add(result);
      }
    }

    // If variadic arguments are involved, always return a list
    if (hasVariadicArgs || flattenedValues.length > 1) {
      throw _ReturnException(flattenedValues);
    } else {
      throw _ReturnException(flattenedValues.single);
    }
  }

  @override
  Object? visitBreak(Break value) {
    throw _BreakException();
  }

  @override
  Object? visitNil(Nil value) => null;

  @override
  Object? visitBool(Bool value) => value.value;

  @override
  Object? visitNumber(Number value) => value.value;

  @override
  Object? visitString(LuaString value) => value.value;

  @override
  Object? visitTable(Table value) {
    final i = TableInstance();
    for (final f in value.fields.indexed) {
      final key = f.$2.name ?? f.$2.index?.visit<Object?>(this) ?? (f.$1 + 1);
      i.fields[key] = f.$2.value.visit(this);
    }
    return i;
  }

  @override
  Object? visitIndex(Index value) {
    final table = value.table.visit(this);
    if (table is TableInstance) {
      final key = value.key.visit(this);
      return table.fields[key];
    } else if (table is LuaExternalObject) {
      final key = value.key.visit(this);
      if (key is String) {
        return table.getProperty(key);
      }
      throw EvaluationException(
        'External object index must be a string, got: $key',
      );
    }
    throw EvaluationException('Cannot index non-table value: $table');
  }

  @override
  Object? visitFieldAccess(FieldAccess value) {
    final table = value.table.visit(this);
    if (table is TableInstance) {
      return table.fields[value.field];
    } else if (table is LuaExternalObject) {
      return table.getProperty(value.field);
    }
    throw EvaluationException('Cannot access field on non-table value: $table');
  }

  @override
  bool visitAnd(And value) {
    for (final i in value.items) {
      final v = i.visit(this);
      if (_isFalse(v)) {
        return false;
      }
    }
    return true;
  }

  @override
  bool visitOr(Or value) {
    for (final i in value.items) {
      final v = i.visit(this);
      if (!_isFalse(v)) {
        return true;
      }
    }
    return false;
  }

  @override
  bool visitNot(Not value) {
    final v = value.value.visit(this);
    return _isFalse(v);
  }

  @override
  Object? visitVarRef(VarRef value) => lookup(value.name);

  @override
  List<Object?> visitVariadicArgs(VariadicArgs value) {
    final variadicArgs = vars['...'];
    if (variadicArgs is List<Object?>) {
      return variadicArgs;
    }
    throw EvaluationException(
      'Variadic arguments (...) can only be used inside variadic functions',
    );
  }

  @override
  Object? visitNegative(Negative value) {
    final v = value.value.visit(this);
    return -(v as num);
  }

  @override
  Object? visitEquals(Equals value) {
    return value.left.visit(this) == value.right.visit(this);
  }

  @override
  Object? visitNotEquals(NotEquals value) {
    return value.left.visit(this) != value.right.visit(this);
  }

  @override
  Object? visitLess(Less value) {
    return (value.left.visit(this) as Comparable).compareTo(
          value.right.visit(this),
        ) <
        0;
  }

  @override
  Object? visitLessEq(LessEq value) {
    return (value.left.visit(this) as Comparable).compareTo(
          value.right.visit(this),
        ) <=
        0;
  }

  @override
  Object? visitGreater(Greater value) {
    return (value.left.visit(this) as Comparable).compareTo(
          value.right.visit(this),
        ) >
        0;
  }

  @override
  Object? visitGreaterEq(GreaterEq value) {
    return (value.left.visit(this) as Comparable).compareTo(
          value.right.visit(this),
        ) >=
        0;
  }

  @override
  Object? visitConcatenate(Concatenate value) {
    return value.values.map((e) => e.visit(this)).join('');
  }

  @override
  Object? visitAdd(Add value) {
    return value.values
        .map((e) => e.visit(this) as num)
        .reduce((sum, e) => sum + e);
  }

  @override
  Object? visitSubtract(Subtract value) {
    return (value.left.visit(this) as num) - (value.right.visit(this) as num);
  }

  @override
  Object? visitMultiply(Multiply value) {
    return value.values
        .map((e) => e.visit(this) as num)
        .reduce((prod, e) => prod * e);
  }

  @override
  Object? visitDivide(Divide value) {
    return (value.left.visit(this) as num) / (value.right.visit(this) as num);
  }

  @override
  Object? visitModulo(Modulo value) {
    return (value.left.visit(this) as num) % (value.right.visit(this) as num);
  }

  @override
  Object? visitExponent(Exponent value) {
    return pow(value.left.visit(this) as num, value.right.visit(this) as num);
  }

  @override
  Object? visitDo(Do value) {
    return value.block.visit(_fork());
  }

  @override
  Object? visitAssign(Assign value) {
    final maxIndex = value.values.length - 1;
    final values = value.names
        .mapIndexed(
          (i, _) => i <= maxIndex ? value.values[i].visit(this) : null,
        )
        .toList();
    for (int i = 0; i < value.names.length; i++) {
      final v = values[i];
      _set(value.isLocal, value.names[i], v);
    }
    return values.length == 1 ? values.single : values;
  }

  @override
  Object? visitCall(Call value) {
    final function = lookup(value.name);
    if (function is _LuaFunction) {
      final args = value.args.map((e) => e.visit(this)).toList();
      final result = function.call(args);
      // When used in expression context, unwrap single-element lists
      if (result is List && result.length == 1) {
        return result.first;
      }
      return result;
    } else if (function is LuaFunction) {
      final args = value.args.map((e) => e.visit(this)).toList();
      return function(args);
    } else if (function is LuaExternalObject) {
      final args = value.args.map((e) => e.visit(this)).toList();
      return function.call(args);
    }
    throw EvaluationException('Function "${value.name}" is not implemented');
  }

  @override
  Object? visitCallFieldAccess(CallFieldAccess value) {
    // Evaluate the field access to get the function
    final function = value.fieldAccess.visit(this);
    if (function is LuaFunction) {
      final args = value.args.map((e) => e.visit(this)).toList();
      return function(args);
    } else if (function is _LuaFunction) {
      final args = value.args.map((e) => e.visit(this)).toList();
      final result = function.call(args);
      // When used in expression context, unwrap single-element lists
      if (result is List && result.length == 1) {
        return result.first;
      }
      return result;
    } else if (function is LuaExternalObject) {
      final args = value.args.map((e) => e.visit(this)).toList();
      return function.call(args);
    }
    throw EvaluationException('Cannot call field access result: $function');
  }

  @override
  Object? visitCallExpression(CallExpression value) {
    // Evaluate the function expression to get the function
    final function = value.function.visit(this);
    if (function is LuaFunction) {
      final args = value.args.map((e) => e.visit(this)).toList();
      return function(args);
    } else if (function is _LuaFunction) {
      final args = value.args.map((e) => e.visit(this)).toList();
      final result = function.call(args);
      // When used in expression context, unwrap single-element lists
      if (result is List && result.length == 1) {
        return result.first;
      }
      return result;
    } else if (function is LuaExternalObject) {
      final args = value.args.map((e) => e.visit(this)).toList();
      return function.call(args);
    }
    throw EvaluationException('Cannot call expression result: $function');
  }

  @override
  Object? visitWhile(While value) {
    Object? lastValue;
    for (;;) {
      final expr = value.condition.visit(this);
      if (_isFalse(expr)) {
        return lastValue;
      }
      try {
        lastValue = value.block.visit(_fork());
      } on _BreakException {
        return lastValue;
      } on _ReturnException {
        rethrow;
      }
    }
  }

  @override
  Object? visitRepeat(Repeat value) {
    Object? lastValue;
    for (;;) {
      try {
        lastValue = value.block.visit(_fork());
      } on _BreakException {
        return lastValue;
      } on _ReturnException {
        rethrow;
      }
      final expr = value.condition.visit(this);
      if (!_isFalse(expr)) {
        return lastValue;
      }
    }
  }

  @override
  Object? visitLength(Length value) {
    final v = value.value.visit(this);
    if (v is TableInstance) {
      return v.fields.length;
    } else if (v is String) {
      return v.length;
    }
    throw EvaluationException('attempt to get length of a ${v.runtimeType}');
  }

  @override
  Object? visitIf(If value) {
    final condition = value.condition.visit(this);
    if (!_isFalse(condition)) {
      final result = value.block.visit(_fork());
      if (result is List && result.length == 1) {
        return result.first;
      }
      return result;
    }

    if (value.elseIfs != null) {
      for (final elseIf in value.elseIfs!) {
        final elseIfCondition = elseIf.condition.visit(this);
        if (!_isFalse(elseIfCondition)) {
          final result = elseIf.block.visit(_fork());
          if (result is List && result.length == 1) {
            return result.first;
          }
          return result;
        }
      }
    }

    if (value.elseBlock != null) {
      final result = value.elseBlock!.visit(_fork());
      if (result is List && result.length == 1) {
        return result.first;
      }
      return result;
    }

    return null;
  }

  @override
  Object? visitFor(For value) {
    final initValue = value.init.visit(this) as num;
    final stopValue = value.stop.visit(this) as num;
    final incrementValue = value.increment?.visit(this) as num? ?? 1;

    Object? lastValue;
    final forked = _fork();

    if (incrementValue > 0) {
      for (num i = initValue; i <= stopValue; i += incrementValue) {
        forked.vars[value.name] = i;
        try {
          lastValue = value.block.visit(forked);
        } on _BreakException {
          break;
        } on _ReturnException {
          rethrow;
        }
      }
    } else {
      for (num i = initValue; i >= stopValue; i += incrementValue) {
        forked.vars[value.name] = i;
        try {
          lastValue = value.block.visit(forked);
        } on _BreakException {
          break;
        } on _ReturnException {
          rethrow;
        }
      }
    }

    return lastValue;
  }

  @override
  Object? visitForEach(ForEach value) {
    if (value.values.length != 1) {
      throw EvaluationException(
        'For-in loops currently support only single iterator expression',
      );
    }

    final iterator = value.values.first.visit(this);

    if (iterator is _LuaPairsIterator) {
      // Handle pairs iterator
      final context = _fork();
      try {
        while (true) {
          final result = iterator.next();
          if (result.length == 1 && result[0] == null) {
            break; // End of iteration
          }

          // Assign iterator values to loop variables
          for (int i = 0; i < value.names.length && i < result.length; i++) {
            context.vars[value.names[i]] = result[i];
          }

          // Execute loop body
          try {
            value.block.visit(context);
          } on _BreakException {
            break;
          } on _ReturnException {
            rethrow;
          }
        }
      } catch (e) {
        if (e is _BreakException || e is _ReturnException) rethrow;
        rethrow;
      }
    } else if (iterator is _LuaIpairsIterator) {
      // Handle ipairs iterator
      final context = _fork();
      try {
        while (true) {
          final result = iterator.next();
          if (result.length == 1 && result[0] == null) {
            break; // End of iteration
          }

          // Assign iterator values to loop variables
          for (int i = 0; i < value.names.length && i < result.length; i++) {
            context.vars[value.names[i]] = result[i];
          }

          // Execute loop body
          try {
            value.block.visit(context);
          } on _BreakException {
            break;
          } on _ReturnException {
            rethrow;
          }
        }
      } catch (e) {
        if (e is _BreakException || e is _ReturnException) rethrow;
        rethrow;
      }
    } else {
      throw EvaluationException(
        'For-in loop requires an iterator (use pairs() or ipairs())',
      );
    }

    return null;
  }

  @override
  Object? visitFunctionDef(FunctionDef value) {
    final function = _LuaFunction(
      value.args,
      value.body,
      this,
      hasVariadicArgs: value.hasVariadicArgs,
    );
    if (value.isLocal) {
      vars[value.name] = function;
    } else {
      _Context? c = this;
      while (c?.parent != null) {
        c = c!.parent;
      }
      c!.vars[value.name] = function;
    }
    return function;
  }

  @override
  Object? visitInlineFunction(InlineFunction value) {
    return _LuaFunction(value.args, value.body, this);
  }

  @override
  Object? visitSingleLineComment(SingleLineComment value) {
    return null;
  }

  @override
  Object? visitMultiLineComment(MultiLineComment value) {
    return null;
  }

  void _set(bool isLocal, String name, Object? value) {
    if (isLocal) {
      if (vars.containsKey(name)) {
        throw ArgumentError('Cannot override local scope "$name".');
      }
      vars[name] = value;
    } else {
      // For non-local assignment, try to find existing variable in scope chain
      _Context? c = this;
      while (c != null) {
        if (c.vars.containsKey(name)) {
          c.vars[name] = value;
          return;
        }
        c = c.parent;
      }
      // If variable doesn't exist anywhere, create it as global (in root scope)
      _Context root = this;
      while (root.parent != null) {
        root = root.parent!;
      }
      root.vars[name] = value;
    }
  }
}

bool _isFalse(Object? v) => v == null || v == false;

class TableInstance {
  final fields = <Object, Object?>{};
  TableInstance? metatable;

  TableInstance();

  TableInstance.fromList(Iterable values) {
    values.forEachIndexed((index, element) {
      fields[index + 1] = element;
    });
  }

  TableInstance.fromMap(Map values) {
    values.forEach((key, value) {
      fields[key] = value;
    });
  }

  @override
  int get hashCode =>
      Object.hashAllUnordered(fields.entries.expand((e) => [e.key, e.value]));

  @override
  bool operator ==(Object other) {
    if (other is! TableInstance) {
      return false;
    }
    for (final e in fields.entries) {
      final ov = other.fields[e.key];
      if (e.value == null) {
        if (ov == null) {
          continue;
        } else {
          return false;
        }
      }
      if (e.value != ov) {
        return false;
      }
    }

    for (final e in other.fields.entries) {
      if (fields.containsKey(e.key)) {
        continue;
      }
      if (e.value != null) {
        return false;
      }
    }

    return true;
  }

  @override
  String toString() => fields.toString();
}

class EvaluationException implements Exception {
  final String message;

  EvaluationException(this.message);

  @override
  String toString() => 'EvaluationException: $message';
}

class _ReturnException implements Exception {
  final Object? value;

  _ReturnException(this.value);
}

class _BreakException implements Exception {}

class _LuaFunction {
  final List<String> parameters;
  final Block body;
  final _Context closure;
  final bool hasVariadicArgs;

  _LuaFunction(
    this.parameters,
    this.body,
    this.closure, {
    this.hasVariadicArgs = false,
  });

  Object? call(List<Object?> args) {
    final functionContext = _Context(parent: closure);

    // Bind regular parameters
    for (int i = 0; i < parameters.length; i++) {
      functionContext.vars[parameters[i]] = i < args.length ? args[i] : null;
    }

    // Handle variadic arguments
    if (hasVariadicArgs) {
      // Collect extra arguments into a list
      final variadicArgs = <Object?>[];
      for (int i = parameters.length; i < args.length; i++) {
        variadicArgs.add(args[i]);
      }
      // Store variadic arguments in a special variable
      functionContext.vars['...'] = variadicArgs;
    }

    try {
      return body.visit(functionContext);
    } on _ReturnException catch (e) {
      return e.value;
    }
  }
}

/// Base class for external objects that can be called from Lua
abstract class LuaExternalObject {
  Object? call(List<Object?> args);
  Object? getProperty(String name);
  void setProperty(String name, Object? value);
}

/// Implementation of a Dart object wrapper for Lua
class LuaDartObject extends LuaExternalObject {
  final Object dartObject;
  final Map<String, Function> methods;
  final Map<String, Object? Function()> getters;
  final Map<String, void Function(Object?)> setters;

  LuaDartObject(
    this.dartObject, {
    this.methods = const {},
    this.getters = const {},
    this.setters = const {},
  });

  @override
  Object? call(List<Object?> args) {
    if (dartObject is Function) {
      // For functions that expect a List<Object?> as single parameter
      final func = dartObject as Function;
      if (func is Object? Function(List<Object?>)) {
        return func(args);
      }
      // For functions that expect individual parameters
      return Function.apply(func, args);
    }
    throw EvaluationException('Object $dartObject is not callable');
  }

  @override
  Object? getProperty(String name) {
    if (methods.containsKey(name)) {
      return methods[name];
    }
    if (getters.containsKey(name)) {
      return getters[name]!();
    }
    throw EvaluationException('Property $name not found on $dartObject');
  }

  @override
  void setProperty(String name, Object? value) {
    if (setters.containsKey(name)) {
      setters[name]!(value);
    } else {
      throw EvaluationException(
        'Property $name is not settable on $dartObject',
      );
    }
  }
}

/// Standard library functions for Lua
/// Iterator for pairs() function - iterates over all key-value pairs in a table
class _LuaPairsIterator {
  final TableInstance table;
  int _index = 0;

  _LuaPairsIterator(this.table);

  List<Object?> next() {
    final entries = table.fields.entries.toList();
    if (_index >= entries.length) {
      return [null]; // End of iteration
    }
    final entry = entries[_index++];
    return [entry.key, entry.value];
  }
}

/// Iterator for ipairs() function - iterates over numeric indices only
class _LuaIpairsIterator {
  final TableInstance table;
  int _index = 1; // Lua arrays start at 1

  _LuaIpairsIterator(this.table);

  List<Object?> next() {
    final value = table.fields[_index];
    if (value == null) {
      return [null]; // End of iteration
    }
    return [_index++, value];
  }
}

// Helper function for next() implementation
List<Object?> _nextTableEntry(TableInstance table, Object? currentKey) {
  final entries = table.fields.entries.toList();

  if (currentKey == null) {
    // Return first entry if available
    if (entries.isNotEmpty) {
      final first = entries.first;
      return [first.key, first.value];
    }
    return [null];
  }

  // Find current key and return next entry
  for (int i = 0; i < entries.length; i++) {
    if (entries[i].key == currentKey) {
      if (i + 1 < entries.length) {
        final next = entries[i + 1];
        return [next.key, next.value];
      }
      break;
    }
  }

  return [null]; // End of iteration or key not found
}

// Create math library table
TableInstance _createMathLibrary() {
  final mathTable = TableInstance();
  mathTable.fields.addAll({
    // Constants
    'pi': pi,
    'huge': double.infinity,

    // Basic arithmetic functions
    'abs': (List<Object?> args) {
      if (args.isEmpty) return 0;
      final value = args.first;
      if (value is num) return value.abs();
      throw EvaluationException('math.abs requires a number');
    },
    'ceil': (List<Object?> args) {
      if (args.isEmpty) return 0;
      final value = args.first;
      if (value is num) return value.ceil();
      throw EvaluationException('math.ceil requires a number');
    },
    'floor': (List<Object?> args) {
      if (args.isEmpty) return 0;
      final value = args.first;
      if (value is num) return value.floor();
      throw EvaluationException('math.floor requires a number');
    },
    'max': (List<Object?> args) {
      if (args.isEmpty) return double.negativeInfinity;
      num maxVal = double.negativeInfinity;
      for (final arg in args) {
        if (arg is num) {
          if (arg > maxVal) maxVal = arg;
        } else {
          throw EvaluationException('math.max requires numbers');
        }
      }
      return maxVal;
    },
    'min': (List<Object?> args) {
      if (args.isEmpty) return double.infinity;
      num minVal = double.infinity;
      for (final arg in args) {
        if (arg is num) {
          if (arg < minVal) minVal = arg;
        } else {
          throw EvaluationException('math.min requires numbers');
        }
      }
      return minVal;
    },

    // Power and logarithm functions
    'pow': (List<Object?> args) {
      if (args.length < 2) return 1;
      final base = args[0];
      final exponent = args[1];
      if (base is num && exponent is num) {
        return pow(base, exponent);
      }
      throw EvaluationException('math.pow requires two numbers');
    },
    'sqrt': (List<Object?> args) {
      if (args.isEmpty) return 0;
      final value = args.first;
      if (value is num) return sqrt(value);
      throw EvaluationException('math.sqrt requires a number');
    },
    'log': (List<Object?> args) {
      if (args.isEmpty) return double.nan;
      final value = args.first;
      if (value is num) {
        if (args.length > 1) {
          final base = args[1];
          if (base is num) {
            return log(value) / log(base);
          }
        }
        return log(value);
      }
      throw EvaluationException('math.log requires a number');
    },
    'exp': (List<Object?> args) {
      if (args.isEmpty) return 1;
      final value = args.first;
      if (value is num) return exp(value);
      throw EvaluationException('math.exp requires a number');
    },

    // Trigonometric functions
    'sin': (List<Object?> args) {
      if (args.isEmpty) return 0;
      final value = args.first;
      if (value is num) return sin(value);
      throw EvaluationException('math.sin requires a number');
    },
    'cos': (List<Object?> args) {
      if (args.isEmpty) return 1;
      final value = args.first;
      if (value is num) return cos(value);
      throw EvaluationException('math.cos requires a number');
    },
    'tan': (List<Object?> args) {
      if (args.isEmpty) return 0;
      final value = args.first;
      if (value is num) return tan(value);
      throw EvaluationException('math.tan requires a number');
    },
    'asin': (List<Object?> args) {
      if (args.isEmpty) return 0;
      final value = args.first;
      if (value is num) return asin(value);
      throw EvaluationException('math.asin requires a number');
    },
    'acos': (List<Object?> args) {
      if (args.isEmpty) return pi / 2;
      final value = args.first;
      if (value is num) return acos(value);
      throw EvaluationException('math.acos requires a number');
    },
    'atan': (List<Object?> args) {
      if (args.isEmpty) return 0;
      final value = args.first;
      if (value is num) return atan(value);
      throw EvaluationException('math.atan requires a number');
    },
    'atan2': (List<Object?> args) {
      if (args.length < 2) return 0;
      final y = args[0];
      final x = args[1];
      if (y is num && x is num) return atan2(y, x);
      throw EvaluationException('math.atan2 requires two numbers');
    },

    // Rounding functions
    'fmod': (List<Object?> args) {
      if (args.length < 2) return 0;
      final x = args[0];
      final y = args[1];
      if (x is num && y is num) return x % y;
      throw EvaluationException('math.fmod requires two numbers');
    },
    'modf': (List<Object?> args) {
      if (args.isEmpty) return [0, 0];
      final value = args.first;
      if (value is num) {
        final intPart = value.truncate();
        final fracPart = value - intPart;
        return [intPart, fracPart];
      }
      throw EvaluationException('math.modf requires a number');
    },

    // Random functions
    'random': (List<Object?> args) {
      final random = Random();
      if (args.isEmpty) {
        return random.nextDouble();
      } else if (args.length == 1) {
        final max = args[0];
        if (max is int && max > 0) {
          return random.nextInt(max) + 1; // Lua random(n) returns 1 to n
        }
      } else if (args.length >= 2) {
        final min = args[0];
        final max = args[1];
        if (min is int && max is int && min <= max) {
          return random.nextInt(max - min + 1) + min;
        }
      }
      throw EvaluationException('math.random requires valid integer arguments');
    },
    'randomseed': (List<Object?> args) {
      // Note: Dart's Random doesn't support setting seed after creation
      // This is a simplified implementation
      return null;
    },
  });
  return mathTable;
}

// Create string library table
TableInstance _createStringLibrary() {
  final stringTable = TableInstance();
  stringTable.fields.addAll({
    'len': (List<Object?> args) {
      if (args.isEmpty) return 0;
      final value = args.first;
      if (value is String) return value.length;
      throw EvaluationException('string.len requires a string');
    },
    'upper': (List<Object?> args) {
      if (args.isEmpty) return '';
      final value = args.first;
      if (value is String) return value.toUpperCase();
      throw EvaluationException('string.upper requires a string');
    },
    'lower': (List<Object?> args) {
      if (args.isEmpty) return '';
      final value = args.first;
      if (value is String) return value.toLowerCase();
      throw EvaluationException('string.lower requires a string');
    },
    'sub': (List<Object?> args) {
      if (args.isEmpty) return '';
      final str = args[0];
      if (str is! String) {
        throw EvaluationException('string.sub requires a string');
      }

      int start = 1;
      int end = str.length;

      if (args.length > 1 && args[1] is int) {
        start = args[1] as int;
      }
      if (args.length > 2 && args[2] is int) {
        end = args[2] as int;
      }

      // Convert to 0-based indexing (Lua uses 1-based)
      start = (start > 0) ? start - 1 : str.length + start;
      end = (end > 0) ? end : str.length + end + 1;

      start = start.clamp(0, str.length);
      end = end.clamp(0, str.length);

      if (start > end) return '';
      return str.substring(start, end);
    },
    'find': (List<Object?> args) {
      if (args.length < 2) return null;
      final str = args[0];
      final pattern = args[1];
      if (str is! String || pattern is! String) {
        throw EvaluationException('string.find requires two strings');
      }

      int startPos = 0;
      if (args.length > 2 && args[2] is int) {
        startPos = (args[2] as int) - 1; // Convert to 0-based
        startPos = startPos.clamp(0, str.length);
      }

      final index = str.indexOf(pattern, startPos);
      if (index == -1) return null;
      return [index + 1, index + pattern.length]; // Convert back to 1-based
    },
    'rep': (List<Object?> args) {
      if (args.length < 2) return '';
      final str = args[0];
      final count = args[1];
      if (str is! String || count is! int) {
        throw EvaluationException('string.rep requires a string and number');
      }
      if (count < 0) return '';
      return str * count;
    },
    'reverse': (List<Object?> args) {
      if (args.isEmpty) return '';
      final value = args.first;
      if (value is String) {
        return value.split('').reversed.join();
      }
      throw EvaluationException('string.reverse requires a string');
    },
    'char': (List<Object?> args) {
      final result = StringBuffer();
      for (final arg in args) {
        if (arg is int && arg >= 0 && arg <= 255) {
          result.writeCharCode(arg);
        } else {
          throw EvaluationException(
            'string.char requires valid character codes',
          );
        }
      }
      return result.toString();
    },
    'byte': (List<Object?> args) {
      if (args.isEmpty) return null;
      final str = args[0];
      if (str is! String) {
        throw EvaluationException('string.byte requires a string');
      }

      int pos = 1;
      if (args.length > 1 && args[1] is int) {
        pos = args[1] as int;
      }

      // Convert to 0-based indexing
      pos = pos - 1;
      if (pos < 0 || pos >= str.length) return null;

      return str.codeUnitAt(pos);
    },
    'format': (List<Object?> args) {
      // Simplified format implementation - just basic %s, %d, %f support
      if (args.isEmpty) return '';
      final format = args[0];
      if (format is! String) {
        throw EvaluationException('string.format requires a format string');
      }

      String result = format;
      int argIndex = 1;

      result = result.replaceAllMapped(RegExp('%[sdqfg]'), (match) {
        if (argIndex < args.length) {
          final arg = args[argIndex++];
          switch (match.group(0)) {
            case '%s':
              return _luaToString(arg);
            case '%d':
              if (arg is num) return arg.toInt().toString();
              return '0';
            case '%f':
            case '%g':
              if (arg is num) return arg.toString();
              return '0';
            case '%q':
              if (arg is String) return '"${arg.replaceAll('"', r'\"')}"';
              return _luaToString(arg);
          }
        }
        return match.group(0) ?? '';
      });

      return result.replaceAll('%%', '%');
    },
  });
  return stringTable;
}

Map<String, LuaFunction> _getStandardLibrary(LuaOutputWriter output) {
  return {
    // Basic functions
    'print': (args) {
      final text = args.map(_luaToString).join('\t');
      output.writeLine(text);
      return null;
    },
    'type': (args) {
      if (args.isEmpty) return 'nil';
      final value = args.first;
      if (value == null) return 'nil';
      if (value is bool) return 'boolean';
      if (value is num) return 'number';
      if (value is String) return 'string';
      if (value is TableInstance) return 'table';
      if (value is _LuaFunction || value is LuaFunction) return 'function';
      return 'userdata';
    },
    'tostring': (args) {
      if (args.isEmpty) return 'nil';
      return _luaToString(args.first);
    },
    'tonumber': (args) {
      if (args.isEmpty) return null;
      final value = args.first;
      if (value is num) return value;
      if (value is String) {
        final parsed = num.tryParse(value);
        return parsed;
      }
      return null;
    },

    // Table iteration functions
    'pairs': (args) {
      if (args.isEmpty) return null;
      final value = args.first;
      if (value is! TableInstance) {
        throw EvaluationException('pairs() requires a table');
      }
      return _LuaPairsIterator(value);
    },
    'ipairs': (args) {
      if (args.isEmpty) return null;
      final value = args.first;
      if (value is! TableInstance) {
        throw EvaluationException('ipairs() requires a table');
      }
      return _LuaIpairsIterator(value);
    },
    'next': (args) {
      if (args.isEmpty) return null;
      final table = args.first;
      if (table is! TableInstance) {
        throw EvaluationException('next() requires a table');
      }
      final key = args.length > 1 ? args[1] : null;
      return _nextTableEntry(table, key);
    },

    // Raw table access functions
    'rawget': (args) {
      if (args.length < 2) return null;
      final table = args[0];
      final key = args[1];
      if (table is! TableInstance) {
        throw EvaluationException('rawget() requires a table');
      }
      return table.fields[key];
    },
    'rawset': (args) {
      if (args.length < 3) return args.isNotEmpty ? args[0] : null;
      final table = args[0];
      final key = args[1];
      final value = args[2];
      if (table is! TableInstance) {
        throw EvaluationException('rawset() requires a table');
      }
      if (key != null) {
        table.fields[key] = value;
      }
      return table;
    },

    // Metatable functions
    'getmetatable': (args) {
      if (args.isEmpty) return null;
      final value = args.first;
      if (value is TableInstance) {
        return value.metatable;
      }
      return null;
    },
    'setmetatable': (args) {
      if (args.length < 2) return args.isNotEmpty ? args[0] : null;
      final table = args[0];
      final metatable = args[1];
      if (table is! TableInstance) {
        throw EvaluationException('setmetatable() requires a table');
      }
      if (metatable != null && metatable is! TableInstance) {
        throw EvaluationException('metatable must be a table or nil');
      }
      table.metatable = metatable as TableInstance?;
      return table;
    },
  };
}

String _luaToString(Object? value) {
  if (value == null) return 'nil';
  if (value is bool) return value.toString();
  if (value is num) {
    if (value is int) return value.toString();
    if (value == value.toInt()) return value.toInt().toString();
    return value.toString();
  }
  if (value is String) return value;
  if (value is TableInstance) {
    return 'table: ${value.hashCode.toRadixString(16)}';
  }
  if (value is _LuaFunction || value is LuaFunction) {
    return 'function: ${value.hashCode.toRadixString(16)}';
  }
  if (value is LuaDartObject) return value.dartObject.toString();
  return value.toString();
}
