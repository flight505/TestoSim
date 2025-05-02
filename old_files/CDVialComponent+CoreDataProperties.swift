//
//  CDVialComponent+CoreDataProperties.swift
//  TestoSim
//
//  Created by Jesper Vang on 02/05/2025.
//
//

import Foundation
import CoreData


extension CDVialComponent {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDVialComponent> {
        return NSFetchRequest<CDVialComponent>(entityName: "CDVialComponent")
    }

    @NSManaged public var mgPerML: Double
    @NSManaged public var compound: CDCompound?
    @NSManaged public var vialBlend: CDVialBlend?

}

extension CDVialComponent : Identifiable {

}
