//
//  Forecast.swift
//  Wellness
//
//  Created by Bri Chapman on 4/4/15.
//  Copyright (c) 2015 com.bchapman. All rights reserved.
//

import Foundation
import CoreData

class Forecast: NSManagedObject {

    @NSManaged var currentForecast: NSData
    @NSManaged var dailyForecast: NSData
    @NSManaged var lastUpdated: NSDate

}
