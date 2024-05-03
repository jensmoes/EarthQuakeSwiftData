//
//  DataTransferModel.swift
//  EarthQuakeSwiftData
//
//  Created by Jens Troest on 11/4/24.
//

import Foundation
import SwiftData

/// A data provider responsible for data transfer and transformation from the transport format to the internal model
///
/// The original earthquakes app creates [Codingkeys](https://developer.apple.com/documentation/swift/codingkey)
/// for each level of the data inline in `GeoJSON`, then decodes the `GeoJSON` which has an internal array of properties objects.
/// That list is then accessed and used to faciliate the conversion into the internal model format and batch insertion in Core Data.
///
/// We do the same thing here because we want to exclude elements with missing data
/// (hence we must iterate on each properties element and add the desires ones to the array manually.)
///
/// There are other ways to achieve the exclusion, search for [Lossy codable list type](https://www.swiftbysundell.com/articles/ignoring-invalid-json-elements-codable/)
/// So with that in mind this becomes very similar to the original except we are using the `SwiftData` paradigms.
/// Specifically we process the entire batch on a seperate context by using `insert` and once done with all elements we call `save()` which in turn then updates
/// the main context.
///
/// - Remark: I have not been able to figure out how to merge contexts as is done in the Core Data example and the current method, although it works as intended
/// processing all elements in the background, does take quite a while. This I believe is due to all inserted elements being compared against
/// existing ones during save.
class QuakesProvider {
    
    /// A singleton
    static let shared = QuakesProvider()
    /// The url for one month summary feed
    let summaryMonthUrl = URL(string: "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_month.geojson")!
    
    var lastUpdated: Date {
        get {
            UserDefaults.standard.object(forKey: "lastUpdatedTimeStamp") as? Date ?? Date.distantPast
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: "lastUpdatedTimeStamp")
        }
    }
    /// Fetches the monthly summary
    /// Strategy is to fetch the batch, then import it, committing to coredata after the import so the UI viewcontext doesnt update until the batch is completed
    /// With swift data this should be possible by inserting each element then calling save on the context at the end of the batch.
    func fetchSummary() async throws {
        let session = URLSession.shared
        guard let (data, response) = try? await session.data(from: summaryMonthUrl),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            throw DataError.noData
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let raw = try decoder.decode(RawContentNestedStructs.self, from: data)
        print("Found \(raw.features.count) quakes")
        await importSummary(features: raw.features)
    }
    
    private func importSummary(features: [RawContentNestedStructs.Feature]) async {
        guard let container = try? ModelContainer(for: Quake.self) else { return }
        // Make a context on this thread. Autosave is false by default
        let context = ModelContext(container)
        
        var updateCount = 0
        for feature in features {
            let quake = Quake(from: feature)
            context.insert(quake)
            updateCount += 1
        }
        print("Added \(updateCount) quakes")
        if context.hasChanges {
            try? context.save()
            lastUpdated = Date.now
        }
    }
    
}


// MARK: Intermediate data transfer model

private struct RawContentNestedStructs: Decodable {
    
    var features = [Feature]()
    
    enum RootCodingKeys: CodingKey {
        case features
    }
    
    /// The nested types:
    @dynamicMemberLookup
    struct Feature: Decodable {
        let id: String //We use the feature ID here just to demonstrate flexibility with composing the internal(app) model object from any nested data points..
        var properties: Properties
        
        /// Allows direct access to properties from a feature. `T` is the type of keypath requested.
        subscript<T>(dynamicMember keyPath: KeyPath<Properties, T>) -> T {
            properties[keyPath: keyPath]
        }
        enum CodingKeys: CodingKey {
            case id
            case properties
        }
    }
    
    struct Properties: Decodable {
        let mag: Float
        let place: String
        let time: Date // We use date here so we can use the built-in date decoding strategy
        let code: String // The code is the unique identifier.
        
        
        // CodingKeys are implicitly given but private, uncomment if needed
        /*
         enum CodingKeys: CodingKey {
         case mag
         case place
         case time
         case code
         }
         */
        // This initializer is only relevant if we want to capture and log missing data.
        // We fail on any missing data so the synthesized initializer is sufficient.
        /*
         /// Custom initializer to capture and filter out specific missing elements
         init(from decoder: any Decoder) throws {
         let container: KeyedDecodingContainer<RawContentNestedStructs.Properties.CodingKeys> = try decoder.container(keyedBy: RawContentNestedStructs.Properties.CodingKeys.self)
         let rawmag = try? container.decode(Float.self, forKey: .mag)
         let rawplace = try? container.decode(String.self, forKey: .place)
         let rawtime = try? container.decode(Date.self, forKey: .time)
         let rawcode = try? container.decode(String.self, forKey: .code)
         
         guard let mag = rawmag,
         let place = rawplace,
         let time = rawtime,
         let code = rawcode
         else {
         print("Ignoring item due to missing data")
         // Ignore this item if it does not have all the data
         throw DataError.missingData
         }
         self.mag = mag
         self.place = place
         self.time = time
         self.code = code
         }
         */
    }
    
    
    /**
     The idea here is to create an unkeyed container of the features JSON array so that we can iterate on features
     extract any feature level data we want, an the properties element seperately.
     The reason we want the properties seperately is in order to ignore any elements with missing values.
     That is achieved by using `try?` when decoding `Properties` and then inserting any results into
     the
     */
    init(from decoder: any Decoder) throws {
        let rootcontainer = try decoder.container(keyedBy: RootCodingKeys.self)
        var featuresContainer = try rootcontainer.nestedUnkeyedContainer(forKey: .features)
        
        // Iterate all feature objects
        while(!featuresContainer.isAtEnd) {
            let singleFeatureContainer = try featuresContainer.nestedContainer(keyedBy: Feature.CodingKeys.self)
            // Use the id from the feature
            let featureId = try singleFeatureContainer.decode(String.self, forKey: .id)
            // We use an optional so we can skip elements with missing data
            if let properties = try? singleFeatureContainer.decode(Properties.self, forKey: .properties) {
                let newElement = Feature(id: featureId, properties: properties)
                features.append(newElement)
            } else {
                print("Ignoring element \(featureId) due to missing data")
            }
        }
    }
}
/**
 Implements transport specific extensions to the app model
 */
private extension Quake {
    /// A convenience initalizer converting to the internal app model
    /// - Note: This uses `@dynamicMemberLookup` to enable access to the nested properties directly from the `Feature`
    convenience init(from: RawContentNestedStructs.Feature) {
        self.init(magnitude: from.mag,
                  place: from.place,
                  timestamp: from.time,
                  code: from.code)
    }
}
