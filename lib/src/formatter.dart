import 'ast.dart';

String format(Ast code) {
  final formatter = _LuaFormatter();
  final text = code.visit(formatter);
  return text.lines.join('\n');
}

extension FormatExt on Ast {
  String format() {
    final formatter = _LuaFormatter();
    final text = visit(formatter);
    return text.lines.join('\n');
  }
}

class _Code {
  final List<String> lines;

  _Code.withLines(this.lines);
  _Code.line(String value) : lines = [value];

  _Code prefixFirst(String v) {
    return _Code.withLines([
      '$v${lines.first}',
      ...lines.skip(1),
    ]);
  }

  _Code postfixLast(String v) {
    return _Code.withLines([
      ...lines.take(lines.length - 1),
      '${lines.last}$v',
    ]);
  }

  _Code joinInline(_Code v) {
    return _Code.withLines([
      ...lines.take(lines.length - 1),
      '${lines.last}${v.lines.first}',
      ...v.lines.skip(1),
    ]);
  }

  _Code joinDistinct(_Code v) {
    return _Code.withLines([...lines, ...v.lines]);
  }

  factory _Code.compose(
      String prefix, Iterable<_Code> items, String join, String postfix) {
    var v = _Code.line(prefix);
    var first = true;
    for (final item in items) {
      if (!first) {
        v = v.postfixLast(join);
      }
      first = false;
      v = v.joinInline(item);
    }
    v = v.postfixLast(postfix);
    return v;
  }

  _Code indent() {
    return _Code.withLines(lines.map((e) => '  $e').toList());
  }
}

class _LuaFormatter extends Visitor<_Code> {
  // Helper method to add comment to code if present
  _Code _addComment(_Code code, String? comment) {
    if (comment != null && comment.isNotEmpty) {
      return code.postfixLast('; --$comment');
    }
    return code;
  }

  @override
  _Code visitBlock(Block value) {
    return _Code.withLines(
        value.statements.expand((s) => s.visit(this).lines).toList());
  }

  @override
  _Code visitBreak(Break value) =>
      _addComment(_Code.line('break'), value.comment);

  @override
  _Code visitReturn(Return value) {
    final code = value.values == null || value.values!.isEmpty
        ? _Code.line('return')
        : _Code.compose(
            'return ', value.values!.map((e) => e.visit(this)), ', ', '');
    return _addComment(code, value.comment);
  }

  @override
  _Code visitAssign(Assign value) {
    final namesJoined = value.names.join(', ');
    final code = _Code.compose(
        value.isLocal ? 'local $namesJoined=' : '$namesJoined=',
        value.values.map((e) => e.visit(this)),
        ', ',
        '');
    return _addComment(code, value.comment);
  }

  @override
  _Code visitCall(Call value) {
    final code = _Code.compose(
        '${value.name}(', value.args.map((e) => e.visit(this)), ', ', ')');
    return _addComment(code, value.comment);
  }

  @override
  _Code visitCallExpression(CallExpression value) =>
      _Code.compose('(', [value.function.visit(this)], '', ')').joinInline(
          _Code.compose('(', value.args.map((e) => e.visit(this)), ', ', ')'));

  @override
  _Code visitCallFieldAccess(CallFieldAccess value) {
    final code = value.fieldAccess.visit(this).joinInline(
        _Code.compose('(', value.args.map((e) => e.visit(this)), ', ', ')'));
    return _addComment(code, value.comment);
  }

  @override
  _Code visitDo(Do value) =>
      _Code.withLines(['do', ...value.block.visit(this).indent().lines, 'end']);

  @override
  _Code visitWhile(While value) {
    return _Code.line('while ')
        .joinInline(value.condition.visit(this))
        .postfixLast(' do ')
        .joinDistinct(value.block.visit(this).indent())
        .joinDistinct(_Code.line('end'));
  }

  @override
  _Code visitRepeat(Repeat value) {
    return _Code.line('repeat')
        .joinDistinct(value.block.visit(this).indent())
        .joinDistinct(
            _Code.line('until ').joinInline(value.condition.visit(this)));
  }

  @override
  _Code visitIf(If value) {
    var v = _Code.line('if ')
        .joinInline(value.condition.visit(this))
        .postfixLast(' then')
        .joinDistinct(value.block.visit(this).indent());
    if (value.elseIfs != null) {
      for (final e in value.elseIfs!) {
        v = v.joinDistinct(_Code.line('elseif ')
            .joinInline(e.condition.visit(this))
            .joinDistinct(e.block.visit(this).indent()));
      }
    }
    if (value.elseBlock != null) {
      v = v.joinDistinct(_Code.line('else')
          .joinDistinct(value.elseBlock!.visit(this).indent()));
    }
    return v.joinDistinct(_Code.line('end'));
  }

  @override
  _Code visitFor(For value) {
    var v = _Code.line('for ${value.name} = ')
        .joinInline(value.init.visit(this))
        .postfixLast(', ')
        .joinInline(value.stop.visit(this));
    if (value.increment != null) {
      v = v.postfixLast(', ').joinInline(value.increment!.visit(this));
    }
    v = v
        .postfixLast(' do')
        .joinDistinct(value.block.visit(this).indent())
        .joinDistinct(_Code.line('end'));
    return v;
  }

  @override
  _Code visitForEach(ForEach value) {
    return _Code.compose('for ${value.names.join(', ')} in ',
            value.values.map((e) => e.visit(this)), ', ', ' do')
        .joinDistinct(value.block.visit(this).indent())
        .joinDistinct(_Code.line('end'));
  }

  @override
  _Code visitFunctionDef(FunctionDef value) {
    var v = _Code.line('function ${value.name}(${value.args.join(', ')})');
    if (value.isLocal) {
      v = v.prefixFirst('local ');
    }
    return v
        .joinDistinct(value.body.visit(this).indent())
        .joinDistinct(_Code.line('end'));
  }

  @override
  _Code visitInlineFunction(InlineFunction value) {
    return _Code.line('function(${value.args.join(', ')})')
        .joinDistinct(value.body.visit(this).indent())
        .joinDistinct(_Code.line('end'));
  }

  @override
  _Code visitNil(Nil value) => _addComment(_Code.line('nil'), value.comment);

  @override
  _Code visitBool(Bool value) => _Code.line(value.value ? 'true' : 'false');

  @override
  _Code visitNumber(Number value) => _Code.line(value.value.toString());

  @override
  _Code visitString(LuaString value) => _Code.line(
      '"${value.value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"');

  @override
  _Code visitNot(Not value) => value.value.visit(this).prefixFirst('not ');

  @override
  _Code visitVarRef(VarRef value) =>
      _addComment(_Code.line(value.name), value.comment);

  @override
  _Code visitAnd(And value) {
    return _Code.compose(
        '',
        value.items.map((e) => e is Literal
            ? e.visit(this)
            : e.visit(this).prefixFirst('(').postfixLast(')')),
        ' and ',
        '');
  }

  @override
  _Code visitOr(Or value) {
    return _Code.compose(
        '',
        value.items.map((e) => e is Literal
            ? e.visit(this)
            : e.visit(this).prefixFirst('(').postfixLast(')')),
        ' or ',
        '');
  }

  @override
  _Code visitTable(Table value) {
    var v = _Code.line('{');

    // Add fields with their comments
    for (var i = 0; i < value.fields.length; i++) {
      final field = value.fields[i];

      // Add preceding comments for this field (preceding block comments)
      if (field.comment != null && field.comment!.isNotEmpty) {
        final commentLines = field.comment!.split('\n');

        // Separate preceding comments from inline comments
        final precedingComments = <String>[];
        String? inlineComment;

        for (final line in commentLines) {
          if (line.trim().isEmpty) continue;
          // If it looks like an inline comment (single word/phrase), treat as inline
          if (commentLines.length == 1 || line.split(' ').length <= 3) {
            inlineComment ??= line;
          } else {
            // Multi-line or complex comments are treated as preceding
            precedingComments.add(line);
          }
        }

        // Add preceding comments before the field
        for (final comment in precedingComments) {
          v = v.joinDistinct(_Code.line('--$comment'));
        }

        // Store inline comment for later
        if (inlineComment != null && precedingComments.isEmpty) {
          // If no preceding comments, treat the single comment as inline
        }
      }

      // Add comma separator if not the first field
      if (i > 0) {
        v = v.postfixLast(', ');
      }

      // Add the field content
      if (field.index != null) {
        v = v
            .joinInline(_Code.line('['))
            .joinInline(field.index!.visit(this))
            .joinInline(_Code.line(']='));
      } else if (field.name != null) {
        v = v.postfixLast('${field.name}=');
      }
      v = v.joinInline(field.value.visit(this));

      // Add inline comment if present
      if (field.comment != null && field.comment!.isNotEmpty) {
        final commentLines = field.comment!.split('\n');
        // Use the last/single line as inline comment
        final lastComment = commentLines.last.trim();
        if (lastComment.isNotEmpty) {
          v = v.postfixLast(' --$lastComment');
        }
      }
    }

    return v.postfixLast('}');
  }

  @override
  _Code visitIndex(Index value) {
    return value.table
        .visit(this)
        .joinInline(_Code.line('['))
        .joinInline(value.key.visit(this))
        .joinInline(_Code.line(']'));
  }

  @override
  _Code visitFieldAccess(FieldAccess value) {
    return value.table
        .visit(this)
        .joinInline(_Code.line('.'))
        .joinInline(_Code.line(value.field));
  }

  @override
  _Code visitNegative(Negative value) =>
      value.value.visit(this).prefixFirst('-');

  @override
  _Code visitLength(Length value) => value.value.visit(this).prefixFirst('#');

  _Code _visitBinOp(Expression left, String operator, Expression right) =>
      left.visit(this).postfixLast(operator).joinInline(right.visit(this));

  @override
  _Code visitEquals(Equals value) => _visitBinOp(value.left, '==', value.right);

  @override
  _Code visitNotEquals(NotEquals value) =>
      _visitBinOp(value.left, '~=', value.right);

  @override
  _Code visitLess(Less value) => _visitBinOp(value.left, '<', value.right);

  @override
  _Code visitLessEq(LessEq value) => _visitBinOp(value.left, '<=', value.right);

  @override
  _Code visitGreater(Greater value) =>
      _visitBinOp(value.left, '>', value.right);

  @override
  _Code visitGreaterEq(GreaterEq value) =>
      _visitBinOp(value.left, '>=', value.right);

  @override
  _Code visitConcatenate(Concatenate value) =>
      _Code.compose('', value.values.map((v) => v.visit(this)), '..', '');

  @override
  _Code visitAdd(Add value) =>
      _Code.compose('', value.values.map((e) => e.visit(this)), '+', '');

  @override
  _Code visitSubtract(Subtract value) =>
      _visitBinOp(value.left, '-', value.right);

  @override
  _Code visitMultiply(Multiply value) =>
      _Code.compose('', value.values.map((e) => e.visit(this)), '*', '');

  @override
  _Code visitDivide(Divide value) => _visitBinOp(value.left, '/', value.right);

  @override
  _Code visitModulo(Modulo value) => _visitBinOp(value.left, '%', value.right);

  @override
  _Code visitExponent(Exponent value) =>
      _visitBinOp(value.left, '^', value.right);

  @override
  _Code visitSingleLineComment(SingleLineComment value) =>
      _Code.line('--${value.text}');

  @override
  _Code visitMultiLineComment(MultiLineComment value) =>
      _Code.line('--[[${value.text}]]');
}
