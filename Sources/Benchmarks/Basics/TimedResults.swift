import Time
public struct TimedResults {
 public var id: String?
 public let times: [Time]
 public let results: [Any]

 public var size: Size { Size(times.count) }
 public var total: Time {
  times.reduce(Time.zero) { Time($0.seconds + $1.seconds) }
 }

 public var average: Time { total.amortized(over: size) }
 
 public init(id: String?, times: [Time], results: [Any]) {
  if let id { self.id = id  == "nil" ? nil : id }
  self.times = times
  self.results = results
 }
}
