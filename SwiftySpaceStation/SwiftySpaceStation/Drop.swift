//
//  Drop.swift
//  SwiftySpaceStation
//
//  Created by Tomer Zed on 4/20/23.
//

import Foundation
import SwiftUI


enum ResourceType: String, CaseIterable, Identifiable {
    case water = "Water"
    case electricity = "Electricity"
    case oxygen = "Oxygen"
    case carbonDioxide = "Carbon Dioxide"
    
    var id: String { self.rawValue }
}

class Resource: ObservableObject, Hashable, Identifiable {
        
    let id = UUID()
    let type: ResourceType
    @Published var currentAmount: Double
    let maxAmount: Double
    
    init(type: ResourceType, currentAmount: Double, maxAmount: Double) {
        self.type = type
        self.currentAmount = currentAmount
        self.maxAmount = maxAmount
    }
    
    var isCharged: Bool {
        return currentAmount >= maxAmount
    }
    
    static func == (lhs: Resource, rhs: Resource) -> Bool {
        return lhs.type == rhs.type
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(currentAmount)
        hasher.combine(maxAmount)
        hasher.combine(type)
    }
}

class ResourceStorage: ObservableObject, Identifiable, Hashable {
    let id = UUID()
    @Published var resources: [Resource]
    
    init(resources: [Resource]) {
        self.resources = resources
    }
    
    func charge() {
        for i in resources.indices {
            resources[i].currentAmount = resources[i].maxAmount
        }
    }
    
    var isCharged: Bool {
        return resources.allSatisfy { $0.isCharged }
    }
    
    func getResource(ofType type: ResourceType) -> Resource? {
        return resources.first(where: { $0.type == type })
    }
    
    func addResource(ofType type: ResourceType, amount: Double) {
        guard let index = resources.firstIndex(where: { $0.type == type }) else { return }
        resources[index].currentAmount += amount
    }
    
    func removeResource(ofType type: ResourceType, amount: Double) {
        guard let index = resources.firstIndex(where: { $0.type == type }) else { return }
        resources[index].currentAmount -= amount
    }
    
    func hasSufficientResources(requiredResources: [ResourceType: Double]) -> Bool {
        for (type, requiredAmount) in requiredResources {
            guard let resource = getResource(ofType: type) else { return false }
            if resource.currentAmount < requiredAmount {
                return false
            }
        }
        return true
    }
    
    // Implement the hash function
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Implement the == function for the Equatable protocol
    static func == (lhs: ResourceStorage, rhs: ResourceStorage) -> Bool {
        return lhs.id == rhs.id
    }
}



class ResourceAgent: ObservableObject, Hashable, Identifiable {
    let id = UUID()
    @Published var rates: [ResourceType : Double]
    
    static func == (lhs: ResourceAgent, rhs: ResourceAgent) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(rates)
    }
    
    init(rates: [ResourceType:Double]) {
        self.rates = rates
    }
}

class Astronaut: ResourceAgent {
    var name: String
    var mass: Double
    var metabolism: Metabolism
    
    init(name: String, mass: Double, metabolism: Metabolism, rates: [ResourceType : Double]) {
        self.name = name
        self.mass = mass
        self.metabolism = metabolism
        super.init(rates: rates)
    }
}

class Plant: ResourceAgent {
    var mass: Double
    init(mass: Double, rates: [ResourceType:Double]) {
        self.mass = mass
        super.init(rates: rates)
    }
}


enum Metabolism {
    case slow, fast
}

class Module: ObservableObject, Hashable, Identifiable {
    let id = UUID()
    var title: String
    @Published var resourceStorages: [ResourceStorage]
    @Published var agents: [ResourceAgent]
    @Published var isActive: Bool
    
    init(title: String, resourceStorages: [ResourceStorage], agents: [ResourceAgent], isActive: Bool) {
        self.title = title
        self.resourceStorages = resourceStorages
        self.agents = agents
        self.isActive = isActive
    }
    
    var allStoragesCharged: Bool {
        return resourceStorages.allSatisfy { $0.isCharged }
    }
    
    static func == (lhs: Module, rhs: Module) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)  // Add this line
        hasher.combine(resourceStorages)
        hasher.combine(agents)
        hasher.combine(isActive)
    }
    
    
    func activate() {
        self.isActive = true
    }
    
    func run() {
        guard isActive else { return }
        
        for agent in agents {
            for (type, rate) in agent.rates {
                for resourceStorage in resourceStorages {
                    if let resource = resourceStorage.getResource(ofType: type) {
                        resourceStorage.removeResource(ofType: type, amount: rate * Double(resourceStorage.resources.count) * resource.maxAmount)
                    }
                }
            }
        }
        
        var hasSufficientResources = true
        for resourceStorage in resourceStorages {
            let requiredResources: [ResourceType: Double] = [:]  // check for all resources
            if !resourceStorage.hasSufficientResources(requiredResources: requiredResources) {
                hasSufficientResources = false
                break
            }
        }
        
        if !hasSufficientResources {
            self.isActive = false
        }
    }

}


class Station: ObservableObject {
    let id = UUID()
    @Published var modules: [Module]
    @Published var roster: Roster
    
    init(modules: [Module], roster: Roster) {
        self.modules = modules
        self.roster = roster
    }
    
    var totalResources: [ResourceType: Double] {
        var totals: [ResourceType: Double] = [:]
        
        for module in modules {
            for resourceStorage in module.resourceStorages {
                for resource in resourceStorage.resources {
                    if let currentTotal = totals[resource.type] {
                        totals[resource.type] = currentTotal + resource.currentAmount
                    } else {
                        totals[resource.type] = resource.currentAmount
                    }
                }
            }
        }
        
        return totals
    }



    
}

class Roster: ObservableObject {
    let id = UUID()
    @Published var astronauts: [Astronaut]
    
    init(astronauts: [Astronaut]) {
        self.astronauts = astronauts
    }
    
    func run(station: Station) {
        for astronaut in astronauts {
            for module in station.modules {
                for (type, rate) in astronaut.rates {
                    for resourceStorage in module.resourceStorages {
                        if resourceStorage.getResource(ofType: type) != nil {
                            resourceStorage.removeResource(ofType: type, amount: rate * astronaut.mass)
                        }
                    }
                }
            }
        }
    }

}
struct ModuleView: View {
    @ObservedObject var module: Module
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(module.title)
                .font(.headline)
            
            HStack {
                Text("Charged/Ready:")
                Text(module.allStoragesCharged ? "Yes" : "No")
            }
            
            HStack {
                Text("Activated:")
                Text(module.isActive ? "Yes" : "No")
            }
            
            ForEach(module.resourceStorages) { resourceStorage in
                ForEach(resourceStorage.resources) { resource in
                    VStack(alignment: .leading) {
                        Text(resource.type.rawValue)
                            .font(.subheadline)
                        
                        ProgressBar(
                            value: resource.currentAmount,
                            maxValue: resource.maxAmount,
                            backgroundColor: Color.gray.opacity(0.3),
                            foregroundColor: Color.blue
                        )
                        .frame(height: 10)
                    }
                }
            }
            
        
            
            ForEach(module.resourceStorages) { resourceStorage in
                ForEach(resourceStorage.resources) { resource in
                    ResourceRow(resource: resource)
                }
            }
            
            Button(action: {
                for i in 0..<module.resourceStorages.count {
                    for j in 0..<module.resourceStorages[i].resources.count {
                        module.resourceStorages[i].resources[j].currentAmount = module.resourceStorages[i].resources[j].maxAmount
                    }
                }
            }) {
                Text("Charge")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }

            
            if module.allStoragesCharged {
                Button(action: {
                    module.isActive.toggle()
                }) {
                    Text(module.isActive ? "Deactivate" : "Activate")
                        .padding()
                        .background(module.isActive ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
    }
}



struct StationView: View {
    @ObservedObject var station: Station
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Total Resources")) {
                    ForEach(ResourceType.allCases) { resourceType in
                        HStack {
                            Text(resourceType.rawValue)
                            Spacer()
                            Text("\(station.totalResources[resourceType] ?? 0, specifier: "%.2f")")
                        }
                    }
                }

                Section(header: Text("Station")) {
                    ForEach(station.modules) { module in
                        ModuleView(module: module)
                            .padding(.vertical)
                    }
                }
            }
            .listStyle(GroupedListStyle())
            .navigationTitle("Space Station")
        }
    }
}

//struct ContentView: View {
//    @StateObject var station = Station(modules: [], roster: Roster(astronauts: []))
//
//    var body: some View {
//        StationView(station: station)
//    }
//}

struct ContentView: View {
    @StateObject var station: Station
    @StateObject var roster: Roster
    
    init() {
        let sampleData = createSampleData()
        _station = StateObject(wrappedValue: sampleData.0)
        _roster = StateObject(wrappedValue: sampleData.1)
    }
    
    var body: some View {
        StationView(station: station)
    }
}


struct ResourceRow: View {
    @ObservedObject var resource: Resource  // Change this line
    
    var body: some View {
        HStack {
            Text(resource.type.rawValue.uppercased())
            Text("\(resource.currentAmount, specifier: "%.2f")")
        }
    }
}



struct ModuleResourceStoragesView: View {
    @ObservedObject var module: Module
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("\(module.title)")
                .font(.headline)
            ForEach(module.resourceStorages) { resourceStorage in
                VStack(alignment: .leading) {
                    Text("Resource Storage")
                        .font(.subheadline)
                    ForEach(resourceStorage.resources) { resource in
                        ResourceRow(resource: resource)
                    }
                    Text("Charged: \(resourceStorage.isCharged ? "Yes" : "No")")
                }
            }
        }
    }
}


func createSampleData() -> (Station, Roster) {
    let waterResource = Resource(type: .water, currentAmount: 1000, maxAmount: 2000)
    let electricityResource = Resource(type: .electricity, currentAmount: 5000, maxAmount: 10000)
    let oxygenResource = Resource(type: .oxygen, currentAmount: 800, maxAmount: 2000)
    let carbonDioxideResource = Resource(type: .carbonDioxide, currentAmount: 0, maxAmount: 1000)
    
    let resourceStorage = ResourceStorage(resources: [waterResource, electricityResource, oxygenResource, carbonDioxideResource])
    
    let ratesAstronaut1: [ResourceType: Double] = [
        .water: 3.0,
        .electricity: 100,
        .oxygen: 0.8,
        .carbonDioxide: -0.8
    ]
    let astronaut1 = Astronaut(name: "Alice", mass: 70, metabolism: .fast, rates: ratesAstronaut1)
    
    let ratesAstronaut2: [ResourceType: Double] = [
        .water: 2.5,
        .electricity: 90,
        .oxygen: 0.7,
        .carbonDioxide: -0.7
    ]
    let astronaut2 = Astronaut(name: "Bob", mass: 80, metabolism: .slow, rates: ratesAstronaut2)
    
    let ratesPlant: [ResourceType: Double] = [
        .water: -0.1,
        .electricity: 0,
        .oxygen: -1.0,
        .carbonDioxide: 10.0
    ]
    let plant = Plant(mass: 10, rates: ratesPlant)
    
    let module1 = Module(title: "Habitation Module", resourceStorages: [resourceStorage], agents: [astronaut1, astronaut2], isActive: true)
    let module2 = Module(title: "Greenhouse Module", resourceStorages: [resourceStorage], agents: [plant], isActive: true)
    
    let station = Station(modules: [module1, module2], roster: Roster(astronauts: [astronaut1, astronaut2]))
    
    return (station, station.roster)
}


struct ProgressBar: View {
    var value: Double
    var maxValue: Double
    var backgroundColor: Color
    var foregroundColor: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .foregroundColor(backgroundColor)
                Rectangle()
                    .frame(width: geometry.size.width * CGFloat(value / maxValue), height: geometry.size.height)
                    .foregroundColor(foregroundColor)
            }
            .cornerRadius(8)
        }
    }
}
