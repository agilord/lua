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

  Parser<Statement> statement() =>
      <Parser<Statement>>[ref0(call)].toChoiceParser().map((value) => value);
  Parser<Expression> expression() => <Parser<Expression>>[
        ref0(nil),
        ref0(boolTrue),
        ref0(boolFalse),
      ].toChoiceParser().map((value) => value);

  Parser<Call> call() => (ref0(name) &
          char('(') &
          ref0(expression).starSeparated(char(',')) &
          char(')'))
      .map((value) =>
          Call(value[0] as String, (value[1] as List).cast<Expression>()));

  Parser<String> name() => allowedChars().plusString();
  Parser<String> allowedChars() => anyCharExcept('[]():<!=>".\'');

  Parser<Nil> nil() => 'nil'.toParser().map((value) => Nil());
  Parser<Bool> boolTrue() => 'true'.toParser().map((value) => Bool(true));
  Parser<Bool> boolFalse() => 'false'.toParser().map((value) => Bool(false));
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
