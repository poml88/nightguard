//
//  AccessoryRectangularView.swift
//  nightguard
//
//  Created by Dirk Hermanns on 02.04.23.
//  Copyright © 2023 private. All rights reserved.
//

import Foundation
import SwiftUI
import WidgetKit

struct AccessoryRectangularView : View {
    
    var entry: NightscoutDataEntry
    
    var body: some View {
        ZStack {
            //No background on watch
#if os(iOS)
            AccessoryWidgetBackground()
                .clipShape(RoundedRectangle(cornerRadius: 10))
#endif
            VStack 	{
                HStack {
                    VStack {
                        ForEach(entry.lastBGValues, id: \.self.id) { bgEntry in
                            //Text("\(calculateAgeInMinutes(from:NSNumber(value: bgEntry.timestamp)))m")
                            if (entry.lastBGValues.first?.id == bgEntry.id) {
                                Text(Date.now.addingTimeInterval(-(Date.now.timeIntervalSince1970 - (bgEntry.timestamp / 1000))), style: .timer)
                                //iOS accessory widgets are b/w...
#if os(watchOS)
                                    .foregroundColor(Color(entry.sgvColor))
#endif
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .monospacedDigit()
                                    .multilineTextAlignment(.trailing)
                            } else {
                                Text("+\(calculateAgeInMinutes(from:NSNumber(value: Date.now.timeIntervalSince1970 * 1000 + bgEntry.timestamp - (entry.lastBGValues.first?.timestamp ?? 0))))m")
#if os(watchOS)
                                    .foregroundColor(Color(entry.sgvColor))
#endif
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }
                    VStack {
                        ForEach(entry.lastBGValues, id: \.self.id) { bgEntry in
                            // Text("\(String(bgEntry.value)) \(bgEntry.delta)")
                            Text("\(String(bgEntry.value)) \(bgEntry.delta) \(bgEntry.arrow)")
#if os(watchOS)
                                .foregroundColor(Color(entry.sgvColor))
#endif
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    if entry.lastBGValues.isEmpty {
                        VStack {
                            Text("--- --- ---")
                        }
                    }
                }
                if !entry.errorMessage.isEmpty {
                    Text("\(entry.errorMessage)")
                        .font(.system(size: 6))
                }
                //Text(entry.entryDate, style: .time)
                //Text("\(snoozedForMinutes(snoozeTimestamp: entry.snoozedUntilTimestamp))min Snoozed")
            }
        }
        .widgetAccentable(true)
        .unredacted()
    }
    
    func snoozedForMinutes(snoozeTimestamp: TimeInterval) -> Int {
        let currentTimestamp = Date().timeIntervalSince1970
        let snoozedMinutes = Int((snoozeTimestamp - currentTimestamp) / 60)
        if snoozedMinutes < 0 {
            return 0
        }
        return snoozedMinutes
    }
}
