import AppKit
import CoreText
let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/private/tmp/fryday-screenshots")
let w = 1284, h = 2778
func color(_ r: CGFloat,_ g: CGFloat,_ b: CGFloat) -> NSColor { NSColor(srgbRed:r/255,green:g/255,blue:b/255,alpha:1) }
let ink = color(33,41,49)
func text(_ s:String, _ rect:NSRect, _ size:CGFloat, _ weight:NSFont.Weight, _ c:NSColor, spacing:CGFloat=0) {
 let p=NSMutableParagraphStyle(); p.alignment = .center; p.lineSpacing=spacing
 let att=NSAttributedString(string:s,attributes:[.font:NSFont.systemFont(ofSize:size,weight:weight),.foregroundColor:c,.paragraphStyle:p,.kern: -0.8])
 let ctx=NSGraphicsContext.current!.cgContext
 ctx.saveGState(); ctx.translateBy(x:rect.minX,y:rect.maxY); ctx.scaleBy(x:1,y:-1); ctx.textMatrix = .identity
 let frame=CTFramesetterCreateFrame(CTFramesetterCreateWithAttributedString(att),CFRange(location:0,length:0),CGPath(rect:CGRect(x:0,y:0,width:rect.width,height:rect.height),transform:nil),nil)
 CTFrameDraw(frame,ctx); ctx.restoreGState()
}

func opaquePNG(_ source:NSBitmapImageRep) -> Data {
 let out=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:source.pixelsWide,pixelsHigh:source.pixelsHigh,bitsPerSample:8,samplesPerPixel:3,hasAlpha:false,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
 for y in 0..<source.pixelsHigh { for x in 0..<source.pixelsWide { let a=y*source.bytesPerRow+x*4; let b=y*out.bytesPerRow+x*3; for c in 0..<3 { out.bitmapData![b+c]=source.bitmapData![a+c] } } }
 return out.representation(using:.png,properties:[:])!
}
let items = [
("01-home", "Track vitamin D.\nStay sun-aware.", "Monitor UV and time in the sun."),
("02-live-activity", "Your session.\nAt a glance.", "Follow your timer from the Lock Screen."),
("03-history", "Keep a record.\nKeep it simple.", "Your saved sessions, right on your phone.")
]
for (id,title,subtitle) in items {
 let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:w,pixelsHigh:h,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
 NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current=NSGraphicsContext(cgContext:NSGraphicsContext(bitmapImageRep:rep)!.cgContext,flipped:true)
 let flip=NSAffineTransform(); flip.translateX(by:0,yBy:CGFloat(h)); flip.scaleX(by:1,yBy:-1); flip.concat()
 NSGradient(starting:color(255,219,173),ending:color(245,172,112))!.draw(in:NSRect(x:0,y:0,width:w,height:h),angle:90)
 text(title,NSRect(x:65,y:185,width:1154,height:250),98,.bold,ink,spacing:0)
 text(subtitle,NSRect(x:100,y:445,width:1084,height:120),46,.medium,ink.withAlphaComponent(0.85),spacing:2)
 let img=NSImage(contentsOf:root.appendingPathComponent("raw/\(id).png"))!
 let iw:CGFloat=936; let ih=iw*2622/1206
 let screen=NSRect(x:(CGFloat(w)-iw)/2,y:594,width:iw,height:ih)
 let frame=screen.insetBy(dx:-17,dy:-17)
 NSGraphicsContext.saveGraphicsState()
 let shadow=NSShadow(); shadow.shadowColor=ink.withAlphaComponent(0.28); shadow.shadowBlurRadius=45; shadow.shadowOffset=NSSize(width:0,height:18); shadow.set()
 ink.setFill(); NSBezierPath(roundedRect:frame,xRadius:117,yRadius:117).fill()
 NSGraphicsContext.restoreGraphicsState()
 NSGraphicsContext.saveGraphicsState(); NSBezierPath(roundedRect:screen,xRadius:100,yRadius:100).addClip()
 img.draw(in:screen,from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:[.interpolation:NSImageInterpolation.high])
 NSGraphicsContext.restoreGraphicsState()
 // Promotional overlay in the unused area of the history capture only.
 if id == "03-history" {
     NSGraphicsContext.saveGraphicsState()
     let transform = NSAffineTransform()
     transform.translateX(by: 592, yBy: 1770)
     transform.scaleX(by: 100.0 / 60.0, yBy: 100.0 / 60.0)
     transform.concat()
     NSColor.white.setFill()
     NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: 60, height: 60), xRadius: 14, yRadius: 14).fill()
     let heart = NSBezierPath()
     heart.move(to: NSPoint(x: 30, y: 47))
     heart.curve(to: NSPoint(x: 9, y: 22), controlPoint1: NSPoint(x: 22, y: 40), controlPoint2: NSPoint(x: 9, y: 33))
     heart.curve(to: NSPoint(x: 30, y: 18), controlPoint1: NSPoint(x: 9, y: 7), controlPoint2: NSPoint(x: 25, y: 7))
     heart.curve(to: NSPoint(x: 51, y: 22), controlPoint1: NSPoint(x: 35, y: 7), controlPoint2: NSPoint(x: 51, y: 7))
     heart.curve(to: NSPoint(x: 30, y: 47), controlPoint1: NSPoint(x: 51, y: 33), controlPoint2: NSPoint(x: 38, y: 40))
     heart.close()
     NSGradient(starting: color(255, 83, 153), ending: color(255, 47, 78))!.draw(in: heart, angle: 90)
     NSGraphicsContext.restoreGraphicsState()
     text("Save vitamin D estimates\nto Apple Health.", NSRect(x: 222, y: 1930, width: 840, height: 180), 62, .semibold, .white, spacing: 8)
     text("Optional export from your saved sessions.", NSRect(x: 222, y: 2120, width: 840, height: 60), 31, .regular, NSColor.white.withAlphaComponent(0.7))
 }

 NSGraphicsContext.restoreGraphicsState()
 try opaquePNG(rep).write(to:root.appendingPathComponent("\(id).png"))
}
// Small overview for review; upload the individual full-resolution files.
let overview=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:428 * items.count,pixelsHigh:926,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:overview)
for (i,item) in items.enumerated() { NSImage(contentsOf:root.appendingPathComponent("\(item.0).png"))!.draw(in:NSRect(x:i*428,y:0,width:428,height:926)) }
NSGraphicsContext.restoreGraphicsState()
try opaquePNG(overview).write(to:root.appendingPathComponent("preview.png"))
