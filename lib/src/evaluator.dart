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

class LuaEnv {
  final Map<String, Object?>? variables;

  LuaEnv({
    this.variables,
  });
}

class _Context extends Visitor<Object?> {
  final _Context? parent;
  final vars = <String, Object?>{};

  _Context.fromEnv(LuaEnv env) : parent = null {
    vars.addAll(env.variables ?? const {});
  }

  _Context({
    required this.parent,
  });

  _Context _fork() {
    return _Context(parent: this);
  }

  Object? lookup(String name) {
    if (vars.containsKey(name)) {
      return vars[name];
    } else if (parent != null) {
      return parent!.lookup(name);
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
  Object? visitSubstract(Substract value) {
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
