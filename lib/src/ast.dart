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
  T visitSubtract(Subtract value) => visitExpression(value);
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
  T visitIndex(Index value) => visitExpression(value);
  T visitFieldAccess(FieldAccess value) => visitExpression(value);
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

  Subtract minus(Expression<num> other) => Subtract(this, other);

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

  @override
  int get hashCode => Object.hashAll([isLocal, ...names, ...values]);

  @override
  bool operator ==(Object other) {
    return other is Assign &&
        isLocal == other.isLocal &&
        names.length == other.names.length &&
        values.length == other.values.length &&
        names.whereIndexed((i, e) => e == other.names[i]).length ==
            names.length &&
        values.whereIndexed((i, e) => e == other.values[i]).length ==
            values.length;
  }
}

class Call extends Statement implements Expression {
  final String name;
  final List<Expression> args;
  Call(this.name, this.args);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitCall(this);

  @override
  int get hashCode => Object.hashAll([name, ...args]);

  @override
  bool operator ==(Object other) {
    return other is Call &&
        name == other.name &&
        args.length == other.args.length &&
        args.whereIndexed((i, e) => e == other.args[i]).length == args.length;
  }
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

  @override
  int get hashCode => Object.hashAll([condition, block]);

  @override
  bool operator ==(Object other) {
    return other is While &&
        condition == other.condition &&
        block == other.block;
  }
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

  @override
  int get hashCode => Object.hashAll([condition, block, elseIfs, elseBlock]);

  @override
  bool operator ==(Object other) {
    return other is If &&
        condition == other.condition &&
        block == other.block &&
        elseIfs?.length == other.elseIfs?.length &&
        (elseIfs == null ||
            elseIfs!.whereIndexed((i, e) => e == other.elseIfs![i]).length ==
                elseIfs!.length) &&
        elseBlock == other.elseBlock;
  }
}

class ElseIf {
  final Expression condition;
  final Block block;

  ElseIf(this.condition, this.block);

  @override
  int get hashCode => Object.hashAll([condition, block]);

  @override
  bool operator ==(Object other) {
    return other is ElseIf &&
        condition == other.condition &&
        block == other.block;
  }
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

  @override
  int get hashCode => Object.hashAll([name, init, stop, increment, block]);

  @override
  bool operator ==(Object other) {
    return other is For &&
        name == other.name &&
        init == other.init &&
        stop == other.stop &&
        increment == other.increment &&
        block == other.block;
  }
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

  @override
  int get hashCode => Object.hashAll([name, ...args, body, isLocal]);

  @override
  bool operator ==(Object other) {
    return other is FunctionDef &&
        name == other.name &&
        args.length == other.args.length &&
        args.whereIndexed((i, e) => e == other.args[i]).length == args.length &&
        body == other.body &&
        isLocal == other.isLocal;
  }
}

class Return extends Statement {
  final List<Expression>? values;
  Return({this.values});

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitReturn(this);

  @override
  int get hashCode => Object.hashAll(values ?? []);

  @override
  bool operator ==(Object other) {
    return other is Return &&
        values?.length == other.values?.length &&
        (values == null ||
            values!.whereIndexed((i, e) => e == other.values![i]).length ==
                values!.length);
  }
}

class Break extends Statement {
  Break();

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitBreak(this);

  @override
  int get hashCode => 'Break'.hashCode;

  @override
  bool operator ==(Object other) {
    return other is Break;
  }
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

class Index extends Expression {
  final Expression table;
  final Expression key;

  Index(this.table, this.key);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitIndex(this);

  @override
  int get hashCode => Object.hashAll([table, key]);

  @override
  bool operator ==(Object other) {
    return other is Index && table == other.table && key == other.key;
  }
}

class FieldAccess extends Expression {
  final Expression table;
  final String field;

  FieldAccess(this.table, this.field);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitFieldAccess(this);

  @override
  int get hashCode => Object.hashAll([table, field]);

  @override
  bool operator ==(Object other) {
    return other is FieldAccess && table == other.table && field == other.field;
  }
}

class Negative extends Expression<num> {
  final Expression value;
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
  final Expression value;
  Not(this.value);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitNot(this);

  @override
  int get hashCode => value.hashCode + 3;

  @override
  bool operator ==(Object other) {
    return other is Not && value == other.value;
  }
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
  final List<Expression> items;
  And(this.items);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitAnd(this);

  @override
  int get hashCode => Object.hashAll(items);

  @override
  bool operator ==(Object other) {
    return other is And &&
        items.length == other.items.length &&
        items.whereIndexed((i, e) => e == other.items[i]).length ==
            items.length;
  }
}

class Or extends Expression<bool> {
  final List<Expression> items;

  Or(this.items);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitOr(this);

  @override
  int get hashCode => Object.hashAll(items);

  @override
  bool operator ==(Object other) {
    return other is Or &&
        items.length == other.items.length &&
        items.whereIndexed((i, e) => e == other.items[i]).length ==
            items.length;
  }
}

class Equals extends Expression<bool> {
  final Expression left;
  final Expression right;

  Equals(this.left, this.right);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitEquals(this);

  @override
  int get hashCode => Object.hash(left, right);

  @override
  bool operator ==(Object other) {
    return other is Equals && left == other.left && right == other.right;
  }
}

class NotEquals extends Expression<bool> {
  final Expression left;
  final Expression right;

  NotEquals(this.left, this.right);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitNotEquals(this);

  @override
  int get hashCode => Object.hash(left, right);

  @override
  bool operator ==(Object other) {
    return other is NotEquals && left == other.left && right == other.right;
  }
}

class Less extends Expression<bool> {
  final Expression left;
  final Expression right;

  Less(this.left, this.right);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitLess(this);

  @override
  int get hashCode => Object.hash(left, right);

  @override
  bool operator ==(Object other) {
    return other is Less && left == other.left && right == other.right;
  }
}

class LessEq extends Expression<bool> {
  final Expression left;
  final Expression right;

  LessEq(this.left, this.right);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitLessEq(this);

  @override
  int get hashCode => Object.hash(left, right);

  @override
  bool operator ==(Object other) {
    return other is LessEq && left == other.left && right == other.right;
  }
}

class Greater extends Expression<bool> {
  final Expression left;
  final Expression right;

  Greater(this.left, this.right);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitGreater(this);

  @override
  int get hashCode => Object.hash(left, right);

  @override
  bool operator ==(Object other) {
    return other is Greater && left == other.left && right == other.right;
  }
}

class GreaterEq extends Expression<bool> {
  final Expression left;
  final Expression right;

  GreaterEq(this.left, this.right);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitGreaterEq(this);

  @override
  int get hashCode => Object.hash(left, right);

  @override
  bool operator ==(Object other) {
    return other is GreaterEq && left == other.left && right == other.right;
  }
}

class Concatenate extends Expression<String> {
  final List<Expression> values;

  Concatenate(this.values);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitConcatenate(this);

  @override
  int get hashCode => Object.hashAll(values);

  @override
  bool operator ==(Object other) {
    return other is Concatenate &&
        values.length == other.values.length &&
        values.whereIndexed((i, e) => e == other.values[i]).length ==
            values.length;
  }
}

class Add extends Expression<num> {
  final List<Expression> values;

  Add(this.values);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitAdd(this);

  @override
  int get hashCode => Object.hashAll(values);

  @override
  bool operator ==(Object other) {
    return other is Add &&
        values.length == other.values.length &&
        values.whereIndexed((i, e) => e == other.values[i]).length ==
            values.length;
  }
}

class Subtract extends Expression<num> {
  final Expression left;
  final Expression right;

  Subtract(this.left, this.right);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitSubtract(this);

  @override
  int get hashCode => Object.hash(left, right);

  @override
  bool operator ==(Object other) {
    return other is Subtract && left == other.left && right == other.right;
  }
}

class Multiply extends Expression<num> {
  final List<Expression> values;

  Multiply(this.values);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitMultiply(this);

  @override
  int get hashCode => Object.hashAll(values);

  @override
  bool operator ==(Object other) {
    return other is Multiply &&
        values.length == other.values.length &&
        values.whereIndexed((i, e) => e == other.values[i]).length ==
            values.length;
  }
}

class Divide extends Expression<num> {
  final Expression left;
  final Expression right;

  Divide(this.left, this.right);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitDivide(this);

  @override
  int get hashCode => Object.hash(left, right);

  @override
  bool operator ==(Object other) {
    return other is Divide && left == other.left && right == other.right;
  }
}

class Modulo extends Expression<num> {
  final Expression left;
  final Expression right;

  Modulo(this.left, this.right);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitModulo(this);

  @override
  int get hashCode => Object.hash(left, right);

  @override
  bool operator ==(Object other) {
    return other is Modulo && left == other.left && right == other.right;
  }
}

class Exponent extends Expression<num> {
  final Expression left;
  final Expression right;

  Exponent(this.left, this.right);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitExponent(this);

  @override
  int get hashCode => Object.hash(left, right);

  @override
  bool operator ==(Object other) {
    return other is Exponent && left == other.left && right == other.right;
  }
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
