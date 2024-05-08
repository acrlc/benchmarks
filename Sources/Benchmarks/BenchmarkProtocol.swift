import struct Time.Size
import Utilities

/// A basic protocol for measuring performance on an algorithm
public protocol BenchmarkProtocol: Identifiable {
 /// The number of times to warmup before benchmarking an algorithm
 var warmup: Size { get }
 /// The number of times to benchmark an algorithm
 var iterations: Size { get }
 // WARNING: not implemented
 /// The threshold for the benchmark to cancel
 var timeout: Double { get }
 var benchmarkName: String? { get }
 var sourceLocation: SourceLocation? { get }
 func setUp() async throws
 func cleanUp() async throws
 /// Performs when a benchmark completes successfully
 func onCompletion() async throws
}

public extension BenchmarkProtocol {
 @_disfavoredOverload
 var sourceLocation: SourceLocation? { nil }
 @_disfavoredOverload
 var warmup: Size { 0 }
 @_disfavoredOverload
 var iterations: Size { 0 }
 @_disfavoredOverload
 var timeout: Double { 0 }
 @_disfavoredOverload
 var benchmarkName: String? { nil }
 @_disfavoredOverload
 func setUp() {}
 @_disfavoredOverload
 func cleanUp() {}
 @_disfavoredOverload
 func onCompletion() {}
}

public extension BenchmarkProtocol where ID: ExpressibleByNilLiteral {
 @_disfavoredOverload
 var benchmarkName: String? {
  nil ~= id ? nil : String(describing: id).readableRemovingQuotes
 }
}

import struct Core.EmptyID
public extension BenchmarkProtocol where ID == EmptyID {
 @_disfavoredOverload
 var id: EmptyID { EmptyID(placeholder: "\(Self.self)") }
}
