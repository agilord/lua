import 'package:collection/collection.dart';

abstract class Visitor<T> {
  T visitAst(Ast value) =>
      throw UnimplementedError('${value.runtimeType} is not implemented');
  T visitStatement(Statement value) => visitAst(value);
  T visitExpression(Expression value) => visitStatement(value);
  T visitBlock(Block value) => visitAst(value);
  T visitVarRef(VarRef value) => visitExpression(value);
  T visitNil(Nil value) => visitExpression(value);
  T visitBool(Bool value) => visitExpression(value);
  T visitNumber(Number value) => visitExpression(value);
  T visitString(LuaString value) => visitExpression(value);
  T visitTable(Table value) => visitExpression(value);
}

abstract class Ast {
  const Ast();

  T visit<T>(Visitor<T> visitor) => visitor.visitAst(this);
}

abstract class Statement extends Ast {
  const Statement();

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitStatement(this);
}

abstract class Expression extends Statement {
  const Expression();
  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitExpression(this);
}

class Block extends Ast {
  final List<Statement> statements;

  Block(this.statements);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitBlock(this);

  @override
  late final int hashCode = Object.hashAll(statements);

  @override
  bool operator ==(Object other) {
    return other is Block &&
        statements.length == other.statements.length &&
        statements.whereIndexed((i, e) => e == other.statements[i]).length ==
            statements.length;
  }
}

class Assign extends Statement {
  final bool isLocal;
  final List<String> names;
  final List<Expression> values;

  Assign(
    this.names,
    this.values, {
    this.isLocal = false,
  });
}

class Call extends Statement implements Expression {
  final String name;
  final List<Expression> args;
  Call(this.name, this.args);
}

class Do extends Statement {
  final Block block;
  Do(this.block);
}

class While extends Statement {
  final Expression condition;
  final Block block;
  While(this.condition, this.block);
}

class Repeat extends Statement {
  final Block block;
  final Expression condition;
  Repeat(this.block, this.condition);
}

class If extends Statement {
  final Expression condition;
  final Block block;
  final List<ElseIf>? elseIfs;
  final Block? elseBlock;

  If(
    this.condition,
    this.block, {
    this.elseIfs,
    this.elseBlock,
  });
}

class ElseIf {
  final Expression condition;
  final Block block;

  ElseIf(this.condition, this.block);
}

class For extends Statement {
  final String name;
  final Expression init;
  final Expression stop;
  final Expression? increment;
  final Block block;

  For({
    required this.name,
    required this.init,
    required this.stop,
    this.increment,
    required this.block,
  });
}

class ForEach extends Statement {
  final List<String> names;
  final List<Expression> values;
  final Block block;

  ForEach(this.names, this.values, this.block);
}

class FunctionDef extends Statement {
  final String name;
  final List<String> args;
  final Block body;
  final bool isLocal;

  FunctionDef(
    this.name,
    this.args,
    this.body, {
    this.isLocal = false,
  });
}

class Return extends Statement {
  final List<Expression>? values;
  Return({this.values});
}

class Break extends Statement {
  Break();
}

class InlineFunction extends Expression {
  final List<String> args;
  final Block body;

  InlineFunction(this.args, this.body);
}

class Nil extends Expression {
  static const _instance = Nil._();
  const Nil._();

  factory Nil() => _instance;

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitNil(this);
}

class Bool extends Expression {
  final bool value;
  const Bool(this.value);

  @override
  int get hashCode => value.hashCode;

  @override
  bool operator ==(Object other) {
    return other is Bool && value == other.value;
  }

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitBool(this);
}

class Number extends Expression {
  final num value;
  Number(this.value);

  @override
  int get hashCode => value.hashCode;

  @override
  bool operator ==(Object other) {
    return other is Number && value == other.value;
  }

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitNumber(this);
}

class LuaString extends Expression {
  final String value;
  LuaString(this.value);

  @override
  int get hashCode => value.hashCode;

  @override
  bool operator ==(Object other) {
    return other is LuaString && value == other.value;
  }

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitString(this);
}

class Table extends Expression {
  final List<Field> fields;

  const Table(this.fields);

  @override
  int get hashCode => Object.hashAll(fields);

  @override
  bool operator ==(Object other) {
    return other is Table &&
        fields.length == other.fields.length &&
        fields.whereIndexed((i, e) => e == other.fields[i]).length ==
            fields.length;
  }

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitTable(this);
}

class Field {
  final String? name;
  final Expression? index;
  final Expression value;

  Field({
    this.name,
    this.index,
    required this.value,
  }) {
    if (name != null && index != null) {
      throw ArgumentError('Only one of `name` or `index` must be set.');
    }
  }

  @override
  int get hashCode => Object.hashAll([name, index, value]);

  @override
  bool operator ==(Object other) {
    return other is Field &&
        name == other.name &&
        index == other.index &&
        value == other.value;
  }
}

class Negative extends Expression {
  final Expression value;
  Negative(this.value);
}

class Not extends Expression {
  final Expression value;
  Not(this.value);
}

class Length extends Expression {
  final Expression value;
  Length(this.value);
}

class BinOp extends Expression {
  final Expression left;
  final String operator;
  final Expression right;

  BinOp(this.left, this.operator, this.right);
}

class VarRef extends Expression {
  final String name;

  const VarRef(this.name);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitVarRef(this);

  @override
  int get hashCode => name.hashCode;

  @override
  bool operator ==(Object other) {
    return other is VarRef && name == other.name;
  }
}
