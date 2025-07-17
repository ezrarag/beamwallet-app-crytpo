import SwiftUI

struct BeamAnalyticsView: View {
    // Mock data for investments
    let investmentData: [InvestmentCategory] = [
        InvestmentCategory(name: "Real Estate", totalInvestors: 12450, totalAmount: 4250000, projects: [
            Project(name: "Urban Heights Tower", investors: 3240, amountInvested: 1250000, location: "New York"),
            Project(name: "Sunset Valley Residences", investors: 5120, amountInvested: 1850000, location: "Miami"),
            Project(name: "Tech Hub Campus", investors: 4090, amountInvested: 1150000, location: "Austin")
        ]),
        InvestmentCategory(name: "Commercial", totalInvestors: 8320, totalAmount: 3150000, projects: [
            Project(name: "Downtown Retail Complex", investors: 2180, amountInvested: 950000, location: "Chicago"),
            Project(name: "Innovation Center", investors: 3450, amountInvested: 1350000, location: "San Francisco"),
            Project(name: "Logistics Hub", investors: 2690, amountInvested: 850000, location: "Dallas")
        ]),
        InvestmentCategory(name: "Infrastructure", totalInvestors: 5780, totalAmount: 2850000, projects: [
            Project(name: "Solar Farm Initiative", investors: 3210, amountInvested: 1650000, location: "Arizona"),
            Project(name: "Smart City Grid", investors: 2570, amountInvested: 1200000, location: "Denver")
        ])
    ]
    
    // Selected category for detail view
    @State private var selectedCategory: InvestmentCategory?
    @State private var showingCategoryDetail = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Animated background with BEAM logo outline
                AnimatedLogoBackground()
                
                // Main content
                ScrollView {
                    VStack(spacing: 24) {
                        // Header stats
                        VStack(spacing: 8) {
                            Text("BEAM Ecosystem Analytics")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Real-time investment data across all BEAM projects")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.top, 20)
                        
                        // Total stats card
                        TotalStatsCard(
                            totalInvestors: investmentData.reduce(0) { $0 + $1.totalInvestors },
                            totalInvested: investmentData.reduce(0) { $0 + $1.totalAmount },
                            totalProjects: investmentData.reduce(0) { $0 + $1.projects.count }
                        )
                        
                        // Investment distribution chart
                        InvestmentDistributionChart(categories: investmentData)
                            .frame(height: 240)
                            .padding()
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(16)
                        
                        // Category cards
                        ForEach(investmentData) { category in
                            CategoryCard(category: category)
                                .onTapGesture {
                                    selectedCategory = category
                                    showingCategoryDetail = true
                                }
                        }
                        
                        // Growth metrics
                        GrowthMetricsView()
                    }
                    .padding()
                }
                .sheet(isPresented: $showingCategoryDetail) {
                    if let category = selectedCategory {
                        CategoryDetailView(category: category)
                    }
                }
            }
            .navigationTitle("BEAM Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.white)
                    }
                }
            }
            .background(Color.black)
        }
    }
}

// MARK: - Animated Logo Background (Simplified)
struct AnimatedLogoBackground: View {
    @State private var animationAmount: Double = 1.0
    @State private var glowOpacity: Double = 0.0
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.2), Color.black]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(.all)
            
            // Using SF Symbol as animated logo
            Image(systemName: "cube.transparent")
                .font(.system(size: 200))
                .foregroundColor(.purple.opacity(0.1))
                .overlay(
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 200))
                        .foregroundColor(.purple)
                        .scaleEffect(animationAmount)
                        .opacity(glowOpacity)
                )
                .rotationEffect(.degrees(rotationAngle))
                .onAppear {
                    withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                        animationAmount = 1.1
                        glowOpacity = 0.7
                    }
                    
                    withAnimation(Animation.linear(duration: 20).repeatForever(autoreverses: false)) {
                        rotationAngle = 360
                    }
                }
                .opacity(0.3)
        }
    }
}

// MARK: - Total Stats Card
struct TotalStatsCard: View {
    let totalInvestors: Int
    let totalInvested: Double
    let totalProjects: Int
    
    var body: some View {
        HStack {
            StatItem(
                icon: "person.3.fill",
                value: "\(totalInvestors.formatted())",
                label: "Investors"
            )
            
            Divider()
                .background(Color.white.opacity(0.3))
                .frame(height: 40)
            
            StatItem(
                icon: "dollarsign.circle.fill",
                value: "$\((totalInvested/1000000).formatted()) M",
                label: "Invested"
            )
            
            Divider()
                .background(Color.white.opacity(0.3))
                .frame(height: 40)
            
            StatItem(
                icon: "building.2.fill",
                value: "\(totalProjects)",
                label: "Projects"
            )
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.purple.opacity(0.7), Color.blue.opacity(0.7)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Investment Distribution Chart
struct InvestmentDistributionChart: View {
    let categories: [InvestmentCategory]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Investment Distribution")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(alignment: .bottom, spacing: 16) {
                ForEach(categories) { category in
                    ChartBar(
                        value: Double(category.totalAmount),
                        label: category.name,
                        color: categoryColor(for: category.name)
                    )
                }
            }
            .padding(.top)
            
            // Legend
            HStack(spacing: 16) {
                ForEach(categories) { category in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(categoryColor(for: category.name))
                            .frame(width: 8, height: 8)
                        
                        Text(category.name)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
    }
    
    func categoryColor(for name: String) -> Color {
        switch name {
        case "Real Estate":
            return .purple
        case "Commercial":
            return .blue
        case "Infrastructure":
            return .green
        default:
            return .gray
        }
    }
}

struct ChartBar: View {
    let value: Double
    let label: String
    let color: Color
    
    // Normalize to max height of 150
    private var barHeight: Double {
        let maxValue: Double = 5000000 // $5M as max for scaling
        return min(150 * (value / maxValue), 150)
    }
    
    var body: some View {
        VStack {
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 40, height: 150)
                
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [color.opacity(0.7), color]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 40, height: barHeight)
                    .animation(.spring(), value: barHeight)
            }
            
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 60)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Category Card
struct CategoryCard: View {
    let category: InvestmentCategory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(category.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(category.projects.count) Projects")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            HStack {
                VStack(alignment: .leading) {
                    Text("\(category.totalInvestors.formatted())")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Investors")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("$\((category.totalAmount/1000000).formatted()) M")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Total Invested")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            // Mini chart
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(category.projects) { project in
                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 8, height: Double(project.amountInvested) / 20000)
                }
            }
            .frame(height: 40)
            .padding(.top, 8)
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    categoryColor(for: category.name).opacity(0.3),
                    categoryColor(for: category.name).opacity(0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(categoryColor(for: category.name).opacity(0.5), lineWidth: 1)
        )
    }
    
    func categoryColor(for name: String) -> Color {
        switch name {
        case "Real Estate":
            return .purple
        case "Commercial":
            return .blue
        case "Infrastructure":
            return .green
        default:
            return .gray
        }
    }
}

// MARK: - Growth Metrics View
struct GrowthMetricsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Growth Metrics")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 16) {
                GrowthMetricCard(
                    title: "Monthly Growth",
                    value: "+12.4%",
                    trend: .up,
                    description: "New investors this month"
                )
                
                GrowthMetricCard(
                    title: "Project Completion",
                    value: "86%",
                    trend: .neutral,
                    description: "Average completion rate"
                )
            }
            
            HStack(spacing: 16) {
                GrowthMetricCard(
                    title: "ROI",
                    value: "+8.2%",
                    trend: .up,
                    description: "Average return on investment"
                )
                
                GrowthMetricCard(
                    title: "New Projects",
                    value: "+3",
                    trend: .up,
                    description: "Added this quarter"
                )
            }
        }
    }
}

enum TrendDirection {
    case up, down, neutral
}

struct GrowthMetricCard: View {
    let title: String
    let value: String
    let trend: TrendDirection
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            
            HStack(alignment: .firstTextBaseline) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                switch trend {
                case .up:
                    Image(systemName: "arrow.up.right")
                        .foregroundColor(.green)
                case .down:
                    Image(systemName: "arrow.down.right")
                        .foregroundColor(.red)
                case .neutral:
                    Image(systemName: "arrow.right")
                        .foregroundColor(.yellow)
                }
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Category Detail View
struct CategoryDetailView: View {
    let category: InvestmentCategory
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(category.name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("\(category.projects.count) active projects • \(category.totalInvestors.formatted()) investors")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Stats
                    HStack {
                        StatBox(
                            title: "Total Invested",
                            value: "$\((category.totalAmount/1000000).formatted()) M"
                        )
                        
                        StatBox(
                            title: "Avg. per Investor",
                            value: "$\((category.totalAmount/Double(category.totalInvestors)).formatted())"
                        )
                    }
                    .padding(.horizontal)
                    
                    // Projects list
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Projects")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(category.projects) { project in
                            ProjectRow(project: project)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Category Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ProjectRow: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.headline)
                    
                    Text(project.location)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("\(project.investors.formatted()) investors")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("$\((project.amountInvested/1000000).formatted()) M invested")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            // Progress bar
            ProgressView(value: Double.random(in: 0.3...0.9))
                .tint(.purple)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
}

// MARK: - Data Models
struct InvestmentCategory: Identifiable {
    let id = UUID()
    let name: String
    let totalInvestors: Int
    let totalAmount: Double
    let projects: [Project]
}

struct Project: Identifiable {
    let id = UUID()
    let name: String
    let investors: Int
    let amountInvested: Double
    let location: String
}
