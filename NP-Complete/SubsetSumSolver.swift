//  SubsetSumSolver.swift
//
//  Provides a pseudo-polynomial to exponential solution to the NP-Complete Subset Sum Problem.
//  As the complexity depends on the input (naïve O(2^N) and dynamic O(sN)) this algorithm selects
//  the most proper approach, depending on the input, and returns the first found solution.
//  The naïve algorithm utilises multithreading through GCD and a mean-subset-size starting
//  point in order to lower running times.
//
//  Created by Kewin Remeczki on 22.01.18.

import Foundation

// Required OS X 10.10 availability check (due to the use of the newer GCD API).
@available (OSX 10.10, *)
public class SubsetSumSolver {
    
    // MARK: - Properties
    /// The solution will be set (if any) after calling findSubset.
    public fileprivate(set) var solution: Set<Int>? = nil
    
    private var superset: [Int] = []
    private var sum: Int = 0
    
    /// DispatchGroup for the concurrent naive algorithm.
    private let tasks = DispatchGroup()
    
    // MARK: - Public functions
    
    /// Call this function to begin searching for a solution to the presented problem.
    /// The function decides whether to use a naïve or dynamic programming approach to the problem.
    /// - Parameters:
    ///   - superset: The superset to search for subsets in.
    ///   - sum: The sum to search for subsets equalling.
    /// - Returns: The first found solution or nil.
    public func findSubset(in superset: [Int], equalling sum: Int) -> Set<Int>? {
        // Checking for invalid input.
        if sum == 0 {
            return []
        } else if superset.isEmpty {
            return nil
        }
        // Set the properties.
        self.solution = nil
        self.superset = superset
        self.sum = sum
        
        // Find out which algorithm to use, depending on the input.
        let naïveTime = UInt64(truncating: NSDecimalNumber(decimal: pow(2, superset.count))) // O(2^N)
        let dynamicTime = UInt64(sum * superset.count) // O(sum*N)
        return naïveTime < dynamicTime ? solveNaïvely() : solveDynamically()
    }
    
    // MARK: - Greedy/Naïve algorithm
    
    /// Solves the problem by using a naive approach:
    /// Generate all subsets for the superset and check if the sum of any of them equals the desired sum.
    /// This algorithm is improved by using the average subset size
    /// - Returns: A solution (Set<Int>) or nil.
    private func solveNaïvely() -> Set<Int>? {
        // Find the size of the average-entry subset that solves the problem.
        let averageSize = averageSubsetSize()
        
        // Starting from the averageSize, create a concurrent task for each size of subsets until a solution is found or all possible subsets have been checked.
        let iterations = min(max(superset.count - averageSize, averageSize), superset.count)
        let _ = DispatchQueue.global(qos: .userInitiated)
        DispatchQueue.concurrentPerform(iterations: iterations) { i in
            if solution != nil {
                return
            }
            let larger = averageSize + i
            let smaller = averageSize - i
            
            if larger <= superset.count {
                build(size: larger)
            }
            if smaller > 0 && larger != smaller {
                build(size: smaller)
            }
        }
        
        return solution
    }
    
    /// Finds the size of the subset if all entries in the superset were equal to the median.
    /// - Returns: The size of the subset of median entries as an Int.
    private func averageSubsetSize() -> Int {
        let set = superset.sorted()
        let medianIndex = max(0, Int(set.count/2) - 1)
        return sum / set[medianIndex]
    }
    
    /// Build and check the subsets of a given size as a concurrent task added to the 'tasks' DispatchGroup.
    /// - Parameters:
    ///   - size: The size of the subsets.
    private func build(size: Int) {
        tasks.enter()
        var initialSubset = Set<Int>()
        buildSubsets(size: size, index: 0, subset: &initialSubset)
        tasks.leave()
    }
    
    /// Recursive, greedy function to build and validate all subsets of a given size.
    /// If a solution is found the 'solution' property will be set and the recursive calls will stop.
    /// - Parameters:
    ///   - size: The size of the subsets.
    ///   - index: The currently reached index in the superset.
    ///   - subset: The subset that is currently being built.
    private func buildSubsets(size: Int, index: Int, subset: inout Set<Int>) {
        // Optimisation step: (If size can't be achieved or a solution has been found)
        if size > superset.count - index + subset.count || solution != nil {
            return
        }
        
        // If we've reached our desired subset size we add it to the list of subsets and return.
        if subset.count >= size {
            if subset.reduce(0, +) == sum {
                solution = subset
            }
            return
        }
        
        // Otherwise we perform the recursive call as long as we haven't reached the end of the superset.
        if index < superset.count {
            let entry = superset[index]
            // Recursive call with the current entry selected.
            subset.insert(entry)
            buildSubsets(size: size, index: index + 1, subset: &subset)
            // Recursive call with the current entry skipped.
            subset.remove(entry)
            buildSubsets(size: size, index: index + 1, subset: &subset)
        }
    }
    
    // MARK: - Dynamic Programming
    
    /// Solve the given problem with dynamic programming principles.
    /// - Returns: A solution subset Set<Int> or nil.
    private func solveDynamically() -> Set<Int>? {
        // Create the dynamic array containing sets of integer sums.
        var dynamicArray = [Set<Int>]()
        // The first entry will always be able to sum to 0 and to itself.
        let firstLine: Set<Int> = [0, superset[0]]
        dynamicArray.append(firstLine)
        
        // Iterate through the entries of the superset.
        for index in 1..<superset.count {
            let entry = superset[index]
            // Optimisation step: Check if the current entry equals the sum.
            if entry == sum {
                return [entry]
            }
            // Add the entry to each of the previous sums, before adding the "sums set" to the dynamic array.
            let previousSums = dynamicArray[index-1]
            var currentSums = previousSums
            for tmpSum in previousSums {
                if tmpSum < sum {
                    currentSums.insert(tmpSum + entry)
                }
            }
            dynamicArray.append(currentSums)
        }
        
        var subset = Set<Int>()
        // Use recursive backtracking to see if there is a solution.
        solution = findDynamicSubset(dynamicArray: dynamicArray, subset: &subset, tmpSum: sum)
        return solution
    }
    
    /// Find a solution subset in a given dynamic array. (Recursive)
    /// - Parameters:
    ///   - dynamicArray: The dynamic array.
    ///   - subset: The mutable subset to build recursively.
    ///   - tmpSum: The current sum to find in the dynamic array.
    /// - Returns: A solution subset Set<Int> or nil.
    private func findDynamicSubset(dynamicArray: [Set<Int>], subset: inout Set<Int>, tmpSum: Int) -> Set<Int>? {
        // If the tmpSum is 0, we've found a solution!
        if tmpSum == 0 {
            return subset
        }
        // Check if the sum is achievable. If so, perform the recursive call with the new tmpSum, otherwise return nil.
        for i in 0..<dynamicArray.count {
            let sums = dynamicArray[i]
            if sums.contains(tmpSum) {
                let entry = superset[i]
                subset.insert(entry)
                return findDynamicSubset(dynamicArray: dynamicArray, subset: &subset, tmpSum: tmpSum - entry)
            }
        }
        return nil
    }
}
