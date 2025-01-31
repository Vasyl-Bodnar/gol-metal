import AppKit
import Foundation
import Metal
import MetalKit

// import SwiftUI

// NOTE: Temporary just to play with fire, not effective, crashes on large grids
// An change in structure is preffered
class Window: NSWindow {
    var rend: Renderer?

    override init(
        contentRect: NSRect, styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool
    ) {
        self.rend = nil
        super.init(
            contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        self.acceptsMouseMovedEvents.toggle()
    }

    override func mouseMoved(with event: NSEvent) {
        activateBox(loc: event.locationInWindow)
    }

    func activateBox(loc: CGPoint) {
        let ren = rend!
        let winSizes = ren.winSizeBuf.contents().assumingMemoryBound(to: UInt.self)
        let sideSize = ren.rowColSize

        var relative = [
            (Float(loc.x) / Float(winSizes[0])) * Float(sideSize),
            (Float(loc.y) / Float(winSizes[1])) * Float(sideSize),
        ]

        relative[0].round(.toNearestOrEven)
        relative[1].round(.toNearestOrEven)

        //ren.batchChanges.append(Int(relative[0]) * sideSize + Int(relative[1]))
    }
}

class Renderer: NSObject, MTKViewDelegate {
    let view: MTKView
    let dev: MTLDevice

    let commQ: MTLCommandQueue
    let compPipe: MTLComputePipelineState
    let rendPipeDesc: MTLRenderPipelineDescriptor

    let threadsPerTG: MTLSize
    let TGCount: MTLSize
    let elemCount: Int
    let rowColSize: Int

    var inputBuf: MTLBuffer
    var outputBuf: MTLBuffer
    let gridSizeBuf: MTLBuffer
    let winSizeBuf: MTLBuffer
    var vBuf: MTLBuffer

    let indexBuf: MTLBuffer
    let indexType: MTLIndexType
    let indexCount: Int

    //var batchChanges: [Int]

    init(view: MTKView, dev: MTLDevice) {
        guard let lib = try? dev.makeDefaultLibrary(bundle: Bundle.module) else {
            fatalError("Failed to load library")
        }

        let game_kern = lib.makeFunction(name: "game")!
        compPipe = try! dev.makeComputePipelineState(function: game_kern)

        threadsPerTG = MTLSize(width: 128, height: 1, depth: 1)
        TGCount = MTLSize(width: 8192, height: 1, depth: 1)
        elemCount = TGCount.width * threadsPerTG.width

        rowColSize = Int(sqrt(Double(elemCount)))

        inputBuf = dev.makeBuffer(
            length: MemoryLayout<Bool>.stride * elemCount,
            options: .storageModeShared)!
        outputBuf = dev.makeBuffer(
            length: MemoryLayout<Bool>.stride * elemCount, options: .storageModeShared)!
        gridSizeBuf = dev.makeBuffer(
            length: MemoryLayout<UInt>.stride, options: .storageModeShared)!
        winSizeBuf = dev.makeBuffer(
            length: MemoryLayout<Float>.stride * 2, options: .storageModeShared)!

        let input = inputBuf.contents().assumingMemoryBound(to: Bool.self)
        let gridSize = gridSizeBuf.contents().assumingMemoryBound(to: UInt.self)

        for i in 0..<elemCount {
            input[i] = Bool.random()
        }
        input[elemCount / 2] = true
        input[elemCount / 2 + 1] = true
        input[elemCount / 2 + 2] = true
        gridSize[0] = UInt(rowColSize)

        //batchChanges = []
        var vertices: [Float] = []
        var indeces: [UInt32] = []
        for i in 0..<rowColSize {
            for j in 0..<rowColSize {
                let color: Float =
                    input[Int(i * rowColSize + j)]
                    ? 1.0
                    : 0.0
                let x_anch = 2 * (Float(i) / Float(rowColSize)) - 1
                let y_anch = 2 * (Float(j) / Float(rowColSize)) - 1
                let x_wing = 2 * ((1 + Float(i)) / Float(rowColSize)) - 1
                let y_wing = 2 * ((1 + Float(j)) / Float(rowColSize)) - 1
                vertices.append(contentsOf: [
                    x_anch, y_anch, 0.0, 1.0, color, color, color, 1.0,
                    x_wing, y_anch, 0.0, 1.0, color, color, color, 1.0,
                    x_anch, y_wing, 0.0, 1.0, color, color, color, 1.0,
                    x_wing, y_wing, 0.0, 1.0, color, color, color, 1.0,
                ])
                indeces.append(contentsOf: [
                    UInt32(i * rowColSize + j) * 4,
                    UInt32(i * rowColSize + j) * 4 + 1,
                    UInt32(i * rowColSize + j) * 4 + 2,
                    UInt32(i * rowColSize + j) * 4 + 1,
                    UInt32(i * rowColSize + j) * 4 + 2,
                    UInt32(i * rowColSize + j) * 4 + 3,
                ])
            }
        }

        vBuf = dev.makeBuffer(
            bytes: &vertices,
            length: MemoryLayout<Float>.stride * vertices.count,
            options: .storageModeShared)!

        indexCount = indeces.count
        indexType = .uint32

        indexBuf = dev.makeBuffer(
            bytes: &indeces,
            length: MemoryLayout<UInt32>.stride * indexCount,
            options: .storageModeShared)!

        rendPipeDesc = MTLRenderPipelineDescriptor()
        rendPipeDesc.vertexFunction = lib.makeFunction(name: "vertex_main")
        rendPipeDesc.fragmentFunction = lib.makeFunction(name: "fragment_main")

        commQ = dev.makeCommandQueue()!

        self.view = view
        self.dev = dev

        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }

    func draw(in view: MTKView) {
        let commBuf = commQ.makeCommandBuffer()!

        let commEnc = commBuf.makeComputeCommandEncoder()!
        commEnc.setComputePipelineState(compPipe)
        commEnc.setBuffer(inputBuf, offset: 0, index: 0)
        commEnc.setBuffer(outputBuf, offset: 0, index: 1)
        commEnc.setBuffer(vBuf, offset: 0, index: 2)
        commEnc.setBuffer(gridSizeBuf, offset: 0, index: 3)
        commEnc.dispatchThreadgroups(TGCount, threadsPerThreadgroup: threadsPerTG)
        commEnc.endEncoding()

        // FIX: Redundent work due to lack of view in init
        // Not significant however
        rendPipeDesc.colorAttachments[0].pixelFormat = view.colorPixelFormat
        let rendPipeSt = try! dev.makeRenderPipelineState(descriptor: rendPipeDesc)
        let rendPassDesc = view.currentRenderPassDescriptor!
        let winSize = winSizeBuf.contents().assumingMemoryBound(to: UInt.self)
        winSize[0] = UInt(view.visibleRect.width)
        winSize[1] = UInt(view.visibleRect.height)
        //

        let rendPassEnc = commBuf.makeRenderCommandEncoder(descriptor: rendPassDesc)!
        rendPassEnc.setRenderPipelineState(rendPipeSt)
        rendPassEnc.setVertexBuffer(vBuf, offset: 0, index: 0)
        rendPassEnc.setFragmentBuffer(winSizeBuf, offset: 0, index: 0)
        rendPassEnc.drawIndexedPrimitives(
            type: .triangle, indexCount: indexCount, indexType: indexType, indexBuffer: indexBuf,
            indexBufferOffset: 0)
        rendPassEnc.endEncoding()

        commBuf.present(view.currentDrawable!)
        commBuf.commit()

        //commBuf.waitUntilCompleted()
        swap(&inputBuf, &outputBuf)
        //if batchChanges.count > 0 {
        //let input = inputBuf.contents().assumingMemoryBound(to: Bool.self)
        //for i in batchChanges {
        //input[i] = true
        //}
        //batchChanges = []
        //}
    }
}

let dev = MTLCreateSystemDefaultDevice()!

let rect = CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 800, height: 800))
let view = MTKView(frame: rect, device: dev)
let rend = Renderer(view: view, dev: dev)
view.delegate = rend

let window = NSWindow(
    contentRect: rect,
    styleMask: NSWindow.StyleMask(
        arrayLiteral: NSWindow.StyleMask.closable, NSWindow.StyleMask.titled,
        NSWindow.StyleMask.resizable, NSWindow.StyleMask.miniaturizable),
    backing: NSWindow.BackingStoreType.buffered, defer: false)
window.center()
window.title = "Gol"
window.makeKeyAndOrderFront(nil)
window.contentView = view
//window.rend = rend

_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
