#!/home/cristian/.swift/tf-0.4.0-rc/usr/bin/swift

// import Commander
// import Foundation

// func slow() {
//     for i in 1 ... 100_000_000 {
//         var b = i + 1
//     }
// }

// let main = command(
//     Option("iterations", default: 100)
// ) {
//     iterations in

//     _ = (1 ... iterations)
//         .asyncFilter {
//             slow()
//             return $0 % 2 == 0
//         }
//         .asyncMap { (x: Int) -> Int in
//             slow()
//             return -x
//         }
//         .asyncFlatMap { (x: Int) -> [Int] in
//             slow()
//             return [x, 1 - x]
//         }
//         .asyncForEach {
//             slow()
//             print($0)
//         }
// }

// main.run()