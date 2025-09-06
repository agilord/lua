import 'package:lua/src/ast.dart';
import 'package:petitparser/definition.dart';
import 'package:petitparser/parser.dart';

final _parser = LuaGrammarDefinition().build<Block>();

Block parse(String text) {
  return _parser.parse(text).value;
}

class LuaGrammarDefinition extends GrammarDefinition {
  const LuaGrammarDefinition();

  @override
  Parser<Block> start() => ref0(block).end();
  Parser token(Parser parser) => parser.flatten().trim();

  Parser<Block> block() =>
      ref0(statement).plusSeparated(anyOf(';\n')).map((v) => Block(v.elements));

  Parser<Statement> statement() => <Parser<Statement>>[
        ref0(functionDef),
        ref0(ifStatement),
        ref0(whileStatement),
        ref0(forStatement),
        ref0(returnStatement),
        ref0(breakStatement),
        ref0(assignment),
        ref0(call),
      ].toChoiceParser().map((value) => value);

  Parser<Expression> expression() => ref0(primary);

  Parser<Expression> primary() => <Parser<Expression>>[
        ref0(nil),
        ref0(boolTrue),
        ref0(boolFalse),
        ref0(number),
        ref0(string),
        ref0(table),
        ref0(varRef),
        ref0(call),
        (char('(').trim() & ref0(expression) & char(')').trim())
            .map((value) => value[1]),
      ].toChoiceParser().map((value) => value);

  Parser<Assign> assignment() =>
      (ref0(name).trim() & char('=').trim() & ref0(expression)).map(
          (value) => Assign.single(value[0] as String, value[2] as Expression));

  Parser<Call> call() => (ref0(name) &
          char('(') &
          ref0(expression).starSeparated(char(',')) &
          char(')'))
      .map((value) => Call(value[0] as String,
          (value[2] as SeparatedList).elements.cast<Expression>()));

  Parser<Number> number() => token(
          (digit().plus() & (char('.') & digit().plus()).optional()).flatten())
      .map((value) => Number(num.parse(value)));

  Parser<LuaString> string() =>
      (char('"') & char('"').neg().star().flatten() & char('"'))
          .trim()
          .map((value) => LuaString(value[1] as String));

  Parser<VarRef> varRef() => token(ref0(name)).map((value) => VarRef(value));

  Parser<String> name() => allowedChars().plusString();
  Parser<String> allowedChars() => anyCharExcept('[](){}:<!=>".\'+-*/% \t\n,');

  Parser<Table> table() => (char('{').trim() & ref0(fieldList) & char('}'))
      .map((value) => Table(value[1] as List<Field>));

  Parser<List<Field>> fieldList() => ref0(field)
      .plusSeparated(char(',').trim())
      .optional()
      .map((value) => value?.elements ?? <Field>[]);

  Parser<Field> field() => <Parser<Field>>[
        // Indexed field: [expr] = value
        (char('[').trim() &
                ref0(expression) &
                char(']').trim() &
                char('=').trim() &
                ref0(expression))
            .map((value) => Field(
                index: value[1] as Expression, value: value[4] as Expression)),
        // Named field: name = value
        (ref0(name) & char('=').trim() & ref0(expression)).map((value) =>
            Field(name: value[0] as String, value: value[2] as Expression)),
        // Array-style field: value (must come last)
        ref0(expression).map((value) => Field(value: value)),
      ].toChoiceParser();

  Parser<String> identifier() => pattern('a-zA-Z_').plus().flatten().trim();

  Parser<If> ifStatement() => (token('if'.toParser()) &
          ref0(expression) &
          token('then'.toParser()) &
          ref0(block) &
          ref0(elseIfParts).optional() &
          ref0(elsePart).optional() &
          token('end'.toParser()))
      .map((value) => If(
            value[1] as Expression,
            value[3] as Block,
            elseIfs: value[4] as List<ElseIf>?,
            elseBlock: value[5] as Block?,
          ));

  Parser<List<ElseIf>> elseIfParts() => ref0(elseIfPart).plus();

  Parser<ElseIf> elseIfPart() => (token('elseif'.toParser()) &
          ref0(expression) &
          token('then'.toParser()) &
          ref0(block))
      .map((value) => ElseIf(value[1] as Expression, value[3] as Block));

  Parser<Block> elsePart() => (token('else'.toParser()) & ref0(block))
      .map((value) => value[1] as Block);

  Parser<While> whileStatement() => (token('while'.toParser()) &
          ref0(expression) &
          token('do'.toParser()) &
          ref0(block) &
          token('end'.toParser()))
      .map((value) => While(value[1] as Expression, value[3] as Block));

  Parser<For> forStatement() => (token('for'.toParser()) &
          ref0(name) &
          char('=').trim() &
          ref0(expression) &
          char(',').trim() &
          ref0(expression) &
          (char(',').trim() & ref0(expression)).optional() &
          token('do'.toParser()) &
          ref0(block) &
          token('end'.toParser()))
      .map((value) => For(
            name: value[1] as String,
            init: value[3] as Expression,
            stop: value[5] as Expression,
            increment: (value[6] as List?)?[1] as Expression?,
            block: value[8] as Block,
          ));

  Parser<FunctionDef> functionDef() => (token('local'.toParser()).optional() &
          token('function'.toParser()) &
          ref0(name) &
          char('(') &
          ref0(paramList) &
          char(')') &
          ref0(block) &
          token('end'.toParser()))
      .map((value) => FunctionDef(
            value[2] as String,
            value[4] as List<String>,
            value[6] as Block,
            isLocal: value[0] != null,
          ));

  Parser<List<String>> paramList() => ref0(name)
      .plusSeparated(char(',').trim())
      .optional()
      .map((value) => value?.elements.cast<String>() ?? <String>[]);

  Parser<Return> returnStatement() => (token('return'.toParser()) &
          ref0(expression).plusSeparated(char(',').trim()).optional())
      .map((value) => Return(
            values: (value[1] as SeparatedList?)?.elements.cast<Expression>(),
          ));

  Parser<Break> breakStatement() =>
      token('break'.toParser()).map((value) => Break());

  Parser<Nil> nil() => token('nil'.toParser()).map((value) => Nil());
  Parser<Bool> boolTrue() =>
      token('true'.toParser()).map((value) => Bool(true));
  Parser<Bool> boolFalse() =>
      token('false'.toParser()).map((value) => Bool(false));
}

Parser<String> anyCharExcept(String except,
    [String message = 'letter or digit expected']) {
  return SingleCharacterParser(
          AnyCharExceptPredicate(except.codeUnits), message)
      .plus()
      .flatten();
}

class AnyCharExceptPredicate implements CharacterPredicate {
  final List<int> exceptCodeUnits;
  AnyCharExceptPredicate(this.exceptCodeUnits);
  static final _ws = WhitespaceCharPredicate();

  @override
  bool test(int value) => !_ws.test(value) && !exceptCodeUnits.contains(value);

  @override
  bool isEqualTo(CharacterPredicate other) {
    return (other is AnyCharExceptPredicate) && identical(this, other);
  }
}
