abstract class Visitor<T> {
  T visitAst(Ast value) =>
      throw UnimplementedError('${value.runtimeType} is not implemented');
  T visitStatement(Statement value) => visitAst(value);
  T visitExpression(Expression value) => visitAst(value);
  T visitBlock(Block value) => visitAst(value);
}

abstract class Ast {
  T visit<T>(Visitor<T> visitor) => visitor.visitAst(this);
}

abstract class Statement extends Ast {
  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitStatement(this);
}

abstract class Expression extends Ast {
  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitExpression(this);
}

class Block extends Ast {
  final List<Statement> statements;

  Block(this.statements);

  @override
  T visit<T>(Visitor<T> visitor) => visitor.visitBlock(this);
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

class Nil extends Expression {}

class Bool extends Expression {
  final bool value;
  Bool(this.value);
}

class Number extends Expression {
  final num value;
  Number(this.value);
}

class LuaString extends Expression {
  final String value;
  LuaString(this.value);
}

class Table extends Expression {
  final List<Field> fields;

  Table(this.fields);
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

  VarRef(this.name);
}
