import Time
import struct Core.EmptyID
import protocol Foundation.LocalizedError

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

 public init(
  _ id: ID,
  warmup: Size = 2,
  iterations: Size = 10,
  timeout: Double = 5.0,
  perform: @escaping () throws -> Result
 ) {
  self.id = id
  self.warmup = warmup
  self.iterations = iterations
  self.timeout = timeout
  self.perform = perform
 }

 public init(
  warmup: Size = 2,
  iterations: Size = 10,
  timeout: Double = 5.0,
  perform: @escaping () throws -> Result
 ) where ID == EmptyID {
  self.warmup = warmup
  self.iterations = iterations
  self.timeout = timeout
  self.perform = perform
 }

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

  public init(
   _ id: ID,
   warmup: Size = 2,
   iterations: Size = 10,
   timeout: Double = 5.0,
   perform: @escaping () async throws -> Result
  ) {
   self.id = id
   self.warmup = warmup
   self.iterations = iterations
   self.timeout = timeout
   self.perform = perform
  }

  public init(
   warmup: Size = 2,
   iterations: Size = 10,
   timeout: Double = 5.0,
   perform: @escaping () async throws -> Result
  ) where ID == EmptyID {
   self.warmup = warmup
   self.iterations = iterations
   self.timeout = timeout
   self.perform = perform
  }

  public func callAsyncBenchmark() async throws -> Result {
   try await perform()
  }
 }
}

public struct Benchmarks<ID: Hashable> {
 public var id: ID?
 // TODO: create a global iterations / timeout to override where they don't exist
 // a default to replace nil variables, even though some bencharks have a default
 // the goal is to keep benchmarks independent of this struct, but that may only
 // work if I conform benchmarks to function / async function as well
 public var setup: (() async throws -> ())?
 public var complete: (() async throws -> ())?
 public var cleanup: (() async throws -> ())?
 @BenchmarksBuilder public var items: () -> [any BenchmarkProtocol]

 public func setUp() async throws { try await setup?() }
 public func onCompletion() async throws { try await complete?() }
 public func cleanUp() async throws { try await cleanup?() }

 public init(
  _ id: ID,
  setUp: (() async throws -> ())? = nil,
  onCompletion: (() async throws -> ())? = nil,
  cleanUp: (() async throws -> ())? = nil,
  @BenchmarksBuilder _ benchmarks: @escaping () -> [any BenchmarkProtocol]
 ) {
  self.id = id
  self.setup = setUp
  self.complete = onCompletion
  self.cleanup = cleanUp
  self.items = benchmarks
 }

 public init(
  setUp: (() async throws -> ())? = nil,
  onCompletion: (() async throws -> ())? = nil,
  cleanUp: (() async throws -> ())? = nil,
  @BenchmarksBuilder _ benchmarks: @escaping () -> [any BenchmarkProtocol]
 ) where ID == EmptyID {
  self.setup = setUp
  self.complete = onCompletion
  self.cleanup = cleanUp
  self.items = benchmarks
 }

 public init(
  _ id: ID? = nil,
  setUp: (() async throws -> ())? = nil,
  onCompletion: (() async throws -> ())? = nil,
  cleanUp: (() async throws -> ())? = nil,
  _ items: any BenchmarkProtocol...
 ) {
  self.id = id
  self.setup = setUp
  self.complete = onCompletion
  self.cleanup = cleanUp
  self.items = { items }
 }

 public init(
  setUp: (() async throws -> ())? = nil,
  onCompletion: (() async throws -> ())? = nil,
  cleanUp: (() async throws -> ())? = nil,
  _ items: any BenchmarkProtocol...
 ) where ID == EmptyID {
  self.setup = setUp
  self.complete = onCompletion
  self.cleanup = cleanUp
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
  guard !items.isEmpty else { throw Error.empty }

  return try await withThrowingTaskGroup(of: (Int, TimedResults).self) { group in
   var results: [Int: TimedResults] = .empty
   for (offset, benchmark) in items.enumerated() {
    assert(benchmark.iterations > 0)

    @Sendable func time(
     _ function: @escaping () async throws -> Any
    ) async throws -> (Int, TimedResults) {
     // TODO: timeout individual benchmarks
     try await benchmark.setUp()

     if benchmark.iterations > 1 {
      var times: [Time] = []
      var results: [Any] = []

      // warmup time
      for _ in 0 ..< benchmark.warmup.rawValue {
       try await blackHole(function())
      }

      // benchmark time
      for _ in 0 ..< benchmark.iterations.rawValue {
       var timer = Timer()
       timer.fire()
       let result = try await function()
       times.append(timer.elapsed)
       results.append(result)
      }

      try await benchmark.onCompletion()
      return (
       offset,
       TimedResults(id: benchmark.benchmarkName, times: times, results: results)
      )
     } else {
      var timer = Timer()
      timer.fire()
      let result = try await function()

      try await benchmark.onCompletion()
      return (
       offset,
       TimedResults(
        id: benchmark.benchmarkName,
        times: [timer.elapsed], results: [result]
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
