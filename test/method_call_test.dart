import 'package:lua/lua.dart';
import 'package:test/test.dart';

void main() {
  group('method call parsing tests', () {
    test('parse standalone method call', () {
      final code = 'hub.call(id, "setValue2", target)';
      final ast = parse(code);

      expect(ast.statements.length, 1);
      expect(ast.statements.first, isA<CallFieldAccess>());

      final methodCall = ast.statements.first as CallFieldAccess;
      expect((methodCall.fieldAccess.table as VarRef).name, 'hub');
      expect(methodCall.fieldAccess.field, 'call');
      expect(methodCall.args.length, 3);
    });

    test('parse standalone method call with no arguments', () {
      final code = 'obj.method()';
      final ast = parse(code);

      expect(ast.statements.length, 1);
      expect(ast.statements.first, isA<CallFieldAccess>());

      final methodCall = ast.statements.first as CallFieldAccess;
      expect((methodCall.fieldAccess.table as VarRef).name, 'obj');
      expect(methodCall.fieldAccess.field, 'method');
      expect(methodCall.args.length, 0);
    });

    test('parse chained method calls as statement', () {
      final code = 'obj.getManager().doAction("test")';
      final ast = parse(code);

      expect(ast.statements.length, 1);
      expect(ast.statements.first, isA<CallFieldAccess>());

      final outerCall = ast.statements.first as CallFieldAccess;
      expect(outerCall.fieldAccess.field, 'doAction');
      expect((outerCall.args.first as LuaString).value, 'test');

      // The table should be another method call
      expect(outerCall.fieldAccess.table, isA<CallFieldAccess>());
      final innerCall = outerCall.fieldAccess.table as CallFieldAccess;
      expect((innerCall.fieldAccess.table as VarRef).name, 'obj');
      expect(innerCall.fieldAccess.field, 'getManager');
    });

    test('parse method call with complex arguments', () {
      final code = 'hub.call(obj.getId(), "method", 1 + 2)';
      final ast = parse(code);

      expect(ast.statements.length, 1);
      final methodCall = ast.statements.first as CallFieldAccess;
      expect(methodCall.args.length, 3);
      expect(methodCall.args[0], isA<CallFieldAccess>());
      expect(methodCall.args[1], isA<LuaString>());
      expect(methodCall.args[2], isA<Add>());
    });
    test('parse simple field access', () {
      final code = 'local x = obj.field';
      final ast = parse(code);

      expect(ast.statements.length, 1);
      final assignment = ast.statements.first as Assign;
      expect(assignment.values.first, isA<FieldAccess>());

      final fieldAccess = assignment.values.first as FieldAccess;
      expect((fieldAccess.table as VarRef).name, 'obj');
      expect(fieldAccess.field, 'field');
    });

    test('parse method call with no arguments', () {
      final code = 'local result = obj.method()';
      final ast = parse(code);

      final assignment = ast.statements.first as Assign;
      expect(assignment.values.first, isA<CallFieldAccess>());

      final methodCall = assignment.values.first as CallFieldAccess;
      expect((methodCall.fieldAccess.table as VarRef).name, 'obj');
      expect(methodCall.fieldAccess.field, 'method');
      expect(methodCall.args.length, 0);
    });

    test('parse method call with arguments', () {
      final code = 'local result = obj.method(1, "hello", true)';
      final ast = parse(code);

      final assignment = ast.statements.first as Assign;
      final methodCall = assignment.values.first as CallFieldAccess;

      expect(methodCall.args.length, 3);
      expect(methodCall.args[0], isA<Number>());
      expect((methodCall.args[0] as Number).value, 1);
      expect(methodCall.args[1], isA<LuaString>());
      expect((methodCall.args[1] as LuaString).value, 'hello');
      expect(methodCall.args[2], isA<Bool>());
      expect((methodCall.args[2] as Bool).value, true);
    });

    test('parse nested field access', () {
      final code = 'local x = obj.nested.field';
      final ast = parse(code);

      final assignment = ast.statements.first as Assign;
      expect(assignment.values.first, isA<FieldAccess>());

      final outerAccess = assignment.values.first as FieldAccess;
      expect(outerAccess.field, 'field');
      expect(outerAccess.table, isA<FieldAccess>());

      final innerAccess = outerAccess.table as FieldAccess;
      expect((innerAccess.table as VarRef).name, 'obj');
      expect(innerAccess.field, 'nested');
    });

    test('parse nested method call', () {
      final code = 'local result = obj.nested.method(42)';
      final ast = parse(code);

      final assignment = ast.statements.first as Assign;
      final methodCall = assignment.values.first as CallFieldAccess;

      expect(methodCall.args.length, 1);
      expect((methodCall.args.first as Number).value, 42);

      // The fieldAccess should be obj.nested.method
      final fieldAccess = methodCall.fieldAccess;
      expect(fieldAccess.field, 'method');
      expect(fieldAccess.table, isA<FieldAccess>());

      final nestedAccess = fieldAccess.table as FieldAccess;
      expect((nestedAccess.table as VarRef).name, 'obj');
      expect(nestedAccess.field, 'nested');
    });

    test('parse complex method call like hub.call', () {
      final code = 'local result = hub.call(id, "setValue2", target)';
      final ast = parse(code);

      final assignment = ast.statements.first as Assign;
      final methodCall = assignment.values.first as CallFieldAccess;

      expect((methodCall.fieldAccess.table as VarRef).name, 'hub');
      expect(methodCall.fieldAccess.field, 'call');
      expect(methodCall.args.length, 3);
      expect((methodCall.args[0] as VarRef).name, 'id');
      expect((methodCall.args[1] as LuaString).value, 'setValue2');
      expect((methodCall.args[2] as VarRef).name, 'target');
    });

    test('parse method call in return statement', () {
      final code = 'return math.abs(-5)';
      final ast = parse(code);

      expect(ast.statements.first, isA<Return>());
      final returnStmt = ast.statements.first as Return;
      expect(returnStmt.values?.first, isA<CallFieldAccess>());

      final methodCall = returnStmt.values?.first as CallFieldAccess;
      expect((methodCall.fieldAccess.table as VarRef).name, 'math');
      expect(methodCall.fieldAccess.field, 'abs');
      expect(methodCall.args.length, 1);
      expect(methodCall.args.first, isA<Negative>());
    });

    test('parse chained method calls', () {
      final code = 'local result = obj.getManager().doAction("test")';
      final ast = parse(code);

      final assignment = ast.statements.first as Assign;
      expect(assignment.values.first, isA<CallFieldAccess>());

      final outerCall = assignment.values.first as CallFieldAccess;
      expect(outerCall.fieldAccess.field, 'doAction');
      expect((outerCall.args.first as LuaString).value, 'test');

      // The table should be another method call
      expect(outerCall.fieldAccess.table, isA<CallFieldAccess>());
      final innerCall = outerCall.fieldAccess.table as CallFieldAccess;
      expect((innerCall.fieldAccess.table as VarRef).name, 'obj');
      expect(innerCall.fieldAccess.field, 'getManager');
      expect(innerCall.args.length, 0);
    });
  });

  group('method call evaluation tests', () {
    test('evaluate field access on table', () {
      final code = 'return obj.name';
      final ast = parse(code);

      final table = TableInstance.fromMap({'name': 'TestObject', 'value': 42});
      final env = LuaEnv(variables: {'obj': table});

      final result = ast.evaluate(env: env);
      expect(result, 'TestObject');
    });

    test('evaluate method call on external object', () {
      final code = 'return hub.getValue()';
      final ast = parse(code);

      final hub = TestHub();
      final env = LuaEnv(variables: {'hub': hub});

      final result = ast.evaluate(env: env);
      expect(result, 'Value from hub');
    });

    test('evaluate method call with arguments', () {
      final code = 'return hub.setValue("newValue")';
      final ast = parse(code);

      final hub = TestHub();
      final env = LuaEnv(variables: {'hub': hub});

      final result = ast.evaluate(env: env);
      expect(result, 'Set value to newValue');
    });

    test('evaluate complex method call like hub.call', () {
      final code = 'return hub.call(123, "setValue2", "target_value")';
      final ast = parse(code);

      final hub = TestHub();
      final env = LuaEnv(variables: {'hub': hub});

      final result = ast.evaluate(env: env);
      expect(result, 'Hub.call(id=123, method=setValue2, args=[target_value])');
    });

    test('evaluate nested field access', () {
      final code = 'return obj.config.enabled';
      final ast = parse(code);

      final config = TableInstance.fromMap({'enabled': true, 'timeout': 30});
      final obj = TableInstance.fromMap({'config': config, 'name': 'test'});
      final env = LuaEnv(variables: {'obj': obj});

      final result = ast.evaluate(env: env);
      expect(result, true);
    });

    test('evaluate method call on nested object', () {
      final code = 'return obj.manager.getName()';
      final ast = parse(code);

      final manager = TestManager('ManagerName');
      final obj = TableInstance.fromMap({'manager': manager});
      final env = LuaEnv(variables: {'obj': obj});

      final result = ast.evaluate(env: env);
      expect(result, 'Manager: ManagerName');
    });

    test('evaluate standalone method call', () {
      final code = 'hub.setValue("test")';
      final ast = parse(code);

      final hub = TestHub();
      final env = LuaEnv(variables: {'hub': hub});

      final result = ast.evaluate(env: env);
      expect(result, 'Set value to test');
    });

    test('evaluate chained method calls as statement', () {
      final code = 'obj.manager.getName()';
      final ast = parse(code);

      final manager = TestManager('ChainedManager');
      final obj = TableInstance.fromMap({'manager': manager});
      final env = LuaEnv(variables: {'obj': obj});

      final result = ast.evaluate(env: env);
      expect(result, 'Manager: ChainedManager');
    });
  });

  group('method call error handling tests', () {
    test('field access on non-table should throw error', () {
      final code = 'return value.field';
      final ast = parse(code);

      final env = LuaEnv(variables: {'value': 42});

      expect(() => ast.evaluate(env: env), throwsA(isA<EvaluationException>()));
    });

    test('method call on non-function should throw error', () {
      final code = 'return obj.field()';
      final ast = parse(code);

      final obj = TableInstance.fromMap({'field': 'not a function'});
      final env = LuaEnv(variables: {'obj': obj});

      expect(() => ast.evaluate(env: env), throwsA(isA<EvaluationException>()));
    });
  });
}

// Test external object implementation
class TestHub extends LuaExternalObject {
  final Map<String, dynamic> _properties = {
    'name': 'TestHub',
    'version': '1.0',
  };

  @override
  Object? call(List<Object?> args) {
    return 'Hub called with ${args.length} arguments';
  }

  @override
  Object? getProperty(String name) {
    switch (name) {
      case 'getValue':
        return (List<Object?> args) => 'Value from hub';
      case 'setValue':
        return (List<Object?> args) =>
            'Set value to ${args.isNotEmpty ? args.first : 'null'}';
      case 'call':
        return (List<Object?> args) {
          if (args.length >= 2) {
            final id = args[0];
            final method = args[1];
            final remaining = args.skip(2).toList();
            return 'Hub.call(id=$id, method=$method, args=$remaining)';
          }
          return 'Hub.call with insufficient args';
        };
      default:
        return _properties[name];
    }
  }

  @override
  void setProperty(String name, Object? value) {
    _properties[name] = value;
  }
}

// Test manager object
class TestManager extends LuaExternalObject {
  final String name;

  TestManager(this.name);

  @override
  Object? call(List<Object?> args) {
    return 'Manager called';
  }

  @override
  Object? getProperty(String name) {
    switch (name) {
      case 'getName':
        return (List<Object?> args) => 'Manager: ${this.name}';
      case 'name':
        return this.name;
      default:
        return null;
    }
  }

  @override
  void setProperty(String name, Object? value) {
    // Not implemented for this test
  }
}
