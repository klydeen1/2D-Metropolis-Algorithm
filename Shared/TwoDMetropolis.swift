//
//  TwoDMetropolis.swift
//  2D-Metropolis-Algorithm
//
//  Created by Katelyn Lydeen on 4/29/22.
//

import Foundation
import SwiftUI

class TwoDMetropolis: IsingModel {
    @ObservedObject var drawingData = DrawingData(withData: true)
    
    var twoDSpinArray: [[Double]] = []
    var twoDEnergy = 0.0
    
    func initializeTwoDSpin(startType: String) async {
        twoDSpinArray = []
        Mj = 0.0
        for _ in 0..<N {
            await initializeSpin(startType: startType)
            twoDSpinArray.append(mySpin.spinArray)
            for i in 0..<mySpin.spinArray.count {
                Mj += mySpin.spinArray[i]
            }
        }
        await twoDEnergy = getConfigEnergy(twoDSpinConfig: twoDSpinArray)
    }
    
    override func runSimulation(startType: String) async {
        var ESum = 0.0
        var ESumCount = 0
        var ESquaredSum = 0.0
        
        for i in 1...numIterations {
            newSpinUpPoints = []
            newSpinDownPoints = []
            
            await iterateTwoDMetropolis(startType: startType)
            
            if (i > numIterations/2) {
                await ESum += twoDEnergy
                await ESquaredSum += twoDEnergy*twoDEnergy
                ESumCount += 1
            }
            
        }
        //print("energy: \(await getConfigEnergy(twoDSpinConfig: twoDSpinArray))")
        U = ESum / Double(ESumCount)
        let ESquaredAvg = ESquaredSum / Double(ESumCount)
        //print("energy fluctuations: \(ESquaredAvg)")
        C = 1/Double(N*N*N*N) * (ESquaredAvg - U*U)/(kB*temp*temp)
        
        await updateInternalEnergyString(text: "\(U)")
        await updateMagnetizationString(text: "\(Mj)")
        await updateSpecificHeatString(text: "\(C)")
    }
    
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
        await updatePlotCoords(spinUpData: newSpinUpPoints, spinDownData: newSpinDownPoints)
    }
    
    func twoDMetropolis(twoDSpinConfig: [[Double]]) async -> [[Double]] {
        var spinToFlip: (i: Int, j: Int)
        spinToFlip.i = Int.random(in: 0..<twoDSpinConfig.count)
        spinToFlip.j = Int.random(in: 0..<twoDSpinConfig.count)
        var trialConfig = twoDSpinConfig
        trialConfig[spinToFlip.i][spinToFlip.j] *= -1.0 // Flip the spin of the random particle
        
        // Get the energies of the configurations
        let trialEnergy = await getConfigEnergy(twoDSpinConfig: trialConfig)
        // let prevEnergy = await getConfigEnergy(twoDSpinConfig: twoDSpinConfig) // using variable twoDEnergy is faster
        
        let R = exp((-1.0*abs(trialEnergy - twoDEnergy))/(kB * temp))
        let r = Double.random(in: 0...1)

        // Accept if the trial energy is lower than the prev energy
        // Otherwise, accept with relative probability R = exp(-ΔE/kB T)
        if (trialEnergy <= twoDEnergy || R >= r) {
            // Accept the trial
            Mj += 2*trialConfig[spinToFlip.i][spinToFlip.j]
            twoDEnergy = trialEnergy
            return trialConfig
        }
        else {
            // Reject the trial and keep the original spin config
            return twoDSpinConfig
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
                //energy += -J * (twoDSpinArray[i][j]*twoDSpinArray[BC.i.next][j] + twoDSpinArray[i][j]*twoDSpinArray[i][BC.j.next])
                energy += -J * (twoDSpinArray[i][j] * twoDSpinArray[BC.i.next][j] * twoDSpinArray[i][BC.j.next])
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
    
    @MainActor func updatePlotCoords(spinUpData: [(xPoint: Double, yPoint: Double)], spinDownData: [(xPoint: Double, yPoint: Double)]) async {
        self.drawingData.spinUpData = spinUpData
        self.drawingData.spinDownData = spinDownData
    }
}
