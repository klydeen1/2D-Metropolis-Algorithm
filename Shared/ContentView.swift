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
    
    @State var spinUpPoints = [(xPoint: Double, yPoint: Double)]()
    @State var spinDownPoints = [(xPoint: Double, yPoint: Double)]()
    
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
            //drawingView(redLayer: drawingData.spinUpData, blueLayer: drawingData.spinDownData, N: myModel.N, n: myModel.numIterations)
            //drawingView(redLayer: self.spinUpPoints, blueLayer: self.spinDownPoints, N: myModel.N, n: myModel.numIterations)
            
            ZStack{
                drawSpins(drawingPoints: self.spinUpPoints, numParticles: myModel.N, numIterations: myModel.numIterations)
                    .stroke(Color.red)
                
                drawSpins(drawingPoints: self.spinDownPoints, numParticles: myModel.N, numIterations: myModel.numIterations)
                    .stroke(Color.blue)
            }
             
            .background(Color.white)
            .aspectRatio(1, contentMode: .fill)
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
        checkParameterChange()
        
        myModel.setButtonEnable(state: false)
        
        myModel.printSpins = true
        await iterate()
        
        myModel.setButtonEnable(state: true)
    }
    
    @MainActor func runMany() async {
        checkParameterChange()
        
        myModel.setButtonEnable(state: false)
        
        myModel.printSpins = false
        
        myModel.numIterations = Int(iterationsString)!
        
        myModel.newSpinUpPoints = []
        myModel.newSpinDownPoints = []
        
        for _ in 1...Int(iterationsString)! {
            await iterate()
        }
        
        // await myModel.runSimulation(startType: selectedStart)
        
        myModel.setButtonEnable(state: true)
    }
    
    @MainActor func iterate() async {
        await myModel.iterateTwoDMetropolis(startType: selectedStart)
        drawingData.spinUpData = myModel.newSpinUpPoints
        drawingData.spinDownData = myModel.newSpinDownPoints
        //sleep(UInt32(2.0))
        //print("delayed")
        updatePoints()
    }
    
    func checkParameterChange() {
        let prevN = myModel.N
        let prevT = myModel.temp
        myModel.N = Int(NString)!
        myModel.temp = Double(tempString)!
        if (prevN != myModel.N || prevT != myModel.temp) {
            self.reset()
        }
    }
    
    func updatePoints() {
        self.spinUpPoints = drawingData.spinUpData
        self.spinDownPoints = drawingData.spinDownData
    }
    
    @MainActor func reset() {
        myModel.setButtonEnable(state: false)
        
        myModel.mySpin.spinArray = []
        myModel.twoDSpinArray = []
        if(myModel.printSpins) {
            print("\nNew Config")
        }
        
        drawingData.clearData()
        updatePoints()
        
        myModel.setButtonEnable(state: true)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
