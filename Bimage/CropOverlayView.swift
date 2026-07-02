import SwiftUI

struct CropOverlayView: View {
    @Binding var cropRect: CGRect
    var imageFrame: CGRect

    private let cornerHandleSize: CGFloat = 24
    private let edgeHandleThickness: CGFloat = 32
    private let edgeHandleLength: CGFloat = 60
    private let edgeVisibleThickness: CGFloat = 4
    private let minCropSize: CGFloat = 0.1

    @GestureState private var bodyDragStart: CGRect?

    var body: some View {
        GeometryReader { geometry in
            let rect = denormalizedRect(in: geometry.size)

            ZStack {
                Color.black.opacity(0.5)
                    .mask {
                        Rectangle()
                            .fill(Color.white)
                            .overlay {
                                Rectangle()
                                    .frame(width: rect.width, height: rect.height)
                                    .position(x: rect.midX, y: rect.midY)
                                    .blendMode(.destinationOut)
                            }
                    }

                Color.white.opacity(0.001)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .updating($bodyDragStart) { _, state, _ in
                                if state == nil { state = cropRect }
                            }
                            .onChanged { value in
                                guard let start = bodyDragStart else { return }
                                moveBody(from: start, with: value.translation)
                            }
                    )

                Rectangle()
                    .strokeBorder(Color.white, lineWidth: 2)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .allowsHitTesting(false)

                ForEach(Corner.allCases, id: \.self) { corner in
                    CornerHandleView(
                        corner: corner,
                        rect: rect,
                        handleSize: cornerHandleSize,
                        cropRect: $cropRect,
                        minCropSize: minCropSize,
                        imageFrame: imageFrame
                    )
                }

                ForEach(Edge.allCases, id: \.self) { edge in
                    EdgeHandleView(
                        edge: edge,
                        rect: rect,
                        hitThickness: edgeHandleThickness,
                        visibleThickness: edgeVisibleThickness,
                        length: edgeHandleLength,
                        cropRect: $cropRect,
                        minCropSize: minCropSize,
                        imageFrame: imageFrame
                    )
                }
            }
        }
    }

    enum Corner: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    enum Edge: CaseIterable {
        case top, bottom, left, right
    }

    private func denormalizedRect(in size: CGSize) -> CGRect {
        CGRect(
            x: imageFrame.origin.x + cropRect.origin.x * imageFrame.width,
            y: imageFrame.origin.y + cropRect.origin.y * imageFrame.height,
            width: cropRect.width * imageFrame.width,
            height: cropRect.height * imageFrame.height
        )
    }

    private func moveBody(from startRect: CGRect, with translation: CGSize) {
        var newRect = startRect
        let deltaX = translation.width / imageFrame.width
        let deltaY = translation.height / imageFrame.height
        newRect.origin.x = max(0, min(1 - startRect.width, startRect.origin.x + deltaX))
        newRect.origin.y = max(0, min(1 - startRect.height, startRect.origin.y + deltaY))
        cropRect = newRect
    }
}

private struct CornerHandleView: View {
    let corner: CropOverlayView.Corner
    let rect: CGRect
    let handleSize: CGFloat
    @Binding var cropRect: CGRect
    let minCropSize: CGFloat
    let imageFrame: CGRect

    @GestureState private var dragStartRect: CGRect?

    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: handleSize, height: handleSize)
            .position(cornerPosition())
            .gesture(
                DragGesture()
                    .updating($dragStartRect) { _, state, _ in
                        if state == nil { state = cropRect }
                    }
                    .onChanged { value in
                        guard let startRect = dragStartRect else { return }
                        updateCorner(from: startRect, with: value.translation)
                    }
            )
    }

    private func cornerPosition() -> CGPoint {
        switch corner {
        case .topLeft:
            return CGPoint(x: rect.minX, y: rect.minY)
        case .topRight:
            return CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft:
            return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomRight:
            return CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }

    private func updateCorner(from startRect: CGRect, with translation: CGSize) {
        var newRect = startRect
        let deltaX = translation.width / imageFrame.width
        let deltaY = translation.height / imageFrame.height

        switch corner {
        case .topLeft:
            newRect.origin.x += deltaX
            newRect.origin.y += deltaY
            newRect.size.width -= deltaX
            newRect.size.height -= deltaY
        case .topRight:
            newRect.origin.y += deltaY
            newRect.size.width += deltaX
            newRect.size.height -= deltaY
        case .bottomLeft:
            newRect.origin.x += deltaX
            newRect.size.width -= deltaX
            newRect.size.height += deltaY
        case .bottomRight:
            newRect.size.width += deltaX
            newRect.size.height += deltaY
        }

        newRect.origin.x = max(0, min(1 - minCropSize, newRect.origin.x))
        newRect.origin.y = max(0, min(1 - minCropSize, newRect.origin.y))
        newRect.size.width = max(minCropSize, min(1 - newRect.origin.x, newRect.size.width))
        newRect.size.height = max(minCropSize, min(1 - newRect.origin.y, newRect.size.height))

        cropRect = newRect
    }
}

private struct EdgeHandleView: View {
    let edge: CropOverlayView.Edge
    let rect: CGRect
    let hitThickness: CGFloat
    let visibleThickness: CGFloat
    let length: CGFloat
    @Binding var cropRect: CGRect
    let minCropSize: CGFloat
    let imageFrame: CGRect

    @GestureState private var dragStartRect: CGRect?

    var body: some View {
        let horizontal = (edge == .top || edge == .bottom)
        let visibleLength = min(length, horizontal ? rect.width * 0.6 : rect.height * 0.6)
        let hitLength = max(visibleLength, horizontal ? 44 : 44)

        Color.white.opacity(0.001)
            .frame(
                width: horizontal ? hitLength : hitThickness,
                height: horizontal ? hitThickness : hitLength
            )
            .contentShape(Rectangle())
            .overlay {
                Rectangle()
                    .fill(Color.white)
                    .frame(
                        width: horizontal ? visibleLength : visibleThickness,
                        height: horizontal ? visibleThickness : visibleLength
                    )
                    .allowsHitTesting(false)
            }
            .position(edgePosition())
            .gesture(
                DragGesture()
                    .updating($dragStartRect) { _, state, _ in
                        if state == nil { state = cropRect }
                    }
                    .onChanged { value in
                        guard let startRect = dragStartRect else { return }
                        updateEdge(from: startRect, with: value.translation)
                    }
            )
    }

    private func edgePosition() -> CGPoint {
        switch edge {
        case .top:
            return CGPoint(x: rect.midX, y: rect.minY)
        case .bottom:
            return CGPoint(x: rect.midX, y: rect.maxY)
        case .left:
            return CGPoint(x: rect.minX, y: rect.midY)
        case .right:
            return CGPoint(x: rect.maxX, y: rect.midY)
        }
    }

    private func updateEdge(from startRect: CGRect, with translation: CGSize) {
        var newRect = startRect

        switch edge {
        case .top:
            let deltaY = translation.height / imageFrame.height
            newRect.origin.y += deltaY
            newRect.size.height -= deltaY
        case .bottom:
            let deltaY = translation.height / imageFrame.height
            newRect.size.height += deltaY
        case .left:
            let deltaX = translation.width / imageFrame.width
            newRect.origin.x += deltaX
            newRect.size.width -= deltaX
        case .right:
            let deltaX = translation.width / imageFrame.width
            newRect.size.width += deltaX
        }

        newRect.origin.x = max(0, min(1 - minCropSize, newRect.origin.x))
        newRect.origin.y = max(0, min(1 - minCropSize, newRect.origin.y))
        newRect.size.width = max(minCropSize, min(1 - newRect.origin.x, newRect.size.width))
        newRect.size.height = max(minCropSize, min(1 - newRect.origin.y, newRect.size.height))

        cropRect = newRect
    }
}
