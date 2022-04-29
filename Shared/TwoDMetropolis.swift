//
//  TwoDMetropolis.swift
//  2D-Metropolis-Algorithm
//
//  Created by Katelyn Lydeen on 4/29/22.
//

import Foundation
import SwiftUI

class TwoDMetropolis: IsingModel {
    
    var twoDSpinArray: [[Double]] = []
    
    func initializeTwoDSpin(startType: String) async {
        twoDSpinArray = []
        for _ in 0..<N {
            await initializeSpin(startType: startType)
            twoDSpinArray.append(mySpin.spinArray)
        }
    }
    
    /*
    override func runSimulation(startType: String) async {
        newSpinUpPoints = []
        newSpinDownPoints = []
        
        for _ in 1...numIterations {
            await iterateTwoDMetropolis(startType: startType)
            await addSpinCoordinates(twoDSpinConfig: twoDSpinArray)
        }
    }
    */
    
    /// We index the spin matrix as [i][j]
    /// Following [row, column] notation means i should represent the y-axis and j should represent the x-axis
    func addSpinCoordinates(twoDSpinConfig: [[Double]]) async {
        for i in 0..<twoDSpinConfig.count {
            for j in 0..<twoDSpinConfig[i].count {
                if (twoDSpinConfig[i][j] < 0) {
                    newSpinDownPoints.append((xPoint: Double(j), yPoint: Double(i)))
                }
                else {
                    newSpinUpPoints.append((xPoint: Double(j), yPoint: Double(i)))
                }
            }
        }
    }
    
    func iterateTwoDMetropolis(startType: String) async {
        newSpinDownPoints = []
        newSpinUpPoints = []
        
        if (twoDSpinArray.isEmpty) {
            await initializeTwoDSpin(startType: startType)
        }

        twoDSpinArray = await twoDMetropolis(twoDSpinConfig: twoDSpinArray)
        if printSpins {
            await printSpin(spinConfig: twoDSpinArray)
        }
        await addSpinCoordinates(twoDSpinConfig: twoDSpinArray)
    }
    
    func twoDMetropolis(twoDSpinConfig: [[Double]]) async -> [[Double]] {
        var spinToFlip: (i: Int, j: Int)
        spinToFlip.i = Int.random(in: 0..<twoDSpinConfig.count)
        spinToFlip.j = Int.random(in: 0..<twoDSpinConfig.count)
        var trialConfig = twoDSpinConfig
        trialConfig[spinToFlip.i][spinToFlip.j] *= -1.0 // Flip the spin of the random particle
        
        // Get the energies of the configurations
        let trialEnergy = await getConfigEnergy(twoDSpinConfig: trialConfig)
        let prevEnergy = await getConfigEnergy(twoDSpinConfig: twoDSpinConfig)
        
        if (trialEnergy <= prevEnergy) {
            // Accept the trial
            return trialConfig
        }
        else {
            // Accept with relative probability R = exp(-ΔE/kB T)
            let R = exp((-1.0*abs(trialEnergy - prevEnergy))/(kB * temp))
            let r = Double.random(in: 0...1)
            // print("r is \(r) and R is \(R)")
            if (R >= r) { return trialConfig } // Accept the trial
            else { return twoDSpinConfig } // Reject the trial and keep the original spin config
        }
    }
    
    /// getConfigEnergy
    /// Gets the energy value of a two-dimensional spin configuration assuming that B = 0. Also applies Born-von Karman boundary conditions
    /// - Parameters:
    ///   - twoDSpinConfig: the 2D spin configuration with positive values representing spin up and negative representing spin down
    func getConfigEnergy(twoDSpinConfig: [[Double]]) async -> Double {
        //          /   |  --      |    \           --                     --
        // E    =  / a  |  \    V  | a   \  =  - J  \   s  * s     - B μ   \    s
        //   ak    \  k |  /__   i |  k  /          /__  i    i+1        b /__   i
        
        // But for simplicity, we assume B = 0 so the second term drops out
        // We also use Born-von Karman boundary conditions
        
        var energy = 0.0
        for i in 0..<twoDSpinConfig.count {
            for j in 0..<twoDSpinConfig[i].count {
                let BC = await handleBCs(spinLoc: (i: i, j: j))
                energy += -J * (twoDSpinArray[i][j]*twoDSpinArray[BC.i.next][j] + twoDSpinArray[i][j]*twoDSpinArray[i][BC.j.next])
            }
        }
        return energy
    }
    
    /// The last element in the array is coupled with the first element in it
    func handleBCs(spinLoc: (i: Int, j: Int)) async -> (i: (next: Int, prev: Int), j: (next: Int, prev: Int)) {
        // Handle boundary conditions for index i
        var iNext = spinLoc.i + 1
        var iPrev = spinLoc.i - 1
        if (iNext >= twoDSpinArray.count) { iNext = 0 }
        else if (iPrev < 0) { iPrev = twoDSpinArray.count - 1 }
        
        // Handle boundary conditions for index j
        var jNext = spinLoc.j + 1
        var jPrev = spinLoc.j - 1
        if (jNext >= twoDSpinArray.count) { jNext = 0 }
        else if (jPrev < 0) { jPrev = twoDSpinArray.count - 1 }
        
        return (i: (next: iNext, prev: iPrev), j: (next: jNext, prev: jPrev))
    }
    
    func printSpin(spinConfig: [[Double]]) async {
        for i in 0..<spinConfig.count {
            await printSpin(spinConfig: spinConfig[i])
        }
    }
}
