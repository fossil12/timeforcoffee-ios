//
//  ComplicationController.swift
//  timeforcoffee
//
//  Created by Raphael Neuenschwander on 11.10.15.
//  Copyright © 2015 opendata.ch. All rights reserved.
//

// create the timeline entries (departures) to populate the complication

import ClockKit

//MARK: - Constants

private struct Constants {
    static let DepartureDuration = NSTimeInterval(60) // 1 minute
    static let FrequencyOfTimelineUpdate = NSTimeInterval(1.5*60*60) // 1.5 hour
}

class ComplicationController: NSObject, CLKComplicationDataSource {
    
    // MARK: - Timeline Configuration
    
    func getSupportedTimeTravelDirectionsForComplication(complication: CLKComplication, withHandler handler: (CLKComplicationTimeTravelDirections) -> Void) {
        handler([.Forward]) // supports only forward time travel
    }
    
    func getTimelineStartDateForComplication(complication: CLKComplication, withHandler handler: (NSDate?) -> Void) {
        func handleReply(stations: TFCStations?) {
            if let station = stations?.stations?.first {
                if let departure = station.getFilteredDepartures()?.first {
                    let startDate = timelineEntryDateForDeparture(departure, previousDeparture: nil)
                    handler(startDate)
                }
            }
        }
        TFCWatchData.sharedInstance.getStations(handleReply, errorReply: nil, stopWithFavorites: true)
    }
    
    func getTimelineEndDateForComplication(complication: CLKComplication, withHandler handler: (NSDate?) -> Void) {
        func handleReply(stations: TFCStations?) {
            if let station = stations?.stations?.first {
                let endDate = station.getFilteredDepartures()?.last?.getScheduledTimeAsNSDate()
                handler(endDate)
            }
        }
        TFCWatchData.sharedInstance.getStations(handleReply, errorReply: nil, stopWithFavorites: true)
    }
    
    func getPrivacyBehaviorForComplication(complication: CLKComplication, withHandler handler: (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.ShowOnLockScreen)
    }
    
    // MARK: - Timeline Population
    
    func getCurrentTimelineEntryForComplication(complication: CLKComplication, withHandler handler: ((CLKComplicationTimelineEntry?) -> Void)) {
        // Take the first entry before the current date
        getTimelineEntriesForComplication(complication, beforeDate: NSDate(), limit: 1) { (entries) -> Void in
            handler(entries?.first)
        }
    }
    
    func getTimelineEntriesForComplication(complication: CLKComplication, beforeDate date: NSDate, limit: Int, withHandler handler: (([CLKComplicationTimelineEntry]?) -> Void)) {
        // Call the handler with the timeline entries after to the given date
        
        func handleReply(stations: TFCStations?) {
            var entries = [CLKComplicationTimelineEntry]()
            
            if let station = stations?.stations?.first { // corresponds to the last favorited station or closest station
                if let departures = station.getFilteredDepartures() {
                    var index = departures.count - 1
                    var nextDeparture: TFCDeparture? = nil
                    var departure: TFCDeparture? = departures.last
                    var previousDeparture: TFCDeparture? = (departures.count >= 2 ) ? departures[index - 1] : nil
                    
                    while let thisDeparture = departure {
                        let thisEntryDate = timelineEntryDateForDeparture(thisDeparture, previousDeparture: previousDeparture)
                        if date.compare(thisEntryDate) == .OrderedDescending { // check if the entry date is "correctly" before the given date
                            let tmpl = templateForStationDepartures(station, departure: thisDeparture, nextDeparture: nextDeparture, complication: complication)
                            let entry = CLKComplicationTimelineEntry(date: thisEntryDate, complicationTemplate: tmpl)
                            entries.append(entry)
                            if entries.count == limit {break} // break if we reached the limit of entries
                        }
                        index--
                        nextDeparture = departure
                        departure = previousDeparture
                        previousDeparture = (index > 0 ) ? departures[index - 1] : nil
                    }
                    handler(entries)
                }
            }
        }
        
        TFCWatchData.sharedInstance.getStations(handleReply, errorReply: nil, stopWithFavorites: true)
    }
    
    func getTimelineEntriesForComplication(complication: CLKComplication, afterDate date: NSDate, limit: Int, withHandler handler: (([CLKComplicationTimelineEntry]?) -> Void)) {
        // Call the handler with the timeline entries after to the given date
        
        func handleReply(stations: TFCStations?) {
            var entries = [CLKComplicationTimelineEntry]()
            
            if let station = stations?.stations?.first { // corresponds to the favorited/closest station
                if let departures = station.getFilteredDepartures() {
                    
                    var index = 0
                    var previousDeparture: TFCDeparture? = nil
                    var departure: TFCDeparture? = departures.first
                    var nextDeparture: TFCDeparture? = (departures.count >= 2) ? departures[1] : nil
                    
                    while let thisDeparture = departure {
                        let thisEntryDate = timelineEntryDateForDeparture(thisDeparture, previousDeparture: previousDeparture)
                        if date.compare(thisEntryDate) == .OrderedAscending { // check if the entry date is "correctly" after the given date
                            let tmpl = templateForStationDepartures(station, departure: thisDeparture, nextDeparture: nextDeparture, complication: complication)
                            let entry = CLKComplicationTimelineEntry(date: thisEntryDate, complicationTemplate: tmpl)
                            entries.append(entry)
                            if entries.count == limit {break} // break if we reached the limit of entries
                        }
                        index++
                        previousDeparture = thisDeparture
                        departure = (departures.count - 1 >= index) ? departures[index] : nil
                        nextDeparture = (departures.count > index + 1) ? departures[index + 1] : nil
                    }
                    
                handler(entries)
                }
            }
        }
        TFCWatchData.sharedInstance.getStations(handleReply, errorReply: nil, stopWithFavorites: true)
    }
    
    // MARK: - Update Scheduling
    
    func getNextRequestedUpdateDateWithHandler(handler: (NSDate?) -> Void) {
        // Call the handler with the date when you would next like to be given the opportunity to update your complication content
        let nextUpdateDate = NSDate().dateByAddingTimeInterval(Constants.FrequencyOfTimelineUpdate) // request an update each 1.5 hour
        handler(nextUpdateDate);
    }
    
    // MARK: - Placeholder Templates
    
    func getPlaceholderTemplateForComplication(complication: CLKComplication, withHandler handler: (CLKComplicationTemplate?) -> Void) {
        
        switch complication.family {
            
        case CLKComplicationFamily.ModularLarge:
            let tmpl = CLKComplicationTemplateModularLargeTable()
            
            tmpl.headerTextProvider = CLKSimpleTextProvider(text: "Station")
            tmpl.row1Column1TextProvider = CLKSimpleTextProvider(text: "Line - Destination", shortText: nil)
            tmpl.row1Column2TextProvider = CLKSimpleTextProvider(text: "Time", shortText: nil)
            tmpl.row2Column1TextProvider = CLKSimpleTextProvider(text: "Line - Destination", shortText: nil)
            tmpl.row2Column2TextProvider = CLKSimpleTextProvider(text: "Time", shortText: nil)
            
            handler(tmpl)
            
        default: break
        }
    }
    
    func requestedUpdateDidBegin() {
        // get the shared instance
        let server = CLKComplicationServer.sharedInstance()
        
        // reload the timeline for all complications
        for complication in server.activeComplications {
            server.reloadTimelineForComplication(complication)
        }
    }
    
    func requestedUpdateBudgetExhausted() {
        // get the shared instance
        let server = CLKComplicationServer.sharedInstance()
        
        // reload the timeline for all complications
        for complication in server.activeComplications {
            server.reloadTimelineForComplication(complication)
        }
    }
    
    //MARK: - Convenience
    
    private func templateForStationDepartures(station: TFCStationBase , departure: TFCDeparture, nextDeparture: TFCDeparture?, complication: CLKComplication) -> CLKComplicationTemplate {
        
        let tmpl = CLKComplicationTemplateModularLargeTable() // Currently supports only ModularLarge
        
        tmpl.headerTextProvider = CLKSimpleTextProvider(text: station.getName(true))
        
        let departureLine = departure.getLine()
        let nextDepartureLine = nextDeparture?.getLine() ?? "-"
        
        var departureDestination = "-"
        var nextDepartureDestination = "-"
        if let tfcStation = station as? TFCStation {
            departureDestination = departure.getDestination(tfcStation)
            if let nextDeparture = nextDeparture {
                nextDepartureDestination = nextDeparture.getDestination(tfcStation)
            }
        }
        
        let units: NSCalendarUnit = [.Minute]
        let style: CLKRelativeDateStyle = .Timer
        
        tmpl.row1Column1TextProvider = CLKSimpleTextProvider(text: "[\(departureLine)] - \(departureDestination)")
        
        if let departureDate = departure.getScheduledTimeAsNSDate() {
            tmpl.row1Column2TextProvider = CLKRelativeDateTextProvider(date: departureDate, style: style, units: units)
        } else {
            tmpl.row1Column2TextProvider = CLKSimpleTextProvider(text: "-")
        }
        
        tmpl.row2Column1TextProvider = CLKSimpleTextProvider(text: "[\(nextDepartureLine)] - \(nextDepartureDestination)")
        
        if let nextDepartureDate = nextDeparture?.getScheduledTimeAsNSDate() {
            tmpl.row2Column2TextProvider = CLKRelativeDateTextProvider(date: nextDepartureDate, style: style, units: units)
        } else {
            tmpl.row2Column2TextProvider = CLKSimpleTextProvider(text: "-")
        }
    
        return tmpl
    }
    
    private func timelineEntryDateForDeparture(departure: TFCDeparture, previousDeparture: TFCDeparture?) -> NSDate {
       
        // If previous departure, show the next scheduled departure 1 minute after the last scheduled departure
        // => If a bus is scheduled at 13:00, it will be displayed till 13:01
        if let pd = previousDeparture, let date = pd.getScheduledTimeAsNSDate() {
            return date.dateByAddingTimeInterval(Constants.DepartureDuration)
        } else {
            return departure.getScheduledTimeAsNSDate()!.dateByAddingTimeInterval(-6*60*60) // If no previous departure, show the departure 6 hours in advance
        }
    }
}
