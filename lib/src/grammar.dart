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
  Parser<String> allowedChars() => anyCharExcept('[]():<!=>".\'+-*/% \t\n');

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
