import 'package:lua/src/ast.dart';
import 'package:petitparser/definition.dart';
import 'package:petitparser/parser.dart';

class ParameterList {
  final List<String> parameters;
  final bool hasVariadicArgs;

  ParameterList(this.parameters, this.hasVariadicArgs);
}

final _parser = LuaGrammarDefinition().build<Block>();

Block parse(String text) {
  return _parser.parse(text).value;
}

class LuaGrammarDefinition extends GrammarDefinition {
  const LuaGrammarDefinition();

  @override
  Parser<Block> start() => ref0(block).end();
  Parser token(Parser parser) => parser.flatten().trim();

  Parser<Block> block() {
    // Context-aware block parser that stops at terminating keywords
    final separator = (char(';') | char('\n')).star();

    // Keywords that should terminate block parsing
    final terminators = ['end', 'else', 'elseif', 'until']
        .map((keyword) => keyword.toParser().trim())
        .toList();

    final terminator = terminators.toChoiceParser();

    // Create a statement parser that won't consume terminators
    final safeStatement = (terminator.not() & ref0(statement))
        .map((value) => value[1] as Statement);

    return (separator & safeStatement.starSeparated(separator) & separator)
        .map((value) {
      final separatedList = value[1] as SeparatedList;
      final statements = separatedList.elements.cast<Statement>();
      return Block(statements);
    });
  }

  // Special parser for statements followed by semicolon and inline comment
  Parser<Statement> statementWithInlineComment() =>
      (ref0(basicStatement) & char(';').trim() & ref0(singleLineComment))
          .map((value) {
        final stmt = value[0] as Statement;
        final comment = value[2] as SingleLineComment;
        final commentText = comment.text.trim();

        // Just return the statement with comment attached - simplified approach
        if (stmt is Assign) {
          return Assign(
            stmt.names,
            stmt.values,
            isLocal: stmt.isLocal,
            comment: commentText,
          );
        } else if (stmt is Return) {
          return Return(values: stmt.values, comment: commentText);
        } else if (stmt is Call) {
          return Call(stmt.name, stmt.args, comment: commentText);
        }
        // For other types, just return the original statement
        return stmt;
      });

  Parser<Statement> basicStatement() => <Parser<Statement>>[
        ref0(functionDef),
        ref0(ifStatement),
        ref0(whileStatement),
        ref0(repeatStatement),
        ref0(forStatement),
        ref0(returnStatement),
        ref0(breakStatement),
        ref0(assignment),
        ref0(callStatement),
      ].toChoiceParser();

  Parser<Statement> statement() => <Parser<Statement>>[
        ref0(multiLineComment),
        ref0(singleLineComment),
        ref0(statementWithInlineComment), // Handle stmt; -- comment pattern
        ref0(basicStatement), // All other statements
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
                  } else if (base is FieldAccess) {
                    // Support method calls like math.abs() by creating a special call
                    return CallFieldAccess(
                        base,
                        (value[1] as SeparatedList)
                            .elements
                            .cast<Expression>());
                  } else {
                    // Support calling any expression (e.g., anonymous functions)
                    return CallExpression(
                        base,
                        (value[1] as SeparatedList)
                            .elements
                            .cast<Expression>());
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
    // Use negative lookahead to prevent matching '--' as subtraction
    final subtractOp = (char('-') & char('-').not()).flatten().trim();
    return ref0(multiplicativeExpression)
        .seq((char('+').trim() | subtractOp)
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
    // Use negative lookahead to prevent matching '--' as unary minus
    final unaryMinusOp = (char('-') & char('-').not()).flatten().trim();
    return (token('not'.toParser()) | unaryMinusOp | char('#').trim())
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
        ref0(inlineFunction),
        ref0(varRef),
        ref0(variadicArgs),
        (char('(').trim() & ref0(expression) & char(')').trim())
            .map((value) => value[1]),
      ].toChoiceParser().map((value) => value);

  Parser<Assign> assignment() => (token('local'.toParser()).optional() &
          allowedChars().plusString().trim().plusSeparated(char(',').trim()) &
          char('=').trim() &
          ref0(expression).plusSeparated(char(',').trim()))
      .map((value) => Assign(
            (value[1] as SeparatedList).elements.cast<String>(),
            (value[3] as SeparatedList).elements.cast<Expression>(),
            isLocal: value[0] != null,
          ));

  Parser<Statement> callStatement() {
    return ref0(postfixExpression)
        .where((expr) => expr is Call || expr is CallFieldAccess)
        .cast<Statement>();
  }

  Parser<Number> number() => token(
          (digit().plus() & (char('.') & digit().plus()).optional()).flatten())
      .map((value) => Number(num.parse(value)));

  Parser<LuaString> string() =>
      (ref0(doubleQuotedString) | ref0(singleQuotedString) | ref0(longString))
          .cast<LuaString>();

  // Double-quoted strings with escape sequences
  Parser<LuaString> doubleQuotedString() =>
      (char('"') & ref0(doubleQuotedContent).star() & char('"'))
          .map((value) => LuaString((value[1] as List).join()));

  Parser<String> doubleQuotedContent() =>
      (ref0(escapeSequence) | char('"').neg()).cast<String>();

  // Single-quoted strings with escape sequences
  Parser<LuaString> singleQuotedString() =>
      (char("'") & ref0(singleQuotedContent).star() & char("'"))
          .map((value) => LuaString((value[1] as List).join()));

  Parser<String> singleQuotedContent() =>
      (ref0(escapeSequence) | char("'").neg()).cast<String>();

  // Long strings [[...]]
  Parser<LuaString> longString() => (char('[') &
          char('[') &
          (char(']') & char(']')).neg().star().flatten() &
          char(']') &
          char(']'))
      .map((value) => LuaString(value[2] as String));

  // Escape sequences
  Parser<String> escapeSequence() => (char(r'\') &
          ((digit() & digit() & digit()).map((value) {
                final code = int.parse(value.join());
                if (code > 255) {
                  throw FormatException(
                      'Decimal escape sequence out of range: $code');
                }
                return String.fromCharCode(code);
              }) |
              (char('x') & pattern('0-9a-fA-F') & pattern('0-9a-fA-F'))
                  .map((value) {
                final hex = value.sublist(1).join();
                return String.fromCharCode(int.parse(hex, radix: 16));
              }) |
              char('n').map((_) => '\n') |
              char('t').map((_) => '\t') |
              char('r').map((_) => '\r') |
              char('b').map((_) => '\b') |
              char('f').map((_) => '\f') |
              char('a').map((_) => '\x07') | // bell
              char('v').map((_) => '\v') | // vertical tab
              char(r'\').map((_) => r'\') |
              char('"').map((_) => '"') |
              char("'").map((_) => "'") |
              char('0').map((_) => '\x00') | // null
              any()))
      .map((value) => value[1] as String);

  Parser<VarRef> varRef() => token(ref0(name)).map((value) => VarRef(value));

  Parser<VariadicArgs> variadicArgs() =>
      '...'.toParser().trim().map((value) => const VariadicArgs());

  Parser<String> name() => allowedChars().plusString();
  Parser<String> allowedChars() => anyCharExcept('[](){}:<!=>".\'+-*/% \t\n,');

  Parser<Table> table() => (char('{').trim() &
              ref0(fieldListWithMiddleComments).optional() &
              char('}'))
          .map((value) {
        final fields = (value[1] as List<Field>?) ?? <Field>[];
        return Table(fields);
      });

  Parser<List<Field>> fieldList() =>
      ref0(fieldListWithComments).optional().map((value) => value ?? <Field>[]);

  // Custom field list parser that handles comma-level comments
  Parser<List<Field>> fieldListWithComments() {
    final multiFieldParser = (ref0(field) &
            (char(',').trim() & ref0(optionalInlineComment).optional())
                .optional())
        .plus()
        .map((List<dynamic> pairs) {
      final List<Field> fields = [];

      for (int i = 0; i < pairs.length; i++) {
        final pair = pairs[i] as List<dynamic>;
        Field field = pair[0] as Field;
        final commaInfo = pair[1] as List<dynamic>?;

        // If there's a comma comment, associate it with this field
        if (commaInfo != null && commaInfo[1] != null) {
          final commaComment = commaInfo[1] as String;
          // Create new field with combined comment
          final existingComment = field.comment;
          final combinedComment = existingComment != null
              ? '$existingComment, $commaComment'
              : commaComment;
          field = Field(
            name: field.name,
            index: field.index,
            value: field.value,
            comment: combinedComment,
          );
        }

        fields.add(field);
      }

      return fields;
    });

    final singleFieldParser = ref0(field).map((field) => [field]);

    return [multiFieldParser, singleFieldParser].toChoiceParser();
  }

  // Parser for inline comments within tables (line comments without newlines)
  Parser<String> tableLineComment() => ('--'.toParser() &
          (char('[').not() & (char('\n') | endOfInput()).neg())
              .star()
              .flatten()
              .trim()) // Trim whitespace from comment text
      .map((value) => value[1] as String);

  // Parser that handles fields with middle comments
  Parser<List<Field>> fieldListWithMiddleComments() {
    // Parse field with optional preceding comments, comma, and possible trailing comma
    final fieldWithComments = (ref0(tableLineComment).trim().star() &
            ref0(field) &
            (char(',').trim() & ref0(optionalInlineComment).optional())
                .optional())
        .map((value) {
      final precedingComments = value[0] as List<String>;
      Field field = value[1] as Field;
      final commaInfo = value[2] as List<dynamic>?;

      // Handle comma-level comments (like the existing logic)
      if (commaInfo != null && commaInfo[1] != null) {
        final commaComment = commaInfo[1] as String;
        final existingComment = field.comment;
        final combinedComment = existingComment != null
            ? '$existingComment, $commaComment'
            : commaComment;
        field = Field(
          name: field.name,
          index: field.index,
          value: field.value,
          comment: combinedComment,
        );
      }

      // If there are preceding comments, attach them to the field
      if (precedingComments.isNotEmpty) {
        final precedingComment = precedingComments.join('\n');
        final existingComment = field.comment;
        final combinedComment = existingComment != null
            ? '$precedingComment\n$existingComment'
            : precedingComment;
        field = Field(
          name: field.name,
          index: field.index,
          value: field.value,
          comment: combinedComment,
        );
      }

      return field;
    });

    // Handle single field or multiple fields
    final singleField = fieldWithComments.map((field) => [field]);
    final multipleFields = fieldWithComments.plus();

    return [multipleFields, singleField].toChoiceParser();
  }

  Parser<Field> field() => <Parser<Field>>[
        // Indexed field: [expr] = value -- comment
        (char('[').trim() &
                ref0(expression) &
                char(']').trim() &
                char('=').trim() &
                ref0(expression).trim() &
                ref0(optionalInlineComment))
            .map((value) => Field(
                index: value[1] as Expression,
                value: value[4] as Expression,
                comment: value[5] as String?)),
        // Named field: name = value -- comment
        (ref0(name).trim() &
                char('=').trim() &
                ref0(expression).trim() &
                ref0(optionalInlineComment))
            .map((value) => Field(
                name: value[0] as String,
                value: value[2] as Expression,
                comment: value[3] as String?)),
        // Array-style field: value -- comment (must come last)
        (ref0(expression).trim() & ref0(optionalInlineComment)).map(
            (value) => Field(value: value[0], comment: value[1] as String?)),
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

  Parser<Repeat> repeatStatement() => (token('repeat'.toParser()) &
          ref0(block) &
          token('until'.toParser()) &
          ref0(expression))
      .map((value) => Repeat(value[1] as Block, value[3] as Expression));

  Parser<Statement> forStatement() => <Parser<Statement>>[
        ref0(forNumericStatement),
        ref0(forInStatement),
      ].toChoiceParser();

  Parser<For> forNumericStatement() => (token('for'.toParser()) &
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

  Parser<ForEach> forInStatement() => (token('for'.toParser()) &
          ref0(nameList) &
          token('in'.toParser()) &
          ref0(expressionList) &
          token('do'.toParser()) &
          ref0(block) &
          token('end'.toParser()))
      .map((value) => ForEach(
            value[1] as List<String>,
            value[3] as List<Expression>,
            value[5] as Block,
          ));

  Parser<List<String>> nameList() => ref0(name)
      .plusSeparated(char(',').trim())
      .map((v) => v.elements.cast<String>());

  Parser<List<Expression>> expressionList() => ref0(expression)
      .plusSeparated(char(',').trim())
      .map((v) => v.elements.cast<Expression>());

  Parser<FunctionDef> functionDef() => (token('local'.toParser()).optional() &
              token('function'.toParser()) &
              token(ref0(name)) &
              char('(') &
              ref0(paramList) &
              char(')') &
              ref0(block) &
              token('end'.toParser()))
          .map((value) {
        final paramList = value[4] as ParameterList;
        return FunctionDef(
          value[2] as String,
          paramList.parameters,
          value[6] as Block,
          isLocal: value[0] != null,
          hasVariadicArgs: paramList.hasVariadicArgs,
        );
      });

  Parser<InlineFunction> inlineFunction() => (token('function'.toParser()) &
              char('(') &
              ref0(paramList) &
              char(')') &
              ref0(block) &
              token('end'.toParser()))
          .map((value) {
        final paramList = value[2] as ParameterList;
        return InlineFunction(
          paramList.parameters,
          value[4] as Block,
        );
      });

  Parser<ParameterList> paramList() =>
      ('...'.toParser().trim().map((value) => ParameterList([], true)) |
              (ref0(name).plusSeparated(char(',').trim()) &
                      (char(',').trim() & '...'.toParser().trim()).optional())
                  .map((value) {
                final params =
                    (value[0] as SeparatedList).elements.cast<String>();
                final hasVariadic = value[1] != null;
                return ParameterList(params, hasVariadic);
              }) |
              epsilon().map((value) => ParameterList([], false)))
          .cast<ParameterList>();

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

  Parser<SingleLineComment> singleLineComment() => ('--'.toParser() &
          (char('[').not() & (char('\n') | endOfInput()).neg())
              .star()
              .flatten())
      .map((value) => SingleLineComment(value[1] as String));

  Parser<MultiLineComment> multiLineComment() => ('--[['.toParser() &
          ']]'.toParser().neg().star().flatten() &
          ']]'.toParser())
      .map((value) => MultiLineComment(value[1] as String));

  // Helper parser for optional inline field comments
  // Only matches if not followed by end of table or newline (for table trailing comments)
  Parser<String?> optionalInlineComment() => ('--'.toParser() &
          (char('[').not() &
                  char('}').not() &
                  (char('\n') | char(',') | endOfInput()).neg())
              .plus() // require at least one character (not empty comment)
              .flatten()
              .trim())
      .map((value) => (value[1] as String).trim())
      .optional();
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
