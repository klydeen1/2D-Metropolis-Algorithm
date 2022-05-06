//
//  OneDMetropolis.swift
//  1D-Metropolis-Algorithm
//
//  Created by Katelyn Lydeen on 3/25/22.
//

import Foundation
import SwiftUI

class IsingModel: NSObject, ObservableObject {
    // @MainActor @Published var spinUpData = [(xPoint: Double, yPoint: Double)]()
    // @MainActor @Published var spinDownData = [(xPoint: Double, yPoint: Double)]()
    
    @Published var OneDSpins: [Double] = []
    @Published var enableButton = true
    
    @Published var magString = ""
    @Published var spHeatString = ""
    @Published var energyString = ""
    
    var mySpin = OneDSpin()
    var N = 100 // Number of particles
    var numIterations = 1000
    
    var Mj = 0.0 // Magnetization
    var C = 0.0 // Specific heat
    var U = 0.0 // Internal energy
    var temp = 273.15 // Temperature in Kelvin
    let J = 1.0 // The exchange energy in units 1e-21 Joules
    let kB = 0.01380649 // Boltzmann constant in units 1e-21 Joules/Kelvin
    
    var printSpins = false
    
    var newSpinUpPoints: [(xPoint: Double, yPoint: Double)] = []
    var newSpinDownPoints: [(xPoint: Double, yPoint: Double)] = []
    
    /// iterateMetropolis
    /// Runs the 1D Metropolis algorithm once and prints the resulting configuration
    /// Also sets and prints the initial spin array if the array is empty
    /// - Parameters:
    ///   - startType: the starting configuration for the spin array. value "hot" means we start with random spins. "cold" means the spins are ordered
    func iterateMetropolis(startType: String) async {
        if (mySpin.spinArray.isEmpty) {
            await initializeSpin(startType: startType)
            Mj = 0.0
            for i in 0..<mySpin.spinArray.count {
                Mj += mySpin.spinArray[i]
            }
        }

        let newSpinArray = await metropolis(spinConfig: mySpin.spinArray)
        if printSpins {
            await printSpin(spinConfig: newSpinArray)
        }
        mySpin.spinArray = newSpinArray
    }
    
    func runSimulation(startType: String) async {
        newSpinUpPoints = []
        newSpinDownPoints = []
        
        var ESum = 0.0
        var ESumCount = 0
        var ESquaredSum = 0.0
        for x in 1...numIterations {
            await iterateMetropolis(startType: startType)
            await addSpinCoordinates(spinConfig: mySpin.spinArray, xCoord: Double(x))
            if(x > numIterations/2) {
                ESum += mySpin.energy
                ESquaredSum += mySpin.energy*mySpin.energy
                ESumCount += 1
            }
        }
        print("energy: \(await getConfigEnergy(spinConfig: mySpin.spinArray))")
        print("mag: \(Mj)")
        U = ESum / Double(ESumCount)
        print("internal energy: \(U)")
        let ESquaredAvg = ESquaredSum / Double(ESumCount)
        print("energy fluctuations: \(ESquaredAvg)")
        C = 1/Double(N*N) * (ESquaredAvg - U*U)/(kB*temp*temp)
        print("specific heat: \(C)")
        print()
    }
    
    /// initializeSpin
    /// Sets the initial spin array in either a "hot" or "cold" configuration and prints that starting configuration
    /// - Parameters:
    ///   - startType: the starting configuration for the spin array. value "hot" means we start with random spins. "cold" means the spins are ordered
    func initializeSpin(startType: String) async {
        switch(startType.lowercased()) {
        case "hot":
            await mySpin.hotStart(N: N)
            
        case "cold":
            await mySpin.coldStart(N: N)
            
        default:
            await mySpin.hotStart(N: N)
        }
        if printSpins {
            await printSpin(spinConfig: mySpin.spinArray) // Print the starting spin array
        }
        await addSpinCoordinates(spinConfig: mySpin.spinArray, xCoord: 0.0)
    }
    
    /// metropolis
    /// Function to run the 1D Metropolis algorithm once
    /// - Parameters:
    ///   - spinConfig: the 1D spin configuration with positive values representing spin up and negative representing spin down
    /// - returns: the new spin configuration which is either the original configuration or a new one where one random spin is flipped
    func metropolis(spinConfig: [Double]) async -> [Double] {
        // var newSpinConfig: [Double] = []
        let spinToFlip = Int.random(in: 0..<spinConfig.count) // Pick a random particle
        var trialConfig = spinConfig
        trialConfig[spinToFlip] *= -1.0 // Flip the spin of the random particle
        
        // Get the energies of the configurations
        let trialEnergy = await getConfigEnergy(spinConfig: trialConfig)
        let prevEnergy = await getConfigEnergy(spinConfig: spinConfig)
        let R = exp((-1.0*abs(trialEnergy - prevEnergy))/(kB * temp))
        let r = Double.random(in: 0...1)
        
        // Accept if the trial energy is lower than the prev energy
        // Otherwise, accept with relative probability R = exp(-ΔE/kB T)
        if (trialEnergy <= prevEnergy || R >= r) {
            // Accept the trial
            Mj += 2*trialConfig[spinToFlip]
            mySpin.energy = trialEnergy
            return trialConfig
        }
        else {
            // Reject the trial and keep the original spin config
            mySpin.energy = prevEnergy
            return spinConfig
        }
    }
    
    /// getConfigEnergy
    /// Gets the energy value of a spin configuration assuming that B = 0. Also applies Born-von Karman boundary conditions
    /// - Parameters:
    ///   - spinConfig: the 1D spin configuration with positive values representing spin up and negative representing spin down
    func getConfigEnergy(spinConfig: [Double]) async -> Double {
        //          /   |  --      |    \           --                     --
        // E    =  / a  |  \    V  | a   \  =  - J  \   s  * s     - B μ   \    s
        //   ak    \  k |  /__   i |  k  /          /__  i    i+1        b /__   i
        
        // But for simplicity, we assume B = 0 so the second term drops out
        // We also use Born-von Karman boundary conditions
        
        var energy = 0.0
        for i in 0..<spinConfig.count {
            if (i == (spinConfig.count-1)) {
                // Couple the last particle in the array to the first particle in it
                energy += -J * spinConfig[0] * spinConfig[i]
            }
            else {
                // Couple the current particle (index i) with the next one (index i+1)
                energy += -J * spinConfig[i] * spinConfig[i+1]
            }
        }
        return energy
    }
    
    /// printSpin
    /// Prints the current spin configuration with + representing a spin up particle and - representing a spin down particle
    /// - Parameters:
    ///   - spinConfig: the 1D spin configuration with positive values representing spin up and negative representing spin down
    func printSpin(spinConfig: [Double]) async {
        var spinString = ""
        for i in 0..<spinConfig.count {
            if (spinConfig[i] < 0) { spinString += "-" }
            else { spinString += "+" }
        }
        print(spinString)
    }
    
    /// addSpinCoordinates
    /// Determines whether each particle in a 1D configuration is spin up or spin down. Adds a coordinate point for each particle to either
    /// newSpinUpPoints or newSpinDownPoints depending on the spin.
    /// - Parameters:
    ///    - spinConfig: the 1D spin configuration with positive values representing spin up and negative representing spin down
    ///    - xCoord: the x-coordinate to use for all particles in the configuration spinConfig
    func addSpinCoordinates(spinConfig: [Double], xCoord: Double) async {
        for i in 0..<spinConfig.count {
            if (spinConfig[i] < 0) {
                newSpinDownPoints.append((xPoint: xCoord, yPoint: Double(i)))
            }
            else {
                newSpinUpPoints.append((xPoint: xCoord, yPoint: Double(i)))
            }
        }
    }
    
    /// updateMagnetizationString
    /// The function runs on the main thread so it can update the GUI
    /// - Parameter text: contains the string containing the current value of the magnetization
    @MainActor func updateMagnetizationString(text:String) async {
        self.magString = text
    }
    
    /// updateSpecificHeatString
    /// The function runs on the main thread so it can update the GUI
    /// - Parameter text: contains the string containing the current value of the specific heat
    @MainActor func updateSpecificHeatString(text:String) async {
        self.spHeatString = text
    }
    
    /// updateInternalEnergyString
    /// The function runs on the main thread so it can update the GUI
    /// - Parameter text: contains the string containing the current value of the internal energy
    @MainActor func updateInternalEnergyString(text:String) async {
        self.energyString = text
    }
    
    /// setButton Enable
    /// Toggles the state of the Enable Button on the Main Thread
    /// - Parameter state: Boolean describing whether the button should be enabled.
    @MainActor func setButtonEnable(state: Bool) {
        if state {
            Task.init {
                await MainActor.run { self.enableButton = true }
            }
        }
        else{
            Task.init { await MainActor.run { self.enableButton = false }
            }
        }
    }
}
