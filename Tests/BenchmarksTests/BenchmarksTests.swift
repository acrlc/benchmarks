@testable import Benchmarks
import XCTest

final class BenchmarksTests: XCTestCase {
 func testBenchmarkMeasure() async throws {
  let integers = [9, 8, 7, 6, 5, 4, 3, 2, 1, 0]
  func sort(_ integers: [Int]) -> [Int] { integers.sorted() }

  let benchmarks = Benchmarks("Testing") {
   Measure("ReversedSort 1", iterations: 9999) { sort(integers.reversed()) }
   Measure("Sort 1", iterations: 9999) { sort(integers) }
   Measure("ReversedSort 2", iterations: 9999) { sort(integers.reversed()) }
   Measure("Sort 2", iterations: 9999) { sort(integers) }
  }

  // accumulated results
  let results = try await benchmarks()
  // print results
  for offset in results.keys.sorted() {
   let result = results[offset]!
   let title = result.id ?? "benchmark " + (offset + 1).description
   let total = result.total
   let average = result.average
   print("time for \(title) was \(total)")
   print("average time for \(title) was \(average)")
   print("results are: \(result.results[0])\n")
  }
 }
}
