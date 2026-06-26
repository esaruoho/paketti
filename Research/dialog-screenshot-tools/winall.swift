import CoreGraphics
import Foundation
let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String:Any]]
for w in info {
  let o = w[kCGWindowOwnerName as String] as? String ?? ""
  if o != "Renoise" { continue }
  let n = w[kCGWindowName as String] as? String ?? "<NO-TITLE>"
  let num = w[kCGWindowNumber as String] as? Int ?? 0
  let b = w[kCGWindowBounds as String] as? [String:CGFloat] ?? [:]
  let layer = w[kCGWindowLayer as String] as? Int ?? 0
  print("id=\(num) layer=\(layer) size=\(Int(b["Width"] ?? 0))x\(Int(b["Height"] ?? 0)) title=\(n)")
}
