//  TimeConverter.swift
//  Converts 12-hour clock times to 24-hour clock times.
//  This problem is often encountered at job interviews or at programming competitions.
//
//  Created by Kewin Remeczki on 22.01.18.

import Foundation

/// Errors specific to the TimeConverter.
/// - InvalidArgument: The input does not conform to the expected format.
enum TimeConverterError : Error {
    case InvalidArgument(String)
}

public class TimeConverter {
    // MARK: - Properties
    private static let regex = try! NSRegularExpression(pattern: "^(0[0-9]|1[0-2]):[0-5][0-9]:[0-5][0-9](a|p)m$", options: .caseInsensitive)
    
    // MARK: - Public functions
    
    /// Convert a 12-hour clock time string to a 24-hour clock time string.
    /// Example: "07:35:40PM" will return "19:35:40".
    /// - Parameter time: The 12-hour clock time string to convert.
    /// - Returns: The converted 24-hour clock time string.
    class func convert12To24(_ time: String) throws -> String {
        if !validateInput(time) {
            throw TimeConverterError.InvalidArgument("\(time) does not conform to the expected format: hh:mm:ssPM (or AM)")
        }
        let hours = time.prefix(2)
        if hours == "12" && time.lowercased().hasSuffix("am") {
            return "00" + time.dropFirst(2).dropLast(2)
        } else if time.lowercased().hasSuffix("pm") && Int(hours)! < 12 {
            return "\(Int(hours)!+12)" + time.dropFirst(2).dropLast(2)
        } else {
            return String(time.dropLast(2))
        }
    }
    
    // MARK: - Private functions
    
    /// Validates the input string against the regex.
    /// - Parameters:
    ///   - input: The input string to validate.
    /// - Returns: true if the input is valid, false if not.
    private class func validateInput(_ input: String) -> Bool {
        return regex.matches(in: input.lowercased(), range: NSRange(input.startIndex..., in: input)).count > 0
    }
}
