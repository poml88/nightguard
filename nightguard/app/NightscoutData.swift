//
//  BgData.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 26.12.15.
//  Copyright © 2015 private. All rights reserved.
//

import Foundation

// Contains all available information of a current Blood Glucose value.
// This data can be stored in the user defaults.
class NightscoutData : NSObject, Codable, NSSecureCoding {
    
    var sgv : String = "---"
    // the delta Value in Display Units
    var bgdeltaString : String = "---"
    var bgdeltaArrow : String = "-"
    // the delta value in mgdl
    var bgdelta : Float = 0.0
    var hourAndMinutes : String {
        get {
            if time == 0 {
                return "??:??"
            }
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            
            let date = Date.init(timeIntervalSince1970: Double(time.int64Value / 1000))
            return formatter.string(from: date)
        }
    }
    var timeString : String {
        get {
            if time == 0 {
                return "-min"
            }
            
            // trick: when displaying the time, we'll add 30 seconds to current time for showing the difference like Nightscout does (0-30 seconds: "0 mins", 31-90 seconds: "1 min", ...)
            let thirtySeconds = Int64(30 * 1000)
            
            // calculate how old the current data is
            let currentTime = Int64(Date().timeIntervalSince1970 * 1000) + thirtySeconds
            let difference = (currentTime - time.int64Value) / 60000
            if difference > 59 {
                return ">1Hr"
            }
            return String(difference) + "min"
        }
    }
    var time : NSNumber = 0
    var battery : String = "---"
    var iob : String = ""
    var cob : String = ""
    
    override init () {
        super.init()
    }
    
    static var supportsSecureCoding: Bool {
        return true
    }
    
    enum CodingKeys: String, CodingKey {
        case sgv
        case bgdeltaString
        case bgdeltaArrow
        case bgdelta
        case time
        case battery
        case iob
        case cob
        case rawbg
        case noise
    }
    
    /*
     Code to deserialize BgData content. The error handling is needed in case that old serialized
     data leads to an error.
     */
    required init(coder decoder: NSCoder) {
        
        guard let sgv = decoder.decodeObject(forKey: "sgv") as? String else {
            return
        }
        self.sgv = sgv
        
        guard let bgdeltaString = decoder.decodeObject(forKey: "bgdeltaString") as? String else {
            return
        }
        self.bgdeltaString = bgdeltaString
        
        bgdeltaArrow = decoder.decodeObject(forKey: "bgdeltaArrow") as? String ?? "?"
        
        self.bgdelta = decoder.decodeFloat(forKey: "bgdelta")
        
        self.time = decoder.decodeObject(forKey: "time") as? NSNumber ?? 0
        
        self.battery = decoder.decodeObject(forKey: "battery") as? String ?? "?"
        
        self.iob = decoder.decodeObject(forKey: "iob") as? String ?? "?"
        
        self.cob = decoder.decodeObject(forKey: "cob") as? String ?? "?"
    }
    
    /*
     Code to serialize the BgData to store them in UserDefaults.
     */
    func encode(with aCoder: NSCoder) {
        aCoder.encode(self.sgv, forKey: "sgv")
        aCoder.encode(self.bgdeltaString, forKey: "bgdeltaString")
        aCoder.encode(self.bgdeltaArrow, forKey: "bgdeltaArrow")
        aCoder.encode(self.bgdelta, forKey: "bgdelta")
        aCoder.encode(self.time, forKey: "time")
        aCoder.encode(self.battery, forKey: "battery")
        aCoder.encode(self.iob, forKey: "iob")
        aCoder.encode(self.cob, forKey: "cob")
    }
    
    
    // MARK:- Codable interface implementation
    
    /// Creates a new instance by decoding from the given decoder.
    ///
    /// This initializer throws an error if reading from the decoder fails, or
    /// if the data read is corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.sgv = try container.decode(String.self, forKey: .sgv)
        self.bgdeltaString = try container.decode(String.self, forKey: .bgdeltaString)
        self.bgdeltaArrow = try container.decode(String.self, forKey: .bgdeltaArrow)
        self.bgdelta = try container.decode(Float.self, forKey: .bgdelta)
        self.time = NSNumber(floatLiteral: try container.decode(Double.self, forKey: .time))
        self.battery = try container.decode(String.self, forKey: .battery)
        self.iob = try container.decode(String.self, forKey: .iob)
        self.cob = try container.decode(String.self, forKey: .cob)
    }
    
    /// Encodes this value into the given encoder.
    ///
    /// If the value fails to encode anything, `encoder` will encode an empty
    /// keyed container in its place.
    ///
    /// This function throws an error if any values are invalid for the given
    /// encoder's format.
    ///
    /// - Parameter encoder: The encoder to write data to.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.sgv, forKey: .sgv)
        try container.encode(self.bgdeltaString, forKey: .bgdeltaString)
        try container.encode(self.bgdeltaArrow, forKey: .bgdeltaArrow)
        try container.encode(self.bgdelta, forKey: .bgdelta)
        try container.encode(self.time.doubleValue, forKey: .time)
        try container.encode(self.battery, forKey: .battery)
        try container.encode(self.iob, forKey: .iob)
        try container.encode(self.cob, forKey: .cob)
    }
    
    func isOlderThanYMinutes() -> Bool {
        if UserDefaultsRepository.checkBGEveryMinute.value == true {
            isOlderThan1Minute()
        } else {
            isOlderThan5Minutes()
        }
    }
    
    func isOlderThan1Minute() -> Bool {
        return isOlderThanXMinutes(1)
    }
    
    func isOlderThan5Minutes() -> Bool {
        return isOlderThanXMinutes(5)
    }
    
    func isOlderThanXMinutes(_ minutes : Int) -> Bool {
        let lastUpdateAsNSDate : Date = Date(timeIntervalSince1970: time.doubleValue / 1000)
        let timeInterval : Int = Int(Date().timeIntervalSince(lastUpdateAsNSDate))

        return timeInterval > minutes * 60
    }
}

