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
    for (final s in value.statements) {
      if (s is Return) {
        return (s.values ?? const []).map((e) => e.visit(this)).toList();
      }
      s.visit(this);
    }
    return [];
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
      final key = f.$2.name ?? f.$2.index?.visit<Object?>(this) ?? f.$1;
      i._fields[key] = f.$2.value.visit(this);
    }
    return i;
  }

  @override
  Object? visitVarRef(VarRef value) => lookup(value.name);
}

class TableInstance {
  final _fields = <Object, Object?>{};

  TableInstance();
}

class EvaluationException implements Exception {
  final String message;

  EvaluationException(this.message);

  @override
  String toString() => 'EvaluationException: $message';
}
