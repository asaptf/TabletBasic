import Foundation
import QBEngine

let code = """
            ' MATH.BAS - Expressions and functions
            A = 16
            PRINT "Square root of"; A; "is"; SQR(A)
            PRINT "10 MOD 3 ="; 10 MOD 3
            """

let interpreter = QBInterpreter()
let output = ConsoleOutputHandler()
interpreter.output = output
await interpreter.run(BasicSourceNormalizer.normalize(code))
print(output.buffer)
print(interpreter.lastError == nil ? "OK" : "FAIL: \(interpreter.lastError!)")
exit(interpreter.lastError == nil ? 0 : 1)