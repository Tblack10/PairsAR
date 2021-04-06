//
//  PairsAR
//  Simple AR game of SET
//
//  To Play:
//     Select two facedown cards
//     If they match they'll stay up, otherwise they flip back down
//     The game's over when all of the cards are faceup
//
//  Created by Travis Black on 2021-04-02.
//

import UIKit
import RealityKit
import Combine

class SetVC: UIViewController {
    
    //Creates an achor of 2cm to anchor the view to
    let anchor = AnchorEntity(plane: .horizontal, minimumBounds: [0.2, 0.2])
    //All of the cards which the object models sit
    var cards: [Entity] = []
    //When an object is added
    var selectedEntities: [Int]? = []
    //The main ARView
    @IBOutlet var arView: ARView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        arView.scene.addAnchor(anchor)
        createCards(numOfCards: 4)
        addCardsToAnchor(numOfModels: 2)
        createOcclusionBox()
        loadAndShuffleEntityModels()
    }
    
    @IBAction func onTap(_ sender: UITapGestureRecognizer) {
        let tapLocation = sender.location(in: arView)
        //Checks that there's entity at the tap location
        guard let card = arView.entity(at: tapLocation) else { return }
        
        //Checks if the card is an actual card or a model, cards have one child
        guard (card.children.count == 1) else { return }
        
        //Reveals the object
        flipDown(card: card)
        //Appends the ID of the object to seletedEntities
        selectedEntities?.append(Int(card.children.first!.id))
        
        guard (selectedEntities?.count == 2) else { return }
        
        if (selectedEntities![0] == selectedEntities![1]) {
            print("MATCH!")
        } else {
            //Flips all cards back down
            for card in cards {
                if (card.transform.rotation.angle != .pi) { flipUp(card: card) }
            }
        }
        selectedEntities?.removeAll()
    }
}


extension SetVC {
    
    /// Creates the cards that objects sit on
    /// - Parameter numOfCards: the number of cards to create, as an Int
    private func createCards(numOfCards: Int) {
        for _  in 1...numOfCards {
            let box = MeshResource.generateBox(width: 0.04, height: 0.002, depth: 0.04)
            let metalMaterial = SimpleMaterial(color: .gray, isMetallic: false)
            let model = ModelEntity(mesh: box, materials: [metalMaterial])
            model.generateCollisionShapes(recursive: true)
            
            cards.append(model)
        }
    }
    
    
    /// Adds the cards to the AR Anchor and lays them out appropriately in AR space
    /// - Parameter numOfModels: the number of models that will be used
    private func addCardsToAnchor(numOfModels: Int) {
        for (index, card) in cards.enumerated() {
            let x = Float(index % numOfModels)
            let z = Float(index / numOfModels)
            
            card.position = [x*0.1, 0, z*0.1]
            anchor.addChild(card)
        }
    }
    
    
    /// Creates an occlusion box to prevent users from seeing the objects on the bottom of the cards
    private func createOcclusionBox() {
        //Hides the objects when they're rotated
        let boxSize: Float = 0.7
        let occlusionBoxMesh = MeshResource.generateBox(size: boxSize)
        let occlusionBox = ModelEntity(mesh: occlusionBoxMesh, materials: [OcclusionMaterial()])
        //occlusionBox.scale = SIMD3<Float>(0, 0, 0)
        occlusionBox.position.y = -boxSize/2
        anchor.addChild(occlusionBox)
    }
    
    
    /// Loads all the entity models and shuffles them
    private func loadAndShuffleEntityModels() {
        // W/O this our load request would cancel before our assets were loaded
        var cancellable: AnyCancellable? = nil
        
        cancellable = ModelEntity.loadModelAsync(named: "toy_car")
            .append(ModelEntity.loadModelAsync(named: "fender_stratocaster"))
            .collect()
            .sink(receiveCompletion: { error in
                print("Error: \(error)")
                cancellable?.cancel()
            }, receiveValue: { [weak self] entities  in
                var objects: [ModelEntity] = []
                for entity in entities {
                    entity.setScale(SIMD3<Float>(0.001, 0.001, 0.001), relativeTo: self!.anchor)
                    entity.setPosition(SIMD3<Float>(0, 0.0001, 0), relativeTo: self!.anchor)
                    entity.generateCollisionShapes(recursive: true)
                    for _ in 1...2 {
                        objects.append(entity.clone(recursive: true))
                        print(entity.id)
                    }
                }
                
                objects.shuffle()
                
                for (index, object) in objects.enumerated() {
                    self!.cards[index].addChild(object)
                    //Rotates objects at the beginning of the game
                    self!.cards[index].transform.rotation = simd_quatf(angle: .pi, axis: [1, 0, 0])
                }
                
                cancellable?.cancel()
            })
    }
    
    
    /// Flips a card downwards, revealing the object
    /// - Parameter card: the card to flip, as an Entity
    private func flipDown(card: Entity) {
        var flipDownTransform = card.transform
        flipDownTransform.rotation = simd_quatf(angle: 0, axis: [1, 0, 0])
        card.move(to: flipDownTransform, relativeTo: card.parent, duration: 0.25, timingFunction: .easeInOut)
    }
    
    
    /// Flips a card upwards, hiding the object
    /// - Parameter card: the card to flip, as an Entity
    private func flipUp(card: Entity) {
        var flipUpTransform = card.transform
        flipUpTransform.rotation = simd_quatf(angle: .pi, axis: [1, 0, 0])
        card.move(to: flipUpTransform, relativeTo: card.parent!, duration: 0.25, timingFunction: .easeInOut)
    }
    
}
