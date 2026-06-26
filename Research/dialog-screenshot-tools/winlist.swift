import CoreGraphics
import Foundation
let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String:Any]]
for w in info {
  let o = w[kCGWindowOwnerName as String] as? String ?? ""
  let n = w[kCGWindowName as String] as? String ?? ""
  let num = w[kCGWindowNumber as String] as? Int ?? 0
  if o == "Renoise" && !n.isEmpty && n != "Renoise (Arm64)" && !n.contains("Scripting Terminal") {
    print("\(num)\t\(n)")
  }
}
