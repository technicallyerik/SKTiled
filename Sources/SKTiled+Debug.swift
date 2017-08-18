//
//  SKTiled+Debug.swift
//  SKTiled
//
//  Created by Michael Fessenden on 6/19/17.
//  Copyright © 2017 Michael Fessenden. All rights reserved.
//

import Foundation
import SpriteKit


// globals
public var TILE_BOUNDS_USE_OFFSET: Bool = false



/**
 
 ## Overview ##
 
 A structure representing debug drawing options for **SKTiled** objects.
 
 ## Properties ##
 
 ```
 DebugDrawOptions.drawGrid               // visualize the objects's grid (tilemap & layers).
 DebugDrawOptions.drawBounds             // visualize the objects's bounds.
 DebugDrawOptions.drawGraph              // visualize a layer's pathfinding graph.
 DebugDrawOptions.drawObjectBounds       // Draw an object's bounds.
 DebugDrawOptions.drawTileBounds         // Draw a tile's bounds.
 DebugDrawOptions.drawMouseOverObject    // Draw an empty tile shape.
 DebugDrawOptions.drawBackground         // Draw layer background.
 DebugDrawOptions.drawAnchor             // Draw anchor point.
 ```
 
 */
public struct DebugDrawOptions: OptionSet {
    public let rawValue: Int
    
    public init(rawValue: Int = 0) {
        self.rawValue = rawValue
    }
    
    /// Draw the layer's grid.
    static public let drawGrid             = DebugDrawOptions(rawValue: 1 << 0)
    /// Draw the layer's boundary shape.
    static public let drawBounds           = DebugDrawOptions(rawValue: 1 << 1)
    /// Draw the layer's pathfinding graph.
    static public let drawGraph            = DebugDrawOptions(rawValue: 1 << 2)
    /// Draw object bounds.
    static public let drawObjectBounds     = DebugDrawOptions(rawValue: 1 << 3)
    /// Draw tile bounds.
    static public let drawTileBounds       = DebugDrawOptions(rawValue: 1 << 4)
    static public let drawMouseOverObject  = DebugDrawOptions(rawValue: 1 << 5)
    static public let drawBackground       = DebugDrawOptions(rawValue: 1 << 6)
    static public let drawAnchor           = DebugDrawOptions(rawValue: 1 << 7)

    static public let grid:    DebugDrawOptions  = [.drawGrid, .drawBounds]
    static public let graph:   DebugDrawOptions  = [.grid, .drawGraph]
    static public let objects: DebugDrawOptions  = [.drawObjectBounds, .drawTileBounds]
    static public let all:     DebugDrawOptions  = [.grid, .graph, .drawObjectBounds,
                                                    .drawObjectBounds, .drawMouseOverObject,
                                                    .drawBackground, .drawAnchor]
}


/// Sprite object for visualizaing grid & graph.
// TODO: at some point the grid & graph textures should be a shader.
internal class TiledDebugDrawNode: SKNode {

    private var layer: TiledLayerObject                     // parent layer

    private var gridSprite: SKSpriteNode!
    private var graphSprite: SKSpriteNode!
    private var frameShape: SKShapeNode!

    private var gridTexture: SKTexture! = nil               // grid texture
    private var graphTexture: SKTexture! = nil              // GKGridGraph texture
    private var anchorKey: String = "LAYER_ANCHOR"

    init(tileLayer: TiledLayerObject){
        layer = tileLayer
        super.init()
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var anchorPoint: CGPoint {
        return convert(layer.position, from: layer)
    }
    
    var blendMode: SKBlendMode = .alpha {
        didSet {
            guard oldValue != blendMode else { return }
            reset()
            update()
        }
    }
    
    /// Debug visualization options.
    var debugDrawOptions: DebugDrawOptions {
        return layer.debugDrawOptions
    }

    var showGrid: Bool {
        get {
            return (gridSprite != nil) ? (gridSprite!.isHidden == false) : false
        } set {
            DispatchQueue.main.async {
                self.drawGrid()
            }
        }
    }

    var showBounds: Bool {
        get {
            return (frameShape != nil) ? (frameShape!.isHidden == false) : false
        } set {
            drawBounds()
        }
    }

    var showGraph: Bool {
        get {
            return (graphSprite != nil) ? (graphSprite!.isHidden == false) : false
        } set {
            DispatchQueue.main.async {
                self.drawGraph()
            }
        }
    }

    /**
     Align with the parent layer.
     */
    func setup() {
        // set the anchorpoints to 0,0 to match the frame
        gridSprite = SKSpriteNode(texture: nil, color: .clear, size: layer.sizeInPoints)
        gridSprite.anchorPoint = .zero
        addChild(gridSprite!)

        graphSprite = SKSpriteNode(texture: nil, color: .clear, size: layer.sizeInPoints)
        graphSprite.anchorPoint = .zero
        addChild(graphSprite!)

        frameShape = SKShapeNode()
        addChild(frameShape!)

        //isHidden = true

        // z-position values
        graphSprite!.zPosition = layer.zPosition + layer.tilemap.zDeltaForLayers
        gridSprite!.zPosition = layer.zPosition + (layer.tilemap.zDeltaForLayers + 10)
        frameShape!.zPosition = layer.zPosition + (layer.tilemap.zDeltaForLayers + 20)
    }
    
    /**
     Update the node with the various options.
     */
    func update() {
        
        Logger.default.log("debug options: \(debugDrawOptions.rawValue), hidden: \(isHidden)", level: .debug)
        
        if self.debugDrawOptions.contains(.drawGrid) {
            self.drawGrid()
        } else {
            self.gridSprite?.isHidden = true
        }

        if self.debugDrawOptions.contains(.drawBounds) {
            self.drawBounds()
        } else {
            self.frameShape?.isHidden = true
        }
        
        if self.debugDrawOptions.contains(.drawGraph) {
            self.drawGraph()
        } else {
            self.graphSprite?.isHidden = true
        }
        
        if self.debugDrawOptions.contains(.drawAnchor) {
            self.drawAnchor()
        } else {
            childNode(withName: anchorKey)?.removeFromParent()
        }
        
        
    }
    
    /**
     Reset all visualizations.
     */
    func reset() {
        gridSprite.texture = nil
        graphSprite.texture = nil
        childNode(withName: anchorKey)?.removeFromParent()
    }

    /**
     Visualize the layer's boundary shape.
     */
    func drawBounds() {

        let objectPath: CGPath!

        // grab dimensions from the layer
        let width = layer.width
        let height = layer.height
        let tileSize = layer.tileSize

        switch layer.orientation {
        case .orthogonal:
            objectPath = polygonPath(layer.bounds.points)

        case .isometric:
            let topPoint = CGPoint(x: 0, y: 0)
            let rightPoint = CGPoint(x: (width - 1) * tileSize.height + tileSize.height, y: 0)
            let bottomPoint = CGPoint(x: (width - 1) * tileSize.height + tileSize.height, y: (height - 1) * tileSize.height + tileSize.height)
            let leftPoint = CGPoint(x: 0, y: (height - 1) * tileSize.height + tileSize.height)

            let points: [CGPoint] = [
                // point order is top, right, bottom, left
                layer.pixelToScreenCoords(topPoint),
                layer.pixelToScreenCoords(rightPoint),
                layer.pixelToScreenCoords(bottomPoint),
                layer.pixelToScreenCoords(leftPoint)
            ]

            let invertedPoints = points.map{ $0.invertedY }
            objectPath = polygonPath(invertedPoints)

        case .hexagonal, .staggered:
            objectPath = polygonPath(layer.bounds.points)
        }

        if let objectPath = objectPath {
            frameShape.path = objectPath
            frameShape.isAntialiased = false
            frameShape.lineWidth = (layer.tileSize.halfHeight) < 8 ? 0.5 : 1.5
            frameShape.lineJoin = .miter

            // don't draw bounds of hexagonal maps
            frameShape.strokeColor = layer.frameColor
            if (layer.orientation == .hexagonal){
                frameShape.strokeColor = SKColor.clear
            }

            frameShape.fillColor = SKColor.clear
        }

        isHidden = false
        frameShape.isHidden = false
    }

    /// Display the current tile grid.
    func drawGrid() {

        if (gridTexture == nil) {
            gridSprite.isHidden = true

            // get the last z-position
            zPosition = layer.tilemap.lastZPosition + (layer.tilemap.zDeltaForLayers + 10)
            isHidden = false
            var gridSize = CGSize.zero

            // scale factor for texture
            let uiScale: CGFloat = SKTiledContentScaleFactor

            // multipliers used to generate smooth lines
            let defaultImageScale: CGFloat = (layer.tilemap.tileHeight < 16) ? 8 : 8
            let imageScale: CGFloat = (uiScale > 1) ? (defaultImageScale / 2) : defaultImageScale
            let lineScale: CGFloat = (layer.tilemap.tileHeightHalf > 8) ? 1.25 : 0.75

            // generate the texture
            if (gridTexture == nil) {
                let gridImage = drawLayerGrid(self.layer, imageScale: imageScale, lineScale: lineScale)
                gridTexture = SKTexture(cgImage: gridImage)
                gridTexture.filteringMode = .linear
            }

            // sprite scaling factor
            let spriteScaleFactor: CGFloat = (1 / imageScale)
            gridSize = gridTexture.size() / uiScale
            gridSprite.setScale(spriteScaleFactor)


            gridSprite.texture = gridTexture
            gridSprite.alpha = layer.gridOpacity * 0.75
            gridSprite.size = gridSize / imageScale

            // need to flip the grid texture in y
            // currently not doing this to the parent node so that objects will draw correctly.
            #if os(iOS) || os(tvOS)
            gridSprite.position.y = -layer.sizeInPoints.height
            #else
            gridSprite.yScale *= -1
            #endif
            
        }
        gridSprite.isHidden = false
        gridSprite.blendMode = self.blendMode
    }
    
    /// Display the current tile graph (if it exists).
    func drawGraph() {
        
        // drawLayerGrid
        graphTexture = nil
        graphSprite.isHidden = true
        
        // get the last z-position
        // TODO: use roles here
        zPosition = layer.tilemap.lastZPosition + (layer.tilemap.zDeltaForLayers - 10)
        isHidden = false
        var gridSize = CGSize.zero
        
        // scale factor for texture
        let uiScale: CGFloat = SKTiledContentScaleFactor
        
        // multipliers used to generate smooth lines
        let defaultImageScale: CGFloat = (layer.tilemap.tileHeight < 16) ? 8 : 8
        let imageScale: CGFloat = (uiScale > 1) ? (defaultImageScale / 2) : defaultImageScale
        // TODO: use tilemap zoom here
        let lineScale: CGFloat = (layer.tilemap.tileHeightHalf > 8) ? 1 : 0.85
        
        
        // generate the texture
        if (graphTexture == nil) {
            let gridImage = drawLayerGraph(self.layer, imageScale: imageScale, lineScale: lineScale)
            graphTexture = SKTexture(cgImage: gridImage)
            graphTexture.filteringMode = .linear
        }
        
        // sprite scaling factor
        let spriteScaleFactor: CGFloat = (1 / imageScale)
        gridSize = graphTexture.size() / uiScale
        graphSprite.setScale(spriteScaleFactor)
        
        
        graphSprite.texture = graphTexture
        graphSprite.alpha = layer.gridOpacity * 1.6
        graphSprite.size = gridSize / imageScale
        
        // need to flip the grid texture in y
        // currently not doing this to the parent node so that objects will draw correctly.
        #if os(iOS) || os(tvOS)
        graphSprite.position.y = -layer.sizeInPoints.height
        #else
        graphSprite.yScale *= -1
        #endif
        graphSprite.isHidden = false
        graphSprite.blendMode = self.blendMode
    }
    
    /**
     Visualize the layer's anchor point.
     */
    func drawAnchor() {
        childNode(withName: anchorKey)?.removeFromParent()
        
        let anchor = SKShapeNode(circleOfRadius: 0.75)
        anchor.name = anchorKey
        anchor.strokeColor = .clear
        anchor.zPosition = zPosition * 4

        addChild(anchor)
        anchor.position = anchorPoint
    }
}


// Shape node used for highlighting and placing tiles.
internal class TileShape: SKShapeNode {

    var tileSize: CGSize
    var orientation: SKTilemap.TilemapOrientation = .orthogonal
    var color: SKColor
    var layer: TiledLayerObject
    var coord: CGPoint
    var useLabel: Bool = false
    
    var renderQuality: CGFloat = 4
    var zoomFactor: CGFloat {
        return layer.tilemap.currentZoom
    }

    init(layer: TiledLayerObject, coord: CGPoint, tileColor: SKColor, withLabel: Bool=false){
        self.layer = layer
        self.coord = coord
        self.tileSize = layer.tileSize
        self.color = tileColor
        self.useLabel = withLabel
        super.init()
        self.orientation = layer.orientation
        drawObject()
    }

    init(layer: TiledLayerObject, tileColor: SKColor, withLabel: Bool=false){
        self.layer = layer
        self.coord = CGPoint.zero
        self.tileSize = layer.tileSize
        self.color = tileColor
        self.useLabel = withLabel
        super.init()
        self.orientation = layer.orientation
        drawObject()

    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func cleanup() {
        let fadeAction = SKAction.fadeAlpha(to: 0, duration: 0.1)
        run(fadeAction, completion: { self.removeFromParent()})
    }

    /**
     Draw the object.
     */
    private func drawObject() {
        // draw the path
        var points: [CGPoint] = []
        
        let scaledTilesize: CGSize = (tileSize * renderQuality)
        let halfWidth: CGFloat = (tileSize.width / 2) * renderQuality
        let halfHeight: CGFloat = (tileSize.height / 2) * renderQuality
        let tileWidth: CGFloat = (tileSize.width * renderQuality)
        let tileHeight: CGFloat = (tileSize.height * renderQuality)

        let tileSizeHalved = CGSize(width: halfWidth, height: halfHeight)

        switch orientation {
        case .orthogonal:
            let origin = CGPoint(x: -halfWidth, y: halfHeight)
            points = rectPointArray(scaledTilesize, origin: origin)

        case .isometric, .staggered:
            points = polygonPointArray(4, radius: tileSizeHalved)

        case .hexagonal:
            var hexPoints = Array(repeating: CGPoint.zero, count: 6)
            let staggerX = layer.tilemap.staggerX
            let sideLengthX = layer.tilemap.sideLengthX * renderQuality
            let sideLengthY = layer.tilemap.sideLengthY * renderQuality
            var variableSize: CGFloat = 0

            // flat
            if (staggerX == true) {
                let r = (tileWidth - sideLengthX) / 2
                let h = tileHeight / 2
                variableSize = tileWidth - (r * 2)
                hexPoints[0] = CGPoint(x: position.x - (variableSize / 2), y: position.y + h)
                hexPoints[1] = CGPoint(x: position.x + (variableSize / 2), y: position.y + h)
                hexPoints[2] = CGPoint(x: position.x + (tileWidth / 2), y: position.y)
                hexPoints[3] = CGPoint(x: position.x + (variableSize / 2), y: position.y - h)
                hexPoints[4] = CGPoint(x: position.x - (variableSize / 2), y: position.y - h)
                hexPoints[5] = CGPoint(x: position.x - (tileWidth / 2), y: position.y)
            } else {
                //let r = tileWidth / 2
                let h = (tileHeight - sideLengthY) / 2
                variableSize = tileHeight - (h * 2)
                hexPoints[0] = CGPoint(x: position.x, y: position.y + (tileHeight / 2))
                hexPoints[1] = CGPoint(x: position.x + (tileWidth / 2), y: position.y + (variableSize / 2))
                hexPoints[2] = CGPoint(x: position.x + (tileWidth / 2), y: position.y - (variableSize / 2))
                hexPoints[3] = CGPoint(x: position.x, y: position.y - (tileHeight / 2))
                hexPoints[4] = CGPoint(x: position.x - (tileWidth / 2), y: position.y - (variableSize / 2))
                hexPoints[5] = CGPoint(x: position.x - (tileWidth / 2), y: position.y + (variableSize / 2))
            }

            points = hexPoints.map{ $0.invertedY }
        }

        // draw the path
        self.path = polygonPath(points)
        self.isAntialiased = true
        self.lineJoin = .miter
        self.miterLimit = 0
        self.lineWidth = 1

        self.strokeColor = self.color.withAlphaComponent(0.75)
        self.fillColor = self.color.withAlphaComponent(0.18)

        // anchor
        childNode(withName: "ANCHOR")?.removeFromParent()
        let anchorRadius: CGFloat = (tileSize.halfHeight / 8) * renderQuality
        let anchor = SKShapeNode(circleOfRadius: anchorRadius)
        anchor.name = "ANCHOR"
        addChild(anchor)
        anchor.fillColor = self.color.withAlphaComponent(0.05)
        anchor.strokeColor = SKColor.clear
        anchor.zPosition = zPosition + 10
        anchor.isAntialiased = true



        // coordinate label
        childNode(withName: "COORDINATE")?.removeFromParent()
        if (useLabel == true) {
            let label = SKLabelNode(fontNamed: "Courier")
            label.name = "COORDINATE"
            label.fontSize = anchorRadius * renderQuality
            label.text = "\(Int(coord.x)),\(Int(coord.y))"
            addChild(label)
            label.zPosition = anchor.zPosition + 10
        }

        setScale(1 / renderQuality)
    }
}



extension TileShape {
    override var description: String {
        return "Tile Shape: \(coord.shortDescription)"
    }

    override var debugDescription: String {
        return description
    }
    
    override var hashValue: Int {
        return coord.hashValue
    }
}



internal func == (lhs: TileShape, rhs: TileShape) -> Bool {
    return lhs.coord.hashValue == rhs.coord.hashValue
}


// MARK: - SKTilemap
extension SKTilemap {

    /**
     Return tiles & objects at the given point in the map.

     - parameter point: `CGPoint` position in tilemap.
     - returns: `[SKNode]` array of tiles.
     */
    public func renderableObjectsAt(point: CGPoint) -> [SKNode] {
        return nodes(at: point).filter { node in
            (node as? SKTile != nil) || (node as? SKTileObject != nil)
            }
    }
    
    /**
     Draw the map bounds.
     */
    public func drawBounds() {
        // remove old nodes
        self.childNode(withName: "MAP_BOUNDS")?.removeFromParent()
        self.childNode(withName: "MAP_ANCHOR")?.removeFromParent()
        
        let debugZPos = lastZPosition * 50
        
        let blendMode = SKBlendMode.screen
        let scaledVertices = getVertices().map { $0 * renderQuality }
        let tilemapPath = polygonPath(scaledVertices)

        
        let boundsShape = SKShapeNode(path: tilemapPath) // , centered: <#T##Bool#>)
        boundsShape.name = "MAP_BOUNDS"
        boundsShape.fillColor = frameColor.withAlphaComponent(0.2)
        boundsShape.strokeColor = frameColor
        boundsShape.blendMode = blendMode
        self.addChild(boundsShape)
        
        
        boundsShape.isAntialiased = true
        boundsShape.lineCap = .round
        boundsShape.lineJoin = .miter
        boundsShape.miterLimit = 0
        boundsShape.lineWidth = 1 * (renderQuality / 2)

        boundsShape.setScale(1 / renderQuality)
        
        let anchorRadius = self.tileHeightHalf / 4
        let anchorShape = SKShapeNode(circleOfRadius: anchorRadius * renderQuality)
        anchorShape.name = "MAP_ANCHOR"
        anchorShape.fillColor = frameColor.withAlphaComponent(0.25)
        anchorShape.strokeColor = .clear
        boundsShape.addChild(anchorShape)
        boundsShape.zPosition = debugZPos
    }
}


// MARK: - SKTile
extension SKTile {
    /**
     Highlight the tile with a given color.

     - parameter color:        `SKColor?` optional highlight color.
     - parameter duration:     `TimeInterval` duration of effect.
     - parameter antialiasing: `Bool` antialias edges.
     */
    public func highlightWithColor(_ color: SKColor?=nil,
                                   duration: TimeInterval=1.0,
                                   antialiasing: Bool=true) {

        let highlight: SKColor = (color == nil) ? highlightColor : color!
        let orientation = tileData.tileset.tilemap.orientation

        if orientation == .orthogonal || orientation == .hexagonal {
            childNode(withName: "HIGHLIGHT")?.removeFromParent()

            var highlightNode: SKShapeNode? = nil
            if orientation == .orthogonal {
                highlightNode = SKShapeNode(rectOf: tileSize, cornerRadius: 0)
            }

            if orientation == .hexagonal {
                let hexPath = polygonPath(self.getVertices())
                highlightNode = SKShapeNode(path: hexPath, centered: true)
            }

            if let highlightNode = highlightNode {
                highlightNode.strokeColor = SKColor.clear
                highlightNode.fillColor = highlight.withAlphaComponent(0.35)
                highlightNode.name = "HIGHLIGHT"

                highlightNode.isAntialiased = antialiasing
                addChild(highlightNode)
                highlightNode.zPosition = zPosition + 50

                // fade out highlight
                removeAction(forKey: "HIGHLIGHT_FADE")
                let fadeAction = SKAction.sequence([
                    SKAction.wait(forDuration: duration * 1.5),
                    SKAction.fadeAlpha(to: 0, duration: duration/4.0)
                    ])

                highlightNode.run(fadeAction, withKey: "HIGHLIGHT_FADE", optionalCompletion: {
                    highlightNode.removeFromParent()
                })
            }
        }

        if orientation == .isometric || orientation == .staggered {
            removeAction(forKey: "HIGHLIGHT_FADE")
            let fadeOutAction = SKAction.colorize(with: SKColor.clear, colorBlendFactor: 1, duration: duration)
            run(fadeOutAction, withKey: "HIGHLIGHT_FADE", optionalCompletion: {
                let fadeInAction = SKAction.sequence([
                    SKAction.wait(forDuration: duration * 2.5),
                    //fadeOutAction.reversedAction()
                    SKAction.colorize(with: SKColor.clear, colorBlendFactor: 0, duration: duration/4.0)
                    ])
                self.run(fadeInAction, withKey: "HIGHLIGHT_FADE")
            })
        }
    }

    /**
     Clear highlighting.
     */
    public func clearHighlight() {
        let orientation = tileData.tileset.tilemap.orientation

        if orientation == .orthogonal {
            childNode(withName: "Highlight")?.removeFromParent()
        }
        if orientation == .isometric {
            removeAction(forKey: "Highlight_Fade")
        }
    }
}


// TODO: Temporary

public func flipFlagsDebug(hflip: Bool, vflip: Bool, dflip: Bool) -> String {
    var result: String = "none"
    if (dflip == true) {
        if (hflip && !vflip) {
            result = "rotate 90"   // rotate 90deg
        }

        if (hflip && vflip) {
            result = "rotate 90, xScale * -1"
        }

        if (!hflip && vflip) {
            result = "rotate -90"    // rotate -90deg
        }

        if (!hflip && !vflip) {
            result = "rotate -90, xScale * -1"
        }
    } else {
        if (hflip == true) {
            result = "xScale * -1"
        }

        if (vflip == true) {
            result = "yScale * -1"
        }
    }
    return result
}


public extension SignedInteger {
    public var hexString: String { return "0x" + String(self, radix: 16) }
    public var binaryString: String { return "0b" + String(self, radix: 2) }
}


public extension UnsignedInteger {
    public var hexString: String { return "0x" + String(self, radix: 16) }
    public var binaryString: String { return "0b" + String(self, radix: 2) }
}

// MARK: - Logging

public enum LoggingLevel: Int {
    case none
    case fatal
    case error
    case warning
    case success
    case status
    case info
    case debug
    case custom
}


public struct LogEvent: Hashable {
    var message: String
    let level: LoggingLevel
    let uuid: String = UUID().uuidString
    
    var symbol: String? = nil
    let date = Date()
    
    let file: String = #file
    let method: String = #function
    let line: UInt = #line
    let column: UInt = #column
    
    public init(_ message: String, level: LoggingLevel = .info, caller: String? = nil) {
        self.message = message
        self.level = level
        self.symbol = caller
    }
    
    public var hashValue: Int {
        return uuid.hashValue
    }
}



public class Logger {
    
    public enum DateFormat {
        case none
        case short
        case long
    }
    
    public var dateFormat: DateFormat = .none
    static public let `default` = Logger()
    
    private var logcache: Set<LogEvent> = []
    private let logQueue = DispatchQueue.global(qos: .background)
    
    public var loggingLevel: LoggingLevel = .info {
        didSet {
            let objname = String(describing: type(of: self))
            print("[\(objname)]: logging level: \(loggingLevel)")
        }
    }
    
    public func log(_ message: String, level: LoggingLevel = .info, symbol: String? = nil, file: String = #file, method: String = #function, line: UInt = #line) {
        
        if (self.loggingLevel.rawValue > LoggingLevel.none.rawValue) && (level.rawValue <= self.loggingLevel.rawValue) {
            // format the message
            let formattedMessage = formatMessage(message, level: level, symbol: symbol, file: file, method: method, line: line)
            print(formattedMessage)
        }
    }
    
    public func cache(_ event: LogEvent) {
        logcache.insert(event)
    }
    
    public func release() {
        for event in logcache.sorted() {
            self.log(event.message, level: event.level)
        }
        logcache = []
    }
    
    private var timeStamp: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = dateFormat.formatString
        let dateStamp = formatter.string(from: Date())
        return "[" + dateStamp + "]"
    }
    
    private func formatMessage(_ message: String, level: LoggingLevel = .info, symbol: String? = nil, file: String = #file, method: String = #function, line: UInt = #line) -> String {
        // shorten file name
        let filename = URL(fileURLWithPath: file).lastPathComponent
        
        
        if (level == .status) {
            var formatted = "\(message)"
            if let symbol = symbol {
                formatted = "[\(symbol)]: \(formatted)"
            }
            return "▹ \(formatted)"
        }
        
        
        if (level == .success) {
            return " ❊ Success! \(message)"
        }
        
        
        // result string
        var result: [String] = (dateFormat == .none) ? [] : [timeStamp]
        
        result += (symbol == nil) ? [filename] : ["[" + symbol! + "]"]
        result += [String(describing: level), message]
        return result.joined(separator: ": ")
    }
}



public protocol Loggable {
    var logSymbol: String { get }
    func log(_ message: String, level: LoggingLevel, file: String, method: String, line: UInt)
}


/// Methods for all loggable objects
extension Loggable {
    public var logSymbol: String {
        return String(describing: type(of: self))
    }
    
    public func log(_ message: String, level: LoggingLevel, file: String = #file, method: String = #function, line: UInt = #line) {
        Logger.default.log(message, level: level, symbol: logSymbol, file: file, method: method, line: line)
    }
}


extension Logger.DateFormat {
    public var formatString: String {
        switch self {
        case .short:
            return "HH:mm:ss"
        case .long:
            return "yyyy-MM-dd HH:mm:ss"
        default:
            return ""
        }
    }
}


extension LogEvent: Comparable {
    static public func < (lhs: LogEvent, rhs: LogEvent) -> Bool {
        return lhs.level.rawValue < rhs.level.rawValue
    }
    
    static public func == (lhs: LogEvent, rhs: LogEvent) -> Bool {
        return lhs.level.rawValue == rhs.level.rawValue
    }
}


extension LoggingLevel: Comparable {
    static public func < (lhs: LoggingLevel, rhs: LoggingLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    static public func == (lhs: LoggingLevel, rhs: LoggingLevel) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
}


extension LoggingLevel: CustomStringConvertible {
    
    /// String representation of logging level.
    public var description: String {
        switch self {
        case .fatal:
            return "FATAL"
        case .error:
            return "ERROR"
        case .warning:
            return "WARNING"
        case .success:
            return "Success"
        case .info:
            return "INFO"
        case .debug:
            return "DEBUG"
        default:
            return ""
        }
    }
    
    /// Array of all options.
    public static let all: [LoggingLevel] = [.none, .fatal, .error, .warning, .success, .info, .debug, .custom]
}


// TODO: remove below this line in master
extension SKTiledScene {
    
    open func addTemporaryShape(at location: CGPoint, radius: CGFloat = 4, duration: TimeInterval=0) {
        guard let world = worldNode else { return }
        let worldLocation = world.convert(location, from: self)
        let shape = SKShapeNode(circleOfRadius: radius)
        shape.strokeColor = .purple
        shape.fillColor = shape.strokeColor.colorWithBrightness(factor: 1.5)
        world.addChild(shape)
        shape.position = worldLocation
        shape.zPosition = 5000
        
        if (duration > 0) {
            let fadeAction = SKAction.fadeAfter(wait: duration, alpha: 0)
            shape.run(fadeAction, completion: {
                shape.removeFromParent()
            })
        }
    }
}

