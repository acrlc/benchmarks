import struct Core.EmptyID
import protocol Foundation.LocalizedError
import Time
import Utilities

protocol Benchmark: BenchmarkProtocol {
 associatedtype Result
 func callAsBenchmark() throws -> Result
}

public protocol AsyncBenchmark: BenchmarkProtocol where Result: Sendable {
 associatedtype Result
 func callAsyncBenchmark() async throws -> Result
}

public struct Measure<ID: Hashable, Result>: Benchmark {
 public var id: ID?
 public let warmup: Size
 public let iterations: Size
 public let timeout: Double
 let perform: () throws -> Result

 var setUpHandler: (() async throws -> ())?
 var onCompletionHandler: (() async throws -> ())?
 var cleanUpHandler: (() async throws -> ())?

 @inline(__always)
 public func cleanUp() async throws {
  try await cleanUpHandler?()
 }

 @inline(__always)
 public func onCompletion() async throws {
  try await onCompletionHandler?()
 }

 @inline(__always)
 public func setUp() async throws {
  try await setUpHandler?()
 }

 public init(
  _ id: ID,
  warmup: Size = .zero,
  iterations: Size = 10,
  timeout: Double = 5.0,
  perform: @escaping () throws -> Result,
  setUp: (() async throws -> ())? = nil,
  onCompletion: (() async throws -> ())? = nil,
  cleanUp: (() async throws -> ())? = nil
 ) {
  self.id = id
  self.warmup = warmup
  self.iterations = iterations
  self.timeout = timeout
  self.perform = perform
  setUpHandler = setUp
  onCompletionHandler = onCompletion
  cleanUpHandler = cleanUp
 }

 public init(
  warmup: Size = .zero,
  iterations: Size = 10,
  timeout: Double = 5.0,
  perform: @escaping () throws -> Result,
  setUp: (() async throws -> ())? = nil,
  onCompletion: (() async throws -> ())? = nil,
  cleanUp: (() async throws -> ())? = nil
 ) where ID == EmptyID {
  self.warmup = warmup
  self.iterations = iterations
  self.timeout = timeout
  self.perform = perform
  setUpHandler = setUp
  onCompletionHandler = onCompletion
  cleanUpHandler = cleanUp
 }

 @inline(__always)
 public func callAsBenchmark() throws -> Result {
  try perform()
 }
}

public extension Measure {
 struct Async: AsyncBenchmark {
  public var id: ID?
  public let warmup: Size
  public let iterations: Size
  public let timeout: Double
  let perform: () async throws -> Result

  var setUpHandler: (() async throws -> ())?
  var onCompletionHandler: (() async throws -> ())?
  var cleanUpHandler: (() async throws -> ())?

  @inline(__always)
  public func cleanUp() async throws {
   try await cleanUpHandler?()
  }

  @inline(__always)
  public func onCompletion() async throws {
   try await onCompletionHandler?()
  }

  @inline(__always)
  public func setUp() async throws {
   try await setUpHandler?()
  }

  public init(
   _ id: ID,
   warmup: Size = .zero,
   iterations: Size = 10,
   timeout: Double = 5.0,
   perform: @escaping () async throws -> Result,
   setUp: (() async throws -> ())? = nil,
   onCompletion: (() async throws -> ())? = nil,
   cleanUp: (() async throws -> ())? = nil
  ) {
   self.id = id
   self.warmup = warmup
   self.iterations = iterations
   self.timeout = timeout
   self.perform = perform
   setUpHandler = setUp
   onCompletionHandler = onCompletion
   cleanUpHandler = cleanUp
  }

  public init(
   warmup: Size = .zero,
   iterations: Size = 10,
   timeout: Double = 5.0,
   perform: @escaping () async throws -> Result,
   setUp: (() async throws -> ())? = nil,
   onCompletion: (() async throws -> ())? = nil,
   cleanUp: (() async throws -> ())? = nil
  ) where ID == EmptyID {
   self.warmup = warmup
   self.iterations = iterations
   self.timeout = timeout
   self.perform = perform
   setUpHandler = setUp
   onCompletionHandler = onCompletion
   cleanUpHandler = cleanUp
  }

  @inline(__always)
  public func callAsyncBenchmark() async throws -> Result {
   try await perform()
  }
 }
}

public struct Benchmarks<ID: Hashable> {
 public var id: ID?
 public var sourceLocation: SourceLocation?
 // TODO: create a global iterations / timeout to override where they don't exist
 // a default to replace nil variables, even though some bencharks have a
 // default
 // the goal is to keep benchmarks independent of this struct, but that may only
 // work if I conform benchmarks to function / async function as well
 public var setup: (() async throws -> ())?
 public var complete: (() async throws -> ())?
 public var cleanup: (() async throws -> ())?
 @BenchmarksBuilder
 public var items: () -> [any BenchmarkProtocol]

 public func setUp() async throws { try await setup?() }
 public func onCompletion() async throws { try await complete?() }
 public func cleanUp() async throws { try await cleanup?() }

 public init(
  _ id: ID,
  fileID: String = #fileID,
  line: Int = #line,
  column: Int = #column,
  setUp: (() async throws -> ())? = nil,
  onCompletion: (() async throws -> ())? = nil,
  cleanUp: (() async throws -> ())? = nil,
  @BenchmarksBuilder _ benchmarks: @escaping () -> [any BenchmarkProtocol]
 ) {
  self.id = id
  sourceLocation = SourceLocation(
   fileID: fileID,
   line: line,
   column: column
  )
  setup = setUp
  complete = onCompletion
  cleanup = cleanUp
  items = benchmarks
 }

 public init(
  fileID: String = #fileID,
  line: Int = #line,
  column: Int = #column,
  setUp: (() async throws -> ())? = nil,
  onCompletion: (() async throws -> ())? = nil,
  cleanUp: (() async throws -> ())? = nil,
  @BenchmarksBuilder _ benchmarks: @escaping () -> [any BenchmarkProtocol]
 ) where ID == EmptyID {
  sourceLocation = SourceLocation(
   fileID: fileID,
   line: line,
   column: column
  )
  setup = setUp
  complete = onCompletion
  cleanup = cleanUp
  items = benchmarks
 }

 public init(
  _ id: ID? = nil,
  fileID: String = #fileID,
  line: Int = #line,
  column: Int = #column,
  setUp: (() async throws -> ())? = nil,
  onCompletion: (() async throws -> ())? = nil,
  cleanUp: (() async throws -> ())? = nil,
  _ items: any BenchmarkProtocol...
 ) {
  self.id = id
  sourceLocation = SourceLocation(
   fileID: fileID,
   line: line,
   column: column
  )
  setup = setUp
  complete = onCompletion
  cleanup = cleanUp
  self.items = { items }
 }

 public init(
  fileID: String = #fileID,
  line: Int = #line,
  column: Int = #column,
  setUp: (() async throws -> ())? = nil,
  onCompletion: (() async throws -> ())? = nil,
  cleanUp: (() async throws -> ())? = nil,
  _ items: any BenchmarkProtocol...
 ) where ID == EmptyID {
  sourceLocation = SourceLocation(
   fileID: fileID,
   line: line,
   column: column
  )
  setup = setUp
  complete = onCompletion
  cleanup = cleanUp
  self.items = { items }
 }

 public enum Error: LocalizedError, CustomStringConvertible {
  case empty
  public var errorDescription: String? {
   "Benchmark is empty"
  }

  public var description: String { errorDescription! }
 }

 @discardableResult
 // TODO: apply conditions such as expected returns and specific inputs
 public func callAsFunction() async throws -> [Int: TimedResults] {
  let items = items()
  guard !items.isEmpty else {
   throw Error.empty
  }

  return try await withThrowingTaskGroup(
   of: (Int, TimedResults)
    .self
  ) { group in
   var results: [Int: TimedResults] = .empty
   for (offset, benchmark) in items.enumerated() {
    assert(benchmark.iterations > 0)

    @Sendable
    func time(
     _ function: @escaping () async throws -> Any
    ) async throws -> (Int, TimedResults) {
     // TODO: timeout individual benchmarks
     try await benchmark.setUp()

     if benchmark.iterations > 1 {
      var times: [Time] = []
      var results: [Any] = []

      // warmup time
      for _ in 0 ..< benchmark.warmup.rawValue {
       _ = try await function()
       try await benchmark.onCompletion()
      }

      // benchmark time
      for _ in 0 ..< benchmark.iterations.rawValue {
       var timer = Timer()
       timer.fire()
       let result = try await function()
       times.append(timer.elapsed)
       results.append(result)
       try await benchmark.onCompletion()
      }

      return (
       offset,
       TimedResults(id: benchmark.benchmarkName, times: times, results: results)
      )
     } else {
      var timer = Timer()
      timer.fire()
      let result = try await function()
      let time = timer.elapsed

      try await benchmark.onCompletion()
      return (
       offset,
       TimedResults(
        id: benchmark.benchmarkName,
        times: [time], results: [result]
       )
      )
     }
    }

    if let benchmark = benchmark as? any AsyncBenchmark {
     group.addTask { try await time(benchmark.callAsyncBenchmark) }
    } else if let benchmark = benchmark as? any Benchmark {
     group.addTask { try await time(benchmark.callAsBenchmark) }
    }
   }

   while results.count < items.count {
    if let (offset, timedResults) = try await group.next() {
     results[offset] = timedResults
     try await items[offset].cleanUp()
    }
   }
   return results
  }
 }
}

@resultBuilder
public enum BenchmarksBuilder {
 public static func buildBlock(
  _ components: (any BenchmarkProtocol)...
 ) -> [any BenchmarkProtocol] {
  components
 }
}
