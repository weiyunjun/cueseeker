import Foundation
import CueSeekerCore

let path = URL(fileURLWithPath: CommandLine.arguments[1])
try DatabaseBootstrap.prepare(at: path)
print("migrated to schema \(DatabaseBootstrap.currentSchemaVersion)")
