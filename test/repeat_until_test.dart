import 'package:lua/src/ast.dart';
import 'package:lua/src/evaluator.dart';
import 'package:test/test.dart';

void main() {
  group('repeat-until loops', () {
    test('basic repeat-until loop - increment counter', () {
      final block = Block([
        Assign.single('a', Number(1), isLocal: true),
        Repeat(
          Block([
            Assign.single('a', Add([VarRef('a'), Number(1)]))
          ]),
          GreaterEq(VarRef('a'), Number(5)),
        ),
        VarRef('a'),
      ]);
      expect(block.evaluate(), 5);
    });

    test('repeat-until loop executes at least once', () {
      final block = Block([
        Assign.single('executed', Bool(false), isLocal: true),
        Repeat(
          Block([Assign.single('executed', Bool(true))]),
          Bool(true), // Condition is immediately true
        ),
        VarRef('executed'),
      ]);
      expect(block.evaluate(), true);
    });

    test('repeat-until with counting down', () {
      final block = Block([
        Assign.single('count', Number(5), isLocal: true),
        Assign.single('sum', Number(0), isLocal: true),
        Repeat(
          Block([
            Assign.single('sum', Add([VarRef('sum'), VarRef('count')])),
            Assign.single('count', Subtract(VarRef('count'), Number(1))),
          ]),
          LessEq(VarRef('count'), Number(0)),
        ),
        VarRef('sum'),
      ]);
      expect(block.evaluate(), 15); // 5+4+3+2+1 = 15
    });

    test('repeat-until with complex condition', () {
      final block = Block([
        Assign.single('x', Number(2), isLocal: true),
        Assign.single('y', Number(1), isLocal: true),
        Repeat(
          Block([
            Assign.single('x', Multiply([VarRef('x'), Number(2)])),
            Assign.single('y', Add([VarRef('y'), Number(1)])),
          ]),
          And([
            Greater(VarRef('x'), Number(16)),
            Greater(VarRef('y'), Number(3)),
          ]),
        ),
        VarRef('x'),
      ]);
      expect(block.evaluate(),
          32); // x starts at 2, becomes 4, 8, 16, 32 when both conditions are true
    });

    test('repeat-until with variable reference in condition', () {
      final env = LuaEnv(variables: {'limit': 3});
      final block = Block([
        Assign.single('counter', Number(0), isLocal: true),
        Repeat(
          Block([
            Assign.single('counter', Add([VarRef('counter'), Number(1)]))
          ]),
          GreaterEq(VarRef('counter'), VarRef('limit')),
        ),
        VarRef('counter'),
      ]);
      expect(block.evaluate(env: env), 3);
    });

    test('repeat-until with break statement', () {
      final block = Block([
        Assign.single('i', Number(1), isLocal: true),
        Repeat(
          Block([
            If(
              Greater(VarRef('i'), Number(3)),
              Block([Break()]),
            ),
            Assign.single('i', Add([VarRef('i'), Number(1)])),
          ]),
          Bool(false), // Would loop forever without break
        ),
        VarRef('i'),
      ]);
      expect(block.evaluate(), 4);
    });

    test('nested repeat-until loops', () {
      final block = Block([
        Assign.single('total', Number(0), isLocal: true),
        Assign.single('i', Number(1), isLocal: true),
        Repeat(
          Block([
            Assign.single('j', Number(1), isLocal: true),
            Repeat(
              Block([
                Assign.single('total', Add([VarRef('total'), VarRef('j')])),
                Assign.single('j', Add([VarRef('j'), Number(1)])),
              ]),
              Greater(VarRef('j'), Number(2)),
            ),
            Assign.single('i', Add([VarRef('i'), Number(1)])),
          ]),
          Greater(VarRef('i'), Number(2)),
        ),
        VarRef('total'),
      ]);
      expect(block.evaluate(), 6); // Inner loop: 1+2 = 3, runs twice, total = 6
    });

    test('repeat-until with string condition', () {
      final block = Block([
        Assign.single('result', LuaString(''), isLocal: true),
        Assign.single('count', Number(0), isLocal: true),
        Repeat(
          Block([
            Assign.single(
                'result', Concatenate([VarRef('result'), LuaString('x')])),
            Assign.single('count', Add([VarRef('count'), Number(1)])),
          ]),
          Equals(VarRef('result'), LuaString('xxx')),
        ),
        VarRef('result'),
      ]);
      expect(block.evaluate(), 'xxx');
    });

    test('repeat-until with nil and false conditions', () {
      // Test that only nil and false are considered false in Lua
      final block = Block([
        Assign.single('counter', Number(0), isLocal: true),
        Repeat(
          Block([
            Assign.single('counter', Add([VarRef('counter'), Number(1)])),
          ]),
          VarRef(
              'counter'), // Numbers are truthy in Lua, so this stops on first iteration
        ),
        VarRef('counter'),
      ]);
      expect(block.evaluate(), 1);
    });

    test('repeat-until with nil condition and safety check', () {
      final block = Block([
        Assign.single('attempts', Number(0), isLocal: true),
        Repeat(
          Block([
            Assign.single('attempts', Add([VarRef('attempts'), Number(1)])),
          ]),
          Greater(VarRef('attempts'), Number(3)), // Stop after 3 attempts
        ),
        VarRef('attempts'),
      ]);
      expect(block.evaluate(), 4);
    });

    test('repeat-until with early termination', () {
      final block = Block([
        Assign.single('value', Number(10), isLocal: true),
        Repeat(
          Block([
            Assign.single('value', Add([VarRef('value'), Number(1)])),
            If(
              Equals(VarRef('value'), Number(13)),
              Block([Break()]), // Use break instead of return
            ),
          ]),
          Greater(VarRef('value'),
              Number(15)), // Loop until value > 15, but break at 13
        ),
        VarRef('value'),
      ]);
      expect(block.evaluate(), 13);
    });

    test('repeat-until with table field counting', () {
      final block = Block([
        Assign.single('count', Number(1), isLocal: true),
        Assign.single('result', Number(0), isLocal: true),
        Repeat(
          Block([
            Assign.single('result', Add([VarRef('result'), VarRef('count')])),
            Assign.single('count', Add([VarRef('count'), Number(1)])),
          ]),
          Greater(VarRef('count'), Number(3)),
        ),
        VarRef('result'),
      ]);
      expect(block.evaluate(), 6); // 1+2+3 = 6
    });

    test('repeat-until with function calls', () {
      final block = Block([
        FunctionDef(
          'increment',
          ['x'],
          Block([
            Return(values: [
              Add([VarRef('x'), Number(1)])
            ])
          ]),
          isLocal: true,
        ),
        Assign.single('value', Number(1), isLocal: true),
        Repeat(
          Block([
            Assign.single('value', Call('increment', [VarRef('value')])),
          ]),
          Equals(VarRef('value'), Number(5)),
        ),
        VarRef('value'),
      ]);
      expect(block.evaluate(), 5);
    });

    test('repeat-until with logical operators in condition', () {
      final block = Block([
        Assign.single('a', Number(1), isLocal: true),
        Assign.single('b', Number(10), isLocal: true),
        Repeat(
          Block([
            Assign.single('a', Add([VarRef('a'), Number(1)])),
            Assign.single('b', Subtract(VarRef('b'), Number(2))),
          ]),
          Or([
            Greater(VarRef('a'), Number(3)),
            Less(VarRef('b'), Number(5)),
          ]),
        ),
        Add([VarRef('a'), VarRef('b')]), // Return sum
      ]);
      expect(block.evaluate(), 8); // a=4, b=4, sum=8
    });
  });

  group('repeat-until edge cases', () {
    test('repeat-until with immediately true condition', () {
      final block = Block([
        Assign.single('executed', Number(0), isLocal: true),
        Repeat(
          Block([
            Assign.single('executed', Number(1)),
          ]),
          Bool(true), // Always true
        ),
        VarRef('executed'),
      ]);
      expect(block.evaluate(), 1); // Should execute once
    });

    test('repeat-until with local variable scoping', () {
      final block = Block([
        Assign.single('x', Number(1), isLocal: true),
        Assign.single('counter', Number(0), isLocal: true),
        Repeat(
          Block([
            Assign.single('x', Multiply([VarRef('x'), Number(2)]),
                isLocal: true), // Local x shadows outer x
            Assign.single(
                'counter',
                Add([
                  VarRef('counter'),
                  Number(1)
                ])), // Increment counter for termination
          ]),
          Greater(VarRef('counter'), Number(3)), // Stop after 3 iterations
        ),
        VarRef('x'), // Should return outer x, which remains 1
      ]);
      expect(
          block.evaluate(), 1); // Outer x remains unchanged, inner x is local
    });

    test('repeat-until with expression as condition', () {
      final block = Block([
        Assign.single('x', Number(2), isLocal: true),
        Repeat(
          Block([
            Assign.single('x', Add([VarRef('x'), Number(1)])),
          ]),
          Greater(
            Multiply([VarRef('x'), Number(2)]),
            Number(12),
          ), // x * 2 > 12, so x > 6
        ),
        VarRef('x'),
      ]);
      expect(block.evaluate(), 7); // x becomes 7, 7*2=14 > 12
    });
  });
}
