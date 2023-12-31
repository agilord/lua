import 'package:collection/collection.dart';
import 'package:lua/src/evaluator.dart';

abstract class Visitor<T> {
  T visitAst(Ast value) =>
      throw UnimplementedError('${value.runtimeType} is not implemented');
  T visitStatement(Statement value) => visitAst(value);
  T visitExpression(Expression value) => visitStatement(value);
  T visitAnd(And value) => visitExpression(value);
  T visitOr(Or value) => visitExpression(value);
  T visitNot(Not value) => visitExpression(value);
  T visitEquals(Equals value) => visitExpression(value);
  T visitNotEquals(NotEquals value) => visitExpression(value);
  T visitLess(Less value) => visitExpression(value);
  T visitLessEq(LessEq value) => visitExpression(value);
  T visitGreater(Greater value) => visitExpression(value);
  T visitGreaterEq(GreaterEq value) => visitExpression(value);
  T visitConcatenate(Concatenate value) => visitExpression(value);
  T visitAdd(Add value) => visitExpression(value);
  T visitSubstract(Substract value) => visitExpression(value);
  T visitMultiply(Multiply value) => visitExpression(value);
  T visitDivide(Divide value) => visitExpression(value);
  T visitModulo(Modulo value) => visitExpression(value);
  T visitExponent(Exponent value) => visitExpression(value);

  T visitBlock(Block value) => visitAst(value);
  T visitVarRef(VarRef value) => visitExpression(value);
  T visitNil(Nil value) => visitExpression(value);
  T visitBool(Bool value) => visitExpression(value);
  T visitNumber(Number value) => visitExpression(value);
  T visitString(LuaString value) => visitExpression(value);
  T visitTable(Table value) => visitExpression(value);
  T visitNegative(Negative value) => visitExpression(value);
  T visitLength(Length value) => visitExpression(value);

  T visitBreak(Break value) => visitStatement(value);
  T visitReturn(Return value) => visitStatement(value);
  T visitAssign(Assign value) => visitStatement(value);
  T visitCall(Call value) => visitStatement(value);
  T visitDo(Do value) => visitStatement(value);
  T visitWhile(While value) => visitStatement(value);
  T visitRepeat(Repeat value) => visitStatement(value);
  T visitIf(If value) => visitStatement(value);
  T visitFor(For value) => visitStatement(value);
  T visitForEach(ForEach value) => visitStatement(value);
  T visitFunctionDef(FunctionDef value) => visitStatement(value);
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

abstract class Expression<E> extends Statement {
  const Expression();
  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitExpression(this);
}

abstract class Literal<E> extends Expression<E> {
  const Literal();
}

extension BoolExpressionExt on Expression<bool> {
  Expression<bool> not() => Not(this);

  And and(Expression<bool> other) {
    if (this is And) {
      final t = this as And;
      return And([...t.items, other]);
    } else {
      return And([this, other]);
    }
  }

  Or or(Expression<bool> other) {
    if (this is Or) {
      final t = this as Or;
      return Or([...t.items, other]);
    } else {
      return Or([this, other]);
    }
  }
}

extension ExpressionExt on Expression {
  Equals equals(Expression other) => Equals(this, other);
  NotEquals notEquals(Expression other) => NotEquals(this, other);

  Concatenate concatenate(Expression other) {
    if (this is Concatenate) {
      final t = this as Concatenate;
      return Concatenate([...t.values, other]);
    } else {
      return Concatenate([this, other]);
    }
  }
}

extension NumExpressionExt on Expression<num> {
  Negative negative() => Negative(this);
  Less lessThan(Expression<num> other) => Less(this, other);
  LessEq lessThanOrEquals(Expression<num> other) => LessEq(this, other);
  Greater greaterThan(Expression<num> other) => Greater(this, other);
  GreaterEq greaterThanOrEquals(Expression<num> other) =>
      GreaterEq(this, other);

  Add plus(Expression<num> other) {
    if (this is Add) {
      final t = this as Add;
      return Add([...t.values, other]);
    } else {
      return Add([this, other]);
    }
  }

  Substract minus(Expression<num> other) => Substract(this, other);

  Multiply multiply(Expression<num> other) {
    if (this is Multiply) {
      final t = this as Multiply;
      return Multiply([...t.values, other]);
    } else {
      return Multiply([this, other]);
    }
  }

  Divide divide(Expression<num> other) => Divide(this, other);
  Modulo modulo(Expression<num> other) => Modulo(this, other);
  Exponent exponent(Expression<num> other) => Exponent(this, other);
}

extension BoolExt on bool {
  Bool lua() => Bool(this);
}

extension NumExt on num {
  Number lua() => Number(this);
}

extension StringExt on String {
  LuaString lua() => LuaString(this);
}

class Block extends Ast {
  final List<Statement> statements;

  Block(this.statements);
  Block.empty() : statements = [];

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

extension BlockExt on Block {
  Block add(Statement other) => Block([...statements, other]);
  Block addAll(Iterable<Statement> other) => Block([...statements, ...other]);
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

  factory Assign.single(
    String name,
    Expression value, {
    bool isLocal = false,
  }) =>
      Assign(
        [name],
        [value],
        isLocal: isLocal,
      );

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitAssign(this);
}

class Call extends Statement implements Expression {
  final String name;
  final List<Expression> args;
  Call(this.name, this.args);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitCall(this);
}

class Do extends Statement {
  final Block block;
  Do(this.block);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitDo(this);
}

class While extends Statement {
  final Expression condition;
  final Block block;
  While(this.condition, this.block);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitWhile(this);
}

class Repeat extends Statement {
  final Block block;
  final Expression condition;
  Repeat(this.block, this.condition);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitRepeat(this);
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

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitIf(this);
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

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitFor(this);
}

class ForEach extends Statement {
  final List<String> names;
  final List<Expression> values;
  final Block block;

  ForEach(this.names, this.values, this.block);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitForEach(this);
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

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitFunctionDef(this);
}

class Return extends Statement {
  final List<Expression>? values;
  Return({this.values});

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitReturn(this);
}

class Break extends Statement {
  Break();

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitBreak(this);
}

class InlineFunction extends Expression {
  final List<String> args;
  final Block body;

  InlineFunction(this.args, this.body);
}

class Nil extends Literal<Null> {
  static const _instance = Nil._();
  const Nil._();

  factory Nil() => _instance;

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitNil(this);
}

class Bool extends Literal<bool> {
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

class Number extends Literal<num> {
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

class LuaString extends Literal<String> {
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

class Table extends Expression<TableInstance> {
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

class Negative extends Expression<num> {
  final Expression<num> value;
  Negative(this.value);

  @override
  int get hashCode => value.hashCode + 1;

  @override
  bool operator ==(Object other) {
    return other is Negative && value == other.value;
  }

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitNegative(this);
}

class Not extends Expression<bool> {
  final Expression<bool> value;
  Not(this.value);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitNot(this);
}

class Length extends Expression<int> {
  final Expression value;
  Length(this.value);

  @override
  int get hashCode => value.hashCode + 2;

  @override
  bool operator ==(Object other) {
    return other is Length && value == other.value;
  }

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitLength(this);
}

class And extends Expression<bool> {
  final List<Expression<bool>> items;
  And(this.items);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitAnd(this);
}

class Or extends Expression<bool> {
  final List<Expression<bool>> items;

  Or(this.items);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitOr(this);
}

class Equals extends Expression<bool> {
  final Expression left;
  final Expression right;

  Equals(this.left, this.right);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitEquals(this);
}

class NotEquals extends Expression<bool> {
  final Expression left;
  final Expression right;

  NotEquals(this.left, this.right);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitNotEquals(this);
}

class Less extends Expression<bool> {
  final Expression left;
  final Expression right;

  Less(this.left, this.right);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitLess(this);
}

class LessEq extends Expression<bool> {
  final Expression left;
  final Expression right;

  LessEq(this.left, this.right);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitLessEq(this);
}

class Greater extends Expression<bool> {
  final Expression left;
  final Expression right;

  Greater(this.left, this.right);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitGreater(this);
}

class GreaterEq extends Expression<bool> {
  final Expression left;
  final Expression right;

  GreaterEq(this.left, this.right);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitGreaterEq(this);
}

class Concatenate extends Expression<String> {
  final List<Expression> values;

  Concatenate(this.values);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitConcatenate(this);
}

class Add extends Expression<num> {
  final List<Expression> values;

  Add(this.values);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitAdd(this);
}

class Substract extends Expression<num> {
  final Expression left;
  final Expression right;

  Substract(this.left, this.right);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitSubstract(this);
}

class Multiply extends Expression<num> {
  final List<Expression> values;

  Multiply(this.values);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitMultiply(this);
}

class Divide extends Expression<num> {
  final Expression left;
  final Expression right;

  Divide(this.left, this.right);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitDivide(this);
}

class Modulo extends Expression<num> {
  final Expression left;
  final Expression right;

  Modulo(this.left, this.right);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitModulo(this);
}

class Exponent extends Expression<num> {
  final Expression left;
  final Expression right;

  Exponent(this.left, this.right);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitExponent(this);
}

class VarRef<E> extends Expression<E> {
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
