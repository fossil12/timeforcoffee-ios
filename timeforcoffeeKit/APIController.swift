//
//  APIController.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 13.09.14.
//  Copyright (c) 2014 Christian Stocker. All rights reserved.
//

import Foundation
import CoreLocation

final class APIController {
    
    private weak var delegate: APIControllerProtocol?
    private var currentFetch:[Int: URLSessionDataTask] = [:]

    private lazy var cache:PINCache = {
        return TFCCache.objects.apicalls
     }()

    init(delegate: APIControllerProtocol?) {
        self.delegate = delegate
    }

    func searchFor(_ coord: CLLocationCoordinate2D, context: Any?) {
        let cacheKey: String = String(format: "locations?x=%.3f&y=%.3f", coord.latitude, coord.longitude)
        let urlPath: String = "https://transport.opendata.ch/v1/locations?type=station&x=\(coord.latitude)&y=\(coord.longitude)"
        self.fetchUrl(urlPath, fetchId: 1, context: context, cacheKey: cacheKey)
    }

    func searchFor(_ coord: CLLocationCoordinate2D) {
        searchFor(coord, context: nil)
    }
    
    func searchFor(_ location: String) {
        var name = location.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
        if let name2 = name {
            var country = TFCLocationManager.getISOCountry()
            let urlPath:String
            let cacheKey:String
            if (name2.hasPrefix("!") == true) {
                country = "all"
                name = String(name2.dropFirst())
            }
            // search over all possible locations if outside of switzerland or starts with ! (for testing purposes)
            if (country != "CH") {
                cacheKey = "stations/trnsprt/\(name!)"
                urlPath = "https://transport.opendata.ch/v1/locations?type=station&query=\(name!)*";

            } else {
                cacheKey = "stations/\(name!)"
                urlPath = "https://tfc.chregu.tv/api/zvv/stations/\(name!)*"
            }
            if (name != "") {
                self.fetchUrl(urlPath, fetchId: 1, cacheKey: cacheKey)
            }
        }
    }

    func getDepartures(_ station: TFCStation) {
        getDepartures(station, context: nil)
    }
    
    func getDepartures(_ station: TFCStation, context: Any?, startTime:Date? = nil) {
        let urlPath = station.getDeparturesURL(startTime)
        self.fetchUrl(urlPath, fetchId: 2, context: context, cacheKey: nil)
    }

    func getPasslist(_ urlPath: String, context: Any?) {
        self.fetchUrl(urlPath, fetchId: 3, context: context, cacheKey: nil)
    }

    func getStationInfo(_ id: String, callback:@escaping (_ result:JSON?) -> Void) {
        let urlPath = "https://transport.opendata.ch/v1/locations?query=\(id)"
        let cacheKey = "stationsinfo/\(id)"
        self.fetchUrlWithCallback(urlPath, cacheKey: cacheKey, callback: callback)
    }
    
    private func fetchUrl(_ urlPath: String, fetchId: Int, cacheKey: String?) {
        fetchUrl(urlPath, fetchId: fetchId, context: nil, cacheKey: cacheKey, counter: 0)
    }

    private func fetchUrl(_ urlPath: String, fetchId: Int, context: Any?, cacheKey: String?) {
        fetchUrl(urlPath, fetchId: fetchId, context: context, cacheKey: cacheKey, counter: 0)
    }

    private func fetchUrl(_ urlPath: String, fetchId: Int, context: Any?, cacheKey: String?, counter: Int) {
        let delegate = self.delegate
        DispatchQueue.global(qos: .default).async {
            if let result = self.getFromCache(cacheKey) {
                delegate?.didReceiveAPIResults(result, error: nil, context: context)
            } else {
                if let url: URL = URL(string: urlPath) {
                    let absUrl = url.absoluteString
                    DLog("Start fetching data \(String(describing: absUrl))", toFile: true)


                    if (fetchId == 1 && self.currentFetch[fetchId] != nil) {
                        DLog("cancel current fetch")
                        self.currentFetch[fetchId]?.cancel()
                    }

                    let session2 = TFCURLSession.sharedInstance.session
                    let dataFetch: URLSessionDataTask? = session2.dataTask(with: url, completionHandler: {data, response, error -> Void in
                        let httpResponse = response as? HTTPURLResponse
                        DLog("Task completed with status code \(String(describing: httpResponse?.statusCode)) and date \(String(describing: httpResponse?.allHeaderFields["Date"])) and error \(String(describing: error))", toFile: true)

                        if(error != nil) {
                            // If there is an error in the web request, print it to the console
                            DLog(error ?? "")
                            // 1001 == timeout => just retry
                            if ((error as NSError?)?.code == -1001) {
                                let newcounter = counter + 1
                                // don't do it more than 5 times
                                if (newcounter <= 5) {
                                    delegate?.didReceiveAPIResults(nil, error: error, context: context)
                                    DLog("Retry #\(newcounter) fetching \(urlPath)")
                                    self.fetchUrl(urlPath, fetchId: fetchId, context: context, cacheKey: cacheKey, counter: newcounter)
                                }
                            }
                        }
                        if (fetchId == 1) {
                            self.currentFetch[fetchId] = nil
                        }

                        let jsonResult:JSON
                        if let data = data {
                            jsonResult = JSON(data: data)
                            //jsonResult.rawValue is NSNull, when data was not parseable. Don't cache it in that case
                            if (!(jsonResult.rawValue is NSNull) && error == nil && cacheKey != nil) {
                                self.cache.setObject(data as NSData, forKey: cacheKey!)
                            }
                        } else {
                            jsonResult = JSON(NSNull())
                        }
                        delegate?.didReceiveAPIResults(jsonResult, error: error, context: context)                        
                    })
                    dataFetch?.resume()
                    DLog("dataTask resumed")
                    if (dataFetch != nil) {
                        self.currentFetch[fetchId] = dataFetch
                    }
                } else {
                    DLog("\(urlPath) could not be parsed")
                    let error = NSError(domain: "ch.opendata.timeforcoffee", code: 9, userInfo: nil);
                    delegate?.didReceiveAPIResults(JSON(NSNull()), error: error, context: context)

                }
            }

        }
    }
    /*  we use it in TFCStationBase to get the name and coords of a station
        if it's not known yet */
    private func fetchUrlWithCallback(_ urlPath: String, cacheKey: String?, callback:@escaping (_ result:JSON?) -> Void) {
        guard let url = URL(string: urlPath) else { callback(nil); return }

        let absUrl = url.absoluteString
        DLog("Start fetching sync data \(absUrl)")
        var jsonResult:JSON? = nil
        let session2 = TFCURLSession.sharedInstance.session
        let dataFetch: URLSessionDataTask? = session2.dataTask(with: url, completionHandler: {data , response, error -> Void in

            DLog("Task Sync completed")
            if(error != nil) {
                jsonResult = nil
            }
            if let data = data {
                jsonResult = JSON(data: data)
                //jsonResult.rawValue is NSNull, when data was not parseable. Don't cache it in that case
                if (!(jsonResult!.rawValue is NSNull) && error == nil && cacheKey != nil) {
                    self.cache.setObject(data as NSData, forKey: cacheKey!)
                }
            } else {
                jsonResult = JSON(NSNull())
            }
            callback(jsonResult)
        })
        dataFetch?.resume()
    }

    private func getFromCache(_ cacheKey: String?) -> JSON? {
        if let cacheKey = cacheKey, let data = self.cache.object(forKey: cacheKey) as? Data  {               return JSON(data: data)
        }
        return nil
    }
}

public protocol APIControllerProtocol: class {
    func didReceiveAPIResults(_ results: JSON?, error: Error?, context: Any?)
}
