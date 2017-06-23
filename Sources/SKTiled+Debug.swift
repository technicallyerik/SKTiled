//
//  SKTiled+Debug.swift
//  SKTiled
//
//  Created by Michael Fessenden on 6/19/17.
//  Copyright © 2017 Michael Fessenden. All rights reserved.
//

import Foundation
import SpriteKit



/// Sprite object for visualizaing grid & graph.
internal class TiledLayerGrid: SKSpriteNode {
    
    private var layer: TiledLayerObject
    private var gridTexture: SKTexture! = nil
    private var graphTexture: SKTexture! = nil
    private var frameColor: SKColor = .black
    private var gridOpacity: CGFloat { return layer.gridOpacity }
    
    init(tileLayer: TiledLayerObject){
        layer = tileLayer
        frameColor = layer.frameColor
        super.init(texture: SKTexture(), color: SKColor.clear, size: tileLayer.sizeInPoints)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /**
     Align with the parent layer.
     */
    func setup() {
        // set the anchorpoint to 0,0 to match the frame
        anchorPoint = CGPoint.zero
        isHidden = true
        
        #if os(iOS)
        position.y = -layer.sizeInPoints.height
        #endif
    }
    
    /// Display the current tile grid.
    var showGrid: Bool = false {
        didSet {
            guard oldValue != showGrid else { return }
            
            texture = nil
            isHidden = true
            
            if (showGrid == true){
                
                // get the last z-position
                zPosition = layer.tilemap.lastZPosition + layer.tilemap.zDeltaForLayers
                isHidden = false
                var gridSize = CGSize.zero
                
                // scale factor for texture
                let uiScale: CGFloat
                
                #if os(iOS)
                uiScale = UIScreen.main.scale
                #else
                uiScale = NSScreen.main()!.backingScaleFactor
                #endif
                
                // multipliers used to generate smooth lines
                let imageScale: CGFloat = uiScale > 1 ? 2 : 4
                let lineScale: CGFloat = (layer.tilemap.tileHeightHalf > 8) ? 1 : 0.85

                
                // generate the texture
                if (gridTexture == nil) {
                    let gridImage = drawGrid(self.layer, imageScale: imageScale, lineScale: lineScale)
                    gridTexture = SKTexture(cgImage: gridImage)
                    gridTexture.filteringMode = .linear
                }
                
                // sprite scaling factor
                let spriteScaleFactor: CGFloat = (1 / imageScale)
                gridSize = gridTexture.size() / uiScale
                setScale(spriteScaleFactor)

                
                texture = gridTexture
                alpha = gridOpacity
                size = gridSize / imageScale
                
                #if os(OSX)
                yScale *= -1
                #endif
                
            }
        }
    }
}


/// Shape node used for highlighting and placing tiles.
internal class TileShape: SKShapeNode {
    
    var tileSize: CGSize
    var orientation: TilemapOrientation = .orthogonal
    var color: SKColor
    var layer: TiledLayerObject
    var coord: CGPoint
    var useLabel: Bool = false
    var renderQuality: CGFloat = 4
    
    
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
            
            // flat (broken)
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
            
            points = hexPoints.map{$0.invertedY}
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


internal func == (lhs: TileShape, rhs: TileShape) -> Bool {
    return lhs.coord == rhs.coord
}


extension SKTilemap {}


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
            childNode(withName: "Highlight")?.removeFromParent()
            
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
                highlightNode.name = "Highlight"
                
                highlightNode.isAntialiased = antialiasing
                addChild(highlightNode)
                highlightNode.zPosition = zPosition + 10
                
                // fade out highlight
                removeAction(forKey: "Highlight_Fade")
                let fadeAction = SKAction.sequence([
                    SKAction.wait(forDuration: duration * 1.5),
                    SKAction.fadeAlpha(to: 0, duration: duration/4.0)
                    ])
                
                highlightNode.run(fadeAction, withKey: "Highlight_Fade", optionalCompletion: {
                    highlightNode.removeFromParent()
                })
            }
        }
        
        if orientation == .isometric || orientation == .staggered {
            removeAction(forKey: "Highlight_Fade")
            let fadeOutAction = SKAction.colorize(with: SKColor.clear, colorBlendFactor: 1, duration: duration)
            run(fadeOutAction, withKey: "Highlight_Fade", optionalCompletion: {
                let fadeInAction = SKAction.sequence([
                    SKAction.wait(forDuration: duration * 2.5),
                    //fadeOutAction.reversedAction()
                    SKAction.colorize(with: SKColor.clear, colorBlendFactor: 0, duration: duration/4.0)
                    ])
                self.run(fadeInAction, withKey: "Highlight_Fade")
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


public extension TiledLayerObject {
    /**
     Communicate with the scene.
     */
    public func updateSceneDebugInfo(_ msg: String) {
        if let demoScene = self.scene as? SKTiledDemoScene {
            demoScene.updateDebugInfo(msg: msg)
        }
    }
}

#if os(OSX)
extension SKTiledDemoScene {
    
    /**
     Run demo keyboard events (macOS).
     
     - parameter eventKey: `UInt16` event key.
     
     */
    public func keyboardEvent(eventKey: UInt16) {
        guard let view = view,
            let cameraNode = cameraNode,
            let tilemap = tilemap,
            let worldNode = worldNode else {
                return
        }
        
        // 'D' shows/hides debug view
        if eventKey == 0x02 {
            tilemap.debugDraw = !tilemap.debugDraw
        }
        
        // 'O' shows/hides object layers
        if eventKey == 0x1f {
            tilemap.showObjects = !tilemap.showObjects
        }
        
        // 'P' pauses the map
        if eventKey == 0x23 {
            self.isPaused = !self.isPaused
        }
        
        // 'Q' print layer stats
        if eventKey == 0xc {
            tilemap.layerStatistics()
        }
        
        
        // 'H' hides the HUD
        if eventKey == 0x04 {
            if let view = self.view {
                let debugState = !view.showsFPS
                view.showsFPS = debugState
                view.showsNodeCount = debugState
                view.showsDrawCount = debugState
            }
        }
        
        // '←' advances to the next scene
        if eventKey == 0x7B {
            self.loadPreviousScene()
        }
        
        // 'E' toggles edit mode
        if eventKey == 0x0E {
            editMode = !editMode
        }
        
        // 'L' toggles live mode
        if eventKey == 0x25 {
            liveMode = !liveMode
        }
        
        // '1' zooms to 100%
        if eventKey == 0x12 || eventKey == 0x53 {
            cameraNode.resetCamera()
        }
        
        // 'A' or 'F' fits the map to the current view
        if eventKey == 0x0 || eventKey == 0x3 {
            cameraNode.fitToView(newSize: view.bounds.size)
        }
        
        
        
        // 'J' fades the layers in succession
        if eventKey == 0x26 {
            var fadeTime: TimeInterval = 3
            let additionalTime: TimeInterval = (tilemap.layerCount > 6) ? 1.25 : 2.25
            for layer in tilemap.getContentLayers() {
                let fadeAction = SKAction.fadeAfter(wait: fadeTime, alpha: 0)
                layer.run(fadeAction)
                fadeTime += additionalTime
            }
        }
        
        // 'K' updates the render quality
        if eventKey == 0x28 {
            if tilemap.renderQuality < 16 {
                tilemap.renderQuality *= 2
            }
        }
        
        // MARK: - Debugging Tests
        
        // 'Z' queries the debug draw state
        if eventKey == 0x6 {
            print("tilemap debug draw: \(tilemap.debugDraw), (show bounds: \(tilemap.showBounds), show grid: \(tilemap.showGrid))")
        }
        
        
        // 'I' runs a custom event
        if eventKey == 0x22 {
            var fadeTime: TimeInterval = 3
            let shapeRadius = (tilemap.tileHeightHalf / 4) - 0.5
            for x in 0..<Int(tilemap.size.width) {
                for y in 0..<Int(tilemap.size.height) {
                    
                    let shape = SKShapeNode(circleOfRadius: shapeRadius)
                    shape.alpha = 0.7
                    shape.fillColor = SKColor(hexString: "#FD4444")
                    shape.strokeColor = .clear
                    worldNode.addChild(shape)
                    
                    let shapePos = tilemap.baseLayer.pointForCoordinate(x, y)
                    shape.position = worldNode.convert(shapePos, from: tilemap.baseLayer)
                    shape.zPosition = tilemap.lastZPosition + tilemap.zDeltaForLayers
                    
                    let fadeAction = SKAction.fadeAfter(wait: fadeTime, alpha: 0)
                    shape.run(fadeAction, completion: {
                        shape.removeFromParent()
                    })
                    fadeTime += 0.003
                    
                }
                //fadeTime += 0.02
            }
        }
        
        // 'V' runs a custom test
        if eventKey == 0x9 {
            if let scoreLabel = tilemap.getObject(withID: 51) {
                print("setting score...")
                scoreLabel.text = "score: 0500"
            }
        }
    }
}
#endif
