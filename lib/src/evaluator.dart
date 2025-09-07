import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:lua/src/ast.dart';

extension EvaluateExt on Ast {
  Object? evaluate({
    LuaEnv? env,
  }) {
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

  LuaEnv({
    this.variables,
    this.builtins,
    LuaOutputWriter? output,
  }) : output = output ?? LuaOutputBuffer();

  /// Create a LuaEnv with standard library functions
  factory LuaEnv.withStdlib({
    Map<String, Object?>? variables,
    LuaOutputWriter? output,
  }) {
    final env = LuaEnv(
      variables: variables,
      output: output ?? LuaOutputBuffer(),
    );
    return LuaEnv(
      variables: variables,
      builtins: _getStandardLibrary(env.output),
      output: env.output,
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

  _Context({
    required this.parent,
  })  : builtins = parent?.builtins ?? {},
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
    throw _ReturnException(
        (value.values ?? const []).map((e) => e.visit(this)).toList());
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
          'External object index must be a string, got: $key');
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
    return (value.left.visit(this) as Comparable)
            .compareTo(value.right.visit(this)) <
        0;
  }

  @override
  Object? visitLessEq(LessEq value) {
    return (value.left.visit(this) as Comparable)
            .compareTo(value.right.visit(this)) <=
        0;
  }

  @override
  Object? visitGreater(Greater value) {
    return (value.left.visit(this) as Comparable)
            .compareTo(value.right.visit(this)) >
        0;
  }

  @override
  Object? visitGreaterEq(GreaterEq value) {
    return (value.left.visit(this) as Comparable)
            .compareTo(value.right.visit(this)) >=
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
            (i, _) => i <= maxIndex ? value.values[i].visit(this) : null)
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
      }
      final expr = value.condition.visit(this);
      if (_isFalse(expr)) {
        return lastValue;
      }
    }
  }

  @override
  Object? visitLength(Length value) {
    final v = value.value.visit(this);
    if (v is TableInstance) {
      return v.fields.length;
    }
    throw UnimplementedError();
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
        }
      }
    } else {
      for (num i = initValue; i >= stopValue; i += incrementValue) {
        forked.vars[value.name] = i;
        try {
          lastValue = value.block.visit(forked);
        } on _BreakException {
          break;
        }
      }
    }

    return lastValue;
  }

  @override
  Object? visitForEach(ForEach value) {
    if (value.values.length != 1) {
      throw EvaluationException(
          'For-in loops currently support only single iterator expression');
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
          'For-in loop requires an iterator (use pairs() or ipairs())');
    }

    return null;
  }

  @override
  Object? visitFunctionDef(FunctionDef value) {
    final function = _LuaFunction(value.args, value.body, this);
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

  void _set(bool isLocal, String name, Object? value) {
    if (isLocal) {
      if (vars.containsKey(name)) {
        throw ArgumentError('Cannot override local scope "$name".');
      }
      vars[name] = value;
    } else {
      _Context? c = this;
      while (c != null) {
        if (c.vars.containsKey(name)) {
          c.vars[name] = value;
          return;
        }
        c = c.parent;
      }
      throw ArgumentError('Unknown reference "$name".');
    }
  }
}

bool _isFalse(Object? v) => v == null || v == false;

class TableInstance {
  final fields = <Object, Object?>{};

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

  _LuaFunction(this.parameters, this.body, this.closure);

  Object? call(List<Object?> args) {
    final functionContext = _Context(parent: closure);

    // Bind parameters
    for (int i = 0; i < parameters.length; i++) {
      functionContext.vars[parameters[i]] = i < args.length ? args[i] : null;
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
          'Property $name is not settable on $dartObject');
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

Map<String, LuaFunction> _getStandardLibrary(LuaOutputWriter output) {
  return {
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
