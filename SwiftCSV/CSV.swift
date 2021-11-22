//
//  CSV.swift
//  SwiftCSV
//
//  Created by Naoto Kaneko on 2/18/16.
//  Copyright © 2016 Naoto Kaneko. All rights reserved.
//

import Foundation

public protocol CSVView {
    associatedtype Row
    associatedtype Columns

    var rows: [Row] { get }
    var columns: Columns { get }

    init(header: [String], text: String, delimiter: Character, loadColumns: Bool, rowLimit: Int?) throws

    func serialize(header: [String], delimiter: Character) -> String
}

/// CSV variant for which unique column names are assumed.
///
/// Example:
///
///     let csv = NamedCSV(...)
///     let allIDs = csv.columns["id"]
///     let firstEntry = csv.rows[0]
///     let fullName = firstEntry["firstName"] + " " + firstEntry["lastName"]
///
public typealias NamedCSV = CSV<Named>

/// CSV variant that exposes columns and rows as arrays.
/// Example:
///
///     let csv = EnumeratedCSV(...)
///     let allIds = csv.columns.filter { $0.header == "id" }.rows
///
public typealias EnumeratedCSV = CSV<Enumerated>

/// For convenience, there's `EnumeratedCSV` to access fields in rows by their column index,
/// and `NamedCSV` to access fields by their column names as defined in a header row.
open class CSV<DataView : CSVView>  {
    public static var comma: Character { return "," }
    
    public let header: [String]

    /// Unparsed contents.
    public let text: String

    /// Used delimiter to parse `text` and to serialize the data again.
    public let delimiter: Character

    /// Underlying data representation of the CSV contents.
    public let content: DataView

    public var rows: [DataView.Row] {
        return content.rows
    }

    public var columns: DataView.Columns {
        return content.columns
    }


    /// Load CSV data from a string.
    ///
    /// - Parameters:
    ///   - string: CSV contents to parse.
    ///   - delimiter: Character used to separate  row and header fields (default is ',')
    ///   - loadColumns: Whether to populate the `columns` dictionary (default is `true`)
    ///   - rowLimit: Amount of rows to parse (default is `nil`).
    /// - Throws: `CSVParseError` when parsing `string` fails.
    public init(string: String, delimiter: Character = comma, loadColumns: Bool = true, rowLimit: Int? = nil) throws {
        self.text = string
        self.delimiter = delimiter
        self.header = try Parser.array(text: string, delimiter: delimiter, rowLimit: 1).first ?? []

        self.content = try DataView(header: header, text: text, delimiter: delimiter, loadColumns: loadColumns, rowLimit: rowLimit)
    }

    /// Load a CSV file as a named resource from `bundle`.
    ///
    /// - Parameters:
    ///   - name: Name of the file resource inside `bundle`.
    ///   - ext: File extension of the resource; use `nil` to load the first file matching the name (default is `nil`)
    ///   - bundle: `Bundle` to use for resource lookup (default is `.main`)
    ///   - delimiter: Character used to separate row and header fields (default is ',')
    ///   - encoding: encoding used to read file (default is `.utf8`)
    ///   - loadColumns: Whether to populate the columns dictionary (default is `true`)
    /// - Throws: `CSVParseError` when parsing the contents of the resource fails, or file loading errors.
    /// - Returns: `nil` if the resource could not be found
    public convenience init?(named name: String, extension ext: String? = nil, bundle: Bundle = .main, delimiter: Character = comma, encoding: String.Encoding = .utf8, loadColumns: Bool = true) throws {
        guard let url = bundle.url(forResource: name, withExtension: ext) else {
            return nil
        }
        try self.init(url: url, delimiter: delimiter, encoding: encoding, loadColumns: loadColumns)
    }
    
    /// Load a CSV file from `url`.
    ///
    /// - parameter url: URL of the file (will be passed to `String(contentsOfURL:encoding:)` to load)
    /// - parameter delimiter: Character used to separate row and header fields (default is ',')
    /// - parameter encoding: Character encoding to read file (default is `.utf8`)
    /// - parameter loadColumns: Whether to populate the columns dictionary (default is `true`)
    /// - throws: `CSVParseError` when parsing the contents of `url` fails, or file loading errors.
    public convenience init(url: URL, delimiter: Character = comma, encoding: String.Encoding = .utf8, loadColumns: Bool = true) throws {
        let contents = try String(contentsOf: url, encoding: encoding)
        
        try self.init(string: contents, delimiter: delimiter, loadColumns: loadColumns)
    }
    
    /// Turn the CSV contents into Data using a given encoding
    open func dataUsingEncoding(_ encoding: String.Encoding) -> Data? {
        return serialized.data(using: encoding)
    }

    /// Serialized form of the CSV data; depending on the View used, this may
    /// perform additional normalizations.
    open var serialized: String {
        return self.content.serialize(header: self.header, delimiter: self.delimiter)
    }
}

extension CSV: CustomStringConvertible {
    public var description: String {
        return self.serialized
    }
}

func enquoteContentsIfNeeded(cell: String) -> String {
    // Add quotes if value contains a comma
    if cell.contains(",") {
        return "\"\(cell)\""
    }
    return cell
}
