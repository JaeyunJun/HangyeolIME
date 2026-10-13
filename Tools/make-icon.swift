//
//  make-icon.swift
//  HangyeolIME 입력기 아이콘 생성
//
//  메뉴 막대·입력 소스 설정에 보이는 아이콘. 투명 배경에 검은 '가'만 그린 템플릿 이미지라,
//  Info.plist의 TISIconIsTemplate과 함께 macOS가 다크·라이트 모드에 맞춰 색을 입힌다.
//
//  사용: swift Tools/make-icon.swift HangyeolIME/hangyeol.tiff
//

import AppKit

let points = 16                     // 메뉴 막대 아이콘 크기(pt)
let fontScale: CGFloat = 0.8        // 칸 대비 글자 크기. 다른 메뉴 막대 아이콘과 비슷한 여백.

func draw(pixels: Int, fontSize: CGFloat, at origin: NSPoint) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let font = NSFont(name: "AppleSDGothicNeo-Medium", size: fontSize)!
    NSAttributedString(string: "가", attributes: [.font: font, .foregroundColor: NSColor.black]).draw(at: origin)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

// 실제로 칠해진 픽셀의 외곽. 아래가 0인 좌표로 돌려준다(그리기 좌표와 같게).
func ink(_ rep: NSBitmapImageRep) -> (left: Int, bottom: Int, width: Int, height: Int) {
    var minX = Int.max, maxX = -1, minRow = Int.max, maxRow = -1
    for row in 0..<rep.pixelsHigh {
        for x in 0..<rep.pixelsWide where rep.colorAt(x: x, y: row)!.alphaComponent > 0.15 {
            minX = min(minX, x); maxX = max(maxX, x); minRow = min(minRow, row); maxRow = max(maxRow, row)
        }
    }
    return (minX, rep.pixelsHigh - 1 - maxRow, maxX - minX + 1, maxRow - minRow + 1)
}

// 글꼴 지표가 아니라 실제 잉크 외곽으로 가운데 정렬한다.
func render(scale: Int) -> NSBitmapImageRep {
    let pixels = points * scale
    let fontSize = CGFloat(pixels) * fontScale
    let probeOrigin = NSPoint(x: CGFloat(pixels) / 2, y: CGFloat(pixels) / 2)
    let measured = ink(draw(pixels: pixels * 2, fontSize: fontSize, at: probeOrigin))
    let origin = NSPoint(x: probeOrigin.x + CGFloat(pixels - measured.width) / 2 - CGFloat(measured.left),
                         y: probeOrigin.y + CGFloat(pixels - measured.height) / 2 - CGFloat(measured.bottom))
    let rep = draw(pixels: pixels, fontSize: fontSize, at: origin)
    rep.size = NSSize(width: points, height: points)
    return rep
}

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "hangyeol.tiff"
let image = NSImage(size: NSSize(width: points, height: points))
image.addRepresentation(render(scale: 1))
image.addRepresentation(render(scale: 2))
try! image.tiffRepresentation!.write(to: URL(fileURLWithPath: output))
print("만듦: \(output) (16pt, @1x·@2x)")
