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
        ref0(callStatement),
      ].toChoiceParser().map((value) => value);

  Parser<Expression> expression() => ref0(orExpression);

  Parser<Expression> postfixExpression() {
    return ref0(atomicExpression)
        .seq(
      <Parser>[
        // Function call: expr(args) - only support simple variable names for now
        (char('(').trim() &
                ref0(expression).starSeparated(char(',').trim()) &
                char(')').trim())
            .map((value) => (Expression base) {
                  if (base is VarRef) {
                    return Call(
                        base.name,
                        (value[1] as SeparatedList)
                            .elements
                            .cast<Expression>());
                  } else {
                    throw FormatException(
                        'Only simple function names are supported for calls: $base');
                  }
                }),
        // Index access: expr[key]
        (char('[').trim() & ref0(expression) & char(']').trim()).map((value) =>
            (Expression base) => Index(base, value[1] as Expression)),
        // Field access: expr.field
        (char('.').trim() & ref0(name)).map((value) =>
            (Expression base) => FieldAccess(base, value[1] as String)),
      ].toChoiceParser().star(),
    )
        .map((value) {
      Expression result = value[0] as Expression;
      for (final fn in value[1] as List) {
        result = (fn as Function)(result);
      }
      return result;
    });
  }

  // Precedence levels from lowest to highest

  // Level 1: or (logical or)
  Parser<Expression> orExpression() {
    return ref0(andExpression)
        .plusSeparated(token('or'.toParser()))
        .map((value) {
      if (value.elements.length == 1) return value.elements.single;
      return Or(value.elements.cast<Expression>());
    });
  }

  // Level 2: and (logical and)
  Parser<Expression> andExpression() {
    return ref0(comparisonExpression)
        .plusSeparated(token('and'.toParser()))
        .map((value) {
      if (value.elements.length == 1) return value.elements.single;
      return And(value.elements.cast<Expression>());
    });
  }

  // Level 3: ==, ~=, <, <=, >, >= (comparison)
  Parser<Expression> comparisonExpression() {
    return ref0(concatenationExpression)
        .seq((token('=='.toParser()) |
                token('~='.toParser()) |
                token('<='.toParser()) |
                token('>='.toParser()) |
                token('<'.toParser()) |
                token('>'.toParser()))
            .seq(ref0(concatenationExpression))
            .optional())
        .map((value) {
      final left = value[0] as Expression;
      final right = value[1] as List?;
      if (right == null) return left;

      final op = right[0] as String;
      final rightExpr = right[1] as Expression;

      switch (op) {
        case '==':
          return Equals(left, rightExpr);
        case '~=':
          return NotEquals(left, rightExpr);
        case '<':
          return Less(left, rightExpr);
        case '<=':
          return LessEq(left, rightExpr);
        case '>':
          return Greater(left, rightExpr);
        case '>=':
          return GreaterEq(left, rightExpr);
        default:
          throw FormatException('Unknown comparison operator: $op');
      }
    });
  }

  // Level 4: .. (concatenation - right associative)
  Parser<Expression> concatenationExpression() {
    return ref0(additiveExpression)
        .plusSeparated(token('..'.toParser()))
        .map((value) {
      if (value.elements.length == 1) return value.elements.single;
      // Right associative - build tree from right to left
      Expression result = value.elements.last;
      for (int i = value.elements.length - 2; i >= 0; i--) {
        result = Concatenate([value.elements[i], result]);
      }
      return result;
    });
  }

  // Level 5: +, - (addition, subtraction)
  Parser<Expression> additiveExpression() {
    return ref0(multiplicativeExpression)
        .seq((char('+').trim() | char('-').trim())
            .seq(ref0(multiplicativeExpression))
            .star())
        .map((value) {
      Expression result = value[0] as Expression;
      final ops = value[1] as List;

      for (final List op in ops) {
        final operator = op[0] as String;
        final right = op[1] as Expression;

        if (operator == '+') {
          result = Add([result, right]);
        } else {
          result = Subtract(result, right);
        }
      }
      return result;
    });
  }

  // Level 6: *, /, % (multiplication, division, modulo)
  Parser<Expression> multiplicativeExpression() {
    return ref0(unaryExpression)
        .seq((char('*').trim() | char('/').trim() | char('%').trim())
            .seq(ref0(unaryExpression))
            .star())
        .map((value) {
      Expression result = value[0] as Expression;
      final ops = value[1] as List;

      for (final List op in ops) {
        final operator = op[0] as String;
        final right = op[1] as Expression;

        switch (operator) {
          case '*':
            result = Multiply([result, right]);
            break;
          case '/':
            result = Divide(result, right);
            break;
          case '%':
            result = Modulo(result, right);
            break;
        }
      }
      return result;
    });
  }

  // Level 7: not, -, # (unary operators)
  Parser<Expression> unaryExpression() {
    return (token('not'.toParser()) | char('-').trim() | char('#').trim())
        .optional()
        .seq(ref0(exponentiationExpression))
        .map((value) {
      final op = value[0] as String?;
      final expr = value[1] as Expression;

      if (op == null) return expr;

      switch (op) {
        case 'not':
          return Not(expr);
        case '-':
          return Negative(expr);
        case '#':
          return Length(expr);
        default:
          return expr;
      }
    });
  }

  // Level 8: ^ (exponentiation - right associative)
  Parser<Expression> exponentiationExpression() {
    return ref0(postfixExpression).plusSeparated(char('^').trim()).map((value) {
      if (value.elements.length == 1) return value.elements.single;
      // Right associative - build tree from right to left
      Expression result = value.elements.last;
      for (int i = value.elements.length - 2; i >= 0; i--) {
        result = Exponent(value.elements[i], result);
      }
      return result;
    });
  }

  Parser<Expression> atomicExpression() => <Parser<Expression>>[
        ref0(nil),
        ref0(boolTrue),
        ref0(boolFalse),
        ref0(number),
        ref0(string),
        ref0(table),
        ref0(varRef),
        (char('(').trim() & ref0(expression) & char(')').trim())
            .map((value) => value[1]),
      ].toChoiceParser().map((value) => value);

  Parser<Assign> assignment() =>
      (ref0(name).trim() & char('=').trim() & ref0(expression)).map(
          (value) => Assign.single(value[0] as String, value[2] as Expression));

  Parser<Statement> callStatement() {
    return ref0(postfixExpression).where((expr) => expr is Call).cast<Call>();
  }

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
