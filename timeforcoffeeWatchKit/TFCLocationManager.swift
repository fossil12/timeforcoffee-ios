//
//  TFCLocationManager.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 21.06.15.
//  Copyright © 2015 Christian Stocker. All rights reserved.
//

import Foundation
import CoreLocation

public final class TFCLocationManager: TFCLocationManagerBase {

    override func requestLocation() {
        self.locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        self.locationManager.requestLocation()
    }

    @objc public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [AnyObject]) {
        self.locationManagerBase(manager, didUpdateLocations: locations)
    }
}
