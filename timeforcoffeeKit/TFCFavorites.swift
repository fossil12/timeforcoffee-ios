//
//  TFCFaforites.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 20.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation

class TFCFavorites: NSObject {

    class var sharedInstance: TFCFavorites {
        struct Static {
            static let instance: TFCFavorites = TFCFavorites()
        }
        return Static.instance
    }

    lazy var stations: [String: TFCStation] = { [unowned self] in
        return self.getCurrentFavoritesFromDefaults()
        }()
    
    private struct objects {
        static let  dataStore: TFCDataStore? = TFCDataStore()
    }

    private var temporarlyRemovedStations = false


    override init() {
        super.init()
    }

    func repopulateFavorites() {
        temporarlyRemovedStations = false
        self.stations = getCurrentFavoritesFromDefaults()
    }

    private func getCurrentFavoritesFromDefaults() -> [String: TFCStation] {
        var st: [String: TFCStation]?
        if let unarchivedObject = objects.dataStore?.objectForKey("favorites2") as? NSData {
            st = NSKeyedUnarchiver.unarchiveObjectWithData(unarchivedObject) as? [String: TFCStation]
        }
        let cache = TFCCache.objects.stations
        if (st != nil) {
            // get if from the cache, if it's already there.
            for (st_id, station) in st! {
                let newStation: TFCStation? = cache.objectForKey(st_id) as TFCStation?
                if (newStation != nil && newStation?.coord != nil) {
                    st![st_id] = newStation
                }
            }
            return st!
        } else {
            return [:]
        }
    }

    func removeTemporarly(st_id: String) {
        temporarlyRemovedStations = true
        stations.removeValueForKey(st_id)
    }

    func unset(st_id: String?) {
        if (st_id == nil) {
            return
        }
        if (temporarlyRemovedStations) {
            repopulateFavorites()
        }
        stations.removeValueForKey(st_id!)
        self.saveFavorites()
    }

    func unset(station: TFCStation?) {
        unset(station?.st_id)
    }

    func set(station: TFCStation?) {
        if (station != nil) {
            if (temporarlyRemovedStations) {
                repopulateFavorites()
            }
            stations[(station?.st_id)!] = station!
            self.saveFavorites()
        }
    }

    func isFavorite(st_id: String?) -> Bool {
        if (st_id != nil) {
            if (self.stations[st_id!] != nil) {
                let res: Bool? = (self.stations[st_id!]! as TFCStation).isFavorite()

                if (res != nil || res == true) {
                    return true
                }
            }
        }
        return false
    }


    private func saveFavorites() {
        for (id, station) in stations {
            station.serializeDepartures = false
        }
        let archivedFavorites = NSKeyedArchiver.archivedDataWithRootObject(stations)
        for (id, station) in stations {
            station.serializeDepartures = true
        }
        objects.dataStore?.setObject(archivedFavorites , forKey: "favorites2")
    }

}

extension Array {
    //  stations.find{($0 as TFCStation).st_id == st_id}
    func indexOf(includedElement: T -> Bool) -> Int? {
        for (idx, element) in enumerate(self) {
            if includedElement(element) {
                return idx
            }
        }
        return nil
    }

    func getObject(includedElement: T -> Bool) -> T? {
        for (idx, element) in enumerate(self) {
            if includedElement(element) {
                return element
            }
        }
        return nil
    }
}