//
//  CDBloodSample+CoreDataProperties.swift
//  TestoSim
//
//  Created by Jesper Vang on 02/05/2025.
//
//

import Foundation
import CoreData


extension CDBloodSample {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDBloodSample> {
        return NSFetchRequest<CDBloodSample>(entityName: "CDBloodSample")
    }

    @NSManaged public var date: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var unit: String?
    @NSManaged public var value: Double
    @NSManaged public var injectionProtocol: CDInjectionProtocol?

}

extension CDBloodSample : Identifiable {

}
