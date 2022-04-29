//
//  ContentView.swift
//  Shared
//
//  Created by Katelyn Lydeen on 4/15/22.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var myModel = TwoDMetropolis()
    @ObservedObject var drawingData = DrawingData(withData: true)
    
    @State var NString = "50" // Number of particles
    @State var tempString = "100.0" // Temperature
    @State var iterationsString = "1000" // Number of iterations for the simulation
    
    @State var selectedStart = "Cold"
    var startOptions = ["Cold", "Hot"]
    
    var body: some View {
        HStack {
            VStack {
                HStack {
                    VStack(alignment: .center) {
                        Text("Number of Particles N")
                            .font(.callout)
                            .bold()
                        TextField("# Number of Particles", text: $NString)
                            .padding()
                    }
                    
                    VStack(alignment: .center) {
                        Text("Temperature (K)")
                            .font(.callout)
                            .bold()
                        TextField("# Temperature (K)", text: $tempString)
                            .padding()
                    }
                    
                    VStack(alignment: .center) {
                        Text("Number of Iterations")
                            .font(.callout)
                            .bold()
                        TextField("# Number of Iterations", text: $iterationsString)
                            .padding()
                    }
                }
                
                VStack {
                    Text("Start Type")
                        .font(.callout)
                        .bold()
                    Picker("", selection: $selectedStart) {
                        ForEach(startOptions, id: \.self) {
                            Text($0)
                        }
                    }
                }
                
                HStack {
                    Button("Run Algorithm Once", action: {Task.init{await self.runAlgorithmOnce()}})
                        .padding()
                        .disabled(myModel.enableButton == false)
                    
                    Button("Run Simulation", action: {Task.init{await self.runMany()}})
                        .padding()
                        .disabled(myModel.enableButton == false)
                    
                    Button("Reset", action: {Task.init{self.reset()}})
                        .padding()
                        .disabled(myModel.enableButton == false)
                }
            }
            
            .padding()
            //DrawingField
            drawingView(redLayer: $drawingData.spinUpData, blueLayer: $drawingData.spinDownData, N: myModel.N, n: myModel.numIterations)
                .padding()
                .aspectRatio(1, contentMode: .fit)
                .drawingGroup()
            // Stop the window shrinking to zero.
            Spacer()
            
        }
        // Stop the window shrinking to zero.
        Spacer()
        Divider()
    }
    
    @MainActor func runAlgorithmOnce() async {
        checkNChange()
        
        myModel.setButtonEnable(state: false)
        
        myModel.printSpins = true
        myModel.N = Int(NString)!
        myModel.temp = Double(tempString)!
        await iterate()
        
        myModel.setButtonEnable(state: true)
    }
    
    @MainActor func runMany() async {
        checkNChange()
        
        myModel.setButtonEnable(state: false)
        
        myModel.printSpins = false
        
        myModel.temp = Double(tempString)!
        myModel.numIterations = Int(iterationsString)!
        
        myModel.newSpinUpPoints = []
        myModel.newSpinDownPoints = []
        
        for _ in 1...Int(iterationsString)! {
            await iterate()
            //sleep(UInt32(1))
            //print("running")
        }
        
        // await myModel.runSimulation(startType: selectedStart)
        
        myModel.setButtonEnable(state: true)
    }
    
    @MainActor func iterate() async {
        await myModel.iterateTwoDMetropolis(startType: selectedStart)
        drawingData.spinUpData = myModel.newSpinUpPoints
        drawingData.spinDownData = myModel.newSpinDownPoints
    }
    
    func checkNChange() {
        let prevN = myModel.N
        myModel.N = Int(NString)!
        if (prevN != myModel.N) {
            self.reset()
        }
    }
    
    @MainActor func reset() {
        myModel.setButtonEnable(state: false)
        
        myModel.mySpin.spinArray = []
        myModel.twoDSpinArray = []
        if(myModel.printSpins) {
            print("\nNew Config")
        }
        
        drawingData.clearData()
        
        myModel.setButtonEnable(state: true)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
