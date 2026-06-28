// Lists Renoise dialog windows (layer >= 3, so the main window and Scripting Terminal at
// layer 0 are excluded — robust across machines, no title matching). Front-to-back order,
// so the FIRST line is the frontmost dialog. Output: "<windowID>\t<title>" per line.
import CoreGraphics
import Foundation
let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String:Any]]
for w in info {
  let o = w[kCGWindowOwnerName as String] as? String ?? ""
  let n = w[kCGWindowName as String] as? String ?? ""
  let num = w[kCGWindowNumber as String] as? Int ?? 0
  let layer = w[kCGWindowLayer as String] as? Int ?? 0
  if o == "Renoise" && !n.isEmpty && layer >= 3 {
    print("\(num)\t\(n)")
  }
}
