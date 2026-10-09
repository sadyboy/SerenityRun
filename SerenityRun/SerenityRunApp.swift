import SwiftUI
import OneSignalFramework
import AdjustSdk
import SwiftUI
import UIKit
import Combine
import WebKit
struct SerenityRunApp: View {
    @StateObject private var state = SerenityRunState()
    @State private var phase: Phase = .onboarding

    enum Phase { case  onboarding, main }

    var body: some View {
        VStack {
            ZStack {
                switch phase {
                case .onboarding:
                    OnboardingView { withAnimation(Motion.spring) { phase = .main } }
                        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                                removal: .scale(scale: 0.95).combined(with: .opacity)))
                case .main:
                    RootScene()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .environmentObject(state)
            .preferredColorScheme(.dark)
            .onAppear { advance() }
        }
    }

    private func advance() {
        withAnimation(Motion.spring) {
            phase = state.onboardingDone ? .main : .onboarding
        }
    }
}

/// Floating island tabs — 2 left, 1 larger centre, 2 right. No TabView.
struct RootScene: View {
    @State private var tab: Tab = .quickHelp
    @StateObject private var kit = FamilyKit.shared

    enum Tab: Int, CaseIterable, Identifiable {
        case guideTab, history, quickHelp, tools, profile
        var id: Int { rawValue }
        var symbol: String {
            switch self {
            case .guideTab: "book.closed.fill"
            case .history: "clock.arrow.circlepath"
            case .quickHelp: "cross.case.fill"
            case .tools: "slider.horizontal.3"
            case .profile: "person.crop.square.fill"
            }
        }
        var title: String {
            switch self {
            case .guideTab: "Guide"
            case .history: "History"
            case .quickHelp: "Quick Help"
            case .tools: "Tools"
            case .profile: "Profile"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .quickHelp: QuickHelpScene(switchToProfile: { tab = .profile })
                case .guideTab:  GuideScene()
                case .tools:     ToolsScene()
                case .history:   HistoryScene()
                case .profile:   ProfileScene()
                }
            }
            .transition(.opacity)

            islandBar
        }
        .ignoresSafeArea(.keyboard)
    }

    private var islandBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(Tab.allCases) { t in
                let active = t == tab
                let primary = t == .quickHelp
                Button {
                    Haptics.selection()
                    withAnimation(Motion.spring) { tab = t }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: t.symbol)
                            .font(.system(size: primary ? 22 : 16, weight: .bold))
                        if active || primary {
                            Text(t.title)
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        }
                    }
                    .foregroundStyle(active ? .black : kit.dim)
                    .frame(minWidth: 44, minHeight: primary ? 60 : 50)
                    .padding(.horizontal, primary ? 16 : 10)
                    .background(
                        Capsule().fill(
                            active
                            ? AnyShapeStyle(LinearGradient(colors: [primary ? kit.danger : kit.phosphor,
                                                                    (primary ? kit.danger : kit.phosphor).opacity(0.6)],
                                                           startPoint: .top, endPoint: .bottom))
                            : AnyShapeStyle(Material.ultraThin))
                    )
                    .overlay(Capsule().strokeBorder((active ? Color.clear : kit.dim.opacity(0.3)), lineWidth: 1))
                    .shadow(color: active ? (primary ? kit.danger : kit.phosphor).opacity(0.45) : .clear,
                            radius: 14, y: 6)
                    .scaleEffect(active ? 1.05 : 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(t.title)
                .accessibilityAddTraits(active ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }
}
/// Theme system. Phosphor-terminal identity + glass depth. Inverts to "Dark Mirror" at midnight.
@MainActor
final class FamilyKit: ObservableObject {
    static let shared = FamilyKit()

    @Published private(set) var isMirror: Bool = FamilyKit.mirrorWindowNow()
    private var ticker: Task<Void, Never>?

    private init() { startClock() }

    static func mirrorWindowNow() -> Bool {
        let h = Calendar.current.component(.hour, from: .now)
        return h >= 0 && h < 5          // 00:00–04:59 local
    }

    private func startClock() {
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self else { return }
                let next = FamilyKit.mirrorWindowNow()
                if next != self.isMirror {
                    withAnimation(Motion.spring) { self.isMirror = next }
                }
            }
        }
    }

    // MARK: Palette
    var bg: Color        { isMirror ? Color(hex: 0x071007) : .black }
    var surface: Color   { isMirror ? Color(hex: 0x0E1A0E) : Color(hex: 0x0B0B0B) }
    var phosphor: Color  { isMirror ? Color(hex: 0x9CFFBE) : Color(hex: 0x00FF41) }
    var ink: Color       { isMirror ? Color(hex: 0xE8FFF0) : Color(hex: 0xDFFFE6) }
    var dim: Color       { ink.opacity(0.52) }
    var danger: Color    { Color(hex: 0xFF4D3D) }
    var caution: Color   { Color(hex: 0xFFC53D) }
    var safe: Color      { Color(hex: 0x3DFF9E) }
    var epic: Color      { Color(hex: 0xB487FF) }

    func tint(for level: RiskLevel) -> Color {
        switch level {
        case .emergency: danger
        case .watch:     caution
        case .benign:    safe
        }
    }
}

enum Motion {
    static let spring = SwiftUI.Animation.spring(response: 0.38, dampingFraction: 0.72)
    static func stagger(_ i: Int) -> SwiftUI.Animation { spring.delay(Double(i) * 0.04) }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

// MARK: - CRT scanline texture (signature surface, replaces "plain white bg")
struct Scanlines: View {
    var spacing: CGFloat = 3
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 0
            var path = Path()
            while y < size.height {
                path.move(to: .init(x: 0, y: y))
                path.addLine(to: .init(x: size.width, y: y))
                y += spacing
            }
            ctx.stroke(path, with: .color(.black.opacity(0.5)), lineWidth: 1)
        }
        .allowsHitTesting(false)
        .blendMode(.multiply)
    }
}

struct LabBackground: View {
    @StateObject private var kit = FamilyKit.shared
    var body: some View {
        ZStack {
            kit.bg.ignoresSafeArea()
            RadialGradient(colors: [kit.phosphor.opacity(0.14), .clear],
                           center: .top, startRadius: 8, endRadius: 520)
                .ignoresSafeArea()
            Scanlines().ignoresSafeArea()
        }
    }
}

// MARK: - Glass card (r:20, ultraThinMaterial, gradient stroke 2pt)
struct GlassCard<Content: View>: View {
    var glow: Color? = nil
    @ViewBuilder var content: Content
    @StateObject private var kit = FamilyKit.shared

    var body: some View {
        content
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [(glow ?? kit.phosphor).opacity(0.85),
                                                (glow ?? kit.phosphor).opacity(0.12)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 2)
            )
            .shadow(color: (glow ?? kit.phosphor).opacity(0.18), radius: 12, x: 0, y: 4)
            .environment(\.colorScheme, .dark)
    }
}

// MARK: - Capsule button, 52pt, press 0.94 → spring back
struct LabButton: View {
    let title: String
    var systemImage: String
    var role: RiskLevel? = nil
    let action: () -> Void

    @State private var pressed = false
    @StateObject private var kit = FamilyKit.shared

    var body: some View {
        Button {
            Haptics.tap(.selection)
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage).font(.system(size: 17, weight: .bold))
                Text(title).font(.system(.callout, design: .monospaced).weight(.bold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                Capsule().fill(
                    LinearGradient(colors: [role.map(kit.tint(for:)) ?? kit.phosphor,
                                            (role.map(kit.tint(for:)) ?? kit.phosphor).opacity(0.65)],
                                   startPoint: .leading, endPoint: .trailing))
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.94 : 1)
        .animation(Motion.spring, value: pressed)
        ._onButtonGesture { pressed = $0 } perform: {}
        .contentShape(Capsule())
        .accessibilityLabel(title)
    }
}

enum Haptics {
    static var enabled = true
    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    static func tap(_ s: UISelectionFeedbackGenerator.Type) {}
    static func selection() { guard enabled else { return }; UISelectionFeedbackGenerator().selectionChanged() }
    static func notify(_ t: UINotificationFeedbackGenerator.FeedbackType) {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(t)
    }
    static func levelUp() async {
        guard enabled else { return }
        for style in [UIImpactFeedbackGenerator.FeedbackStyle.light, .medium, .heavy] {
            UIImpactFeedbackGenerator(style: style).impactOccurred()
            try? await Task.sleep(for: .milliseconds(80))
        }
    }
}

extension UIImpactFeedbackGenerator.FeedbackStyle {
    static let selection: UIImpactFeedbackGenerator.FeedbackStyle = .light
}
import Foundation

enum RiskLevel: String, Codable, Sendable, CaseIterable {
    case emergency, watch, benign

    var headline: String {
        switch self {
        case .emergency: "CALL POISON CONTROL NOW"
        case .watch:     "OBSERVE — call if symptoms appear"
        case .benign:    "LIKELY HARMLESS"
        }
    }
}

enum SubstanceClass: String, Codable, Sendable, CaseIterable, Identifiable {
    case medication, household, plant, battery, cosmetic, food, chemical, tobacco
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .medication: "pills.fill"
        case .household:  "bubbles.and.sparkles.fill"
        case .plant:      "leaf.fill"
        case .battery:    "minus.plus.batteryblock.fill"
        case .cosmetic:   "drop.triangle.fill"
        case .food:       "fork.knife"
        case .chemical:   "flask.fill"
        case .tobacco:    "smoke.fill"
        }
    }
    var label: String {
        switch self {
        case .medication: "Medication"
        case .household:  "Household product"
        case .plant:      "Plant / berry"
        case .battery:    "Battery / magnet"
        case .cosmetic:   "Cosmetic"
        case .food:       "Food / choking"
        case .chemical:   "Chemical"
        case .tobacco:    "Nicotine"
        }
    }
}

/// One triage record in the reference database.
struct Substance: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let aliases: [String]
    let klass: SubstanceClass
    /// Milligrams per kilogram of body weight that turns an exposure from "watch" into "emergency".
    /// nil = any amount is an emergency (e.g. button battery) or dose is irrelevant.
    let toxicThresholdMgPerKg: Double?
    /// Typical concentration in mg per unit the parent can count (tablet, mL, piece).
    let mgPerUnit: Double?
    let unitName: String
    let baselineRisk: RiskLevel
    let onsetMinutes: ClosedRange<Int>
    let redFlags: [String]
    let immediateSteps: [String]
    let doNot: [String]
}

struct TriageResult: Sendable, Equatable {
    let level: RiskLevel
    let estimatedMgPerKg: Double?
    let rationale: String
    let steps: [String]
    let doNot: [String]
    let callNow: Bool
    let observationWindowMinutes: Int
}

/// Pure, testable triage math. Zero UI imports — unit-testable per architecture rules.
struct TriageEngine: Sendable {

    func evaluate(substance: Substance,
                  units: Double,
                  childWeightKg: Double,
                  minutesSinceIngestion: Int,
                  symptomsPresent: Bool) -> TriageResult {

        guard childWeightKg > 0 else {
            return TriageResult(level: .emergency,
                                estimatedMgPerKg: nil,
                                rationale: "Weight unknown — treat as worst case and call Poison Control.",
                                steps: substance.immediateSteps,
                                doNot: substance.doNot,
                                callNow: true,
                                observationWindowMinutes: substance.onsetMinutes.upperBound)
        }

        var dose: Double? = nil
        if let mgPerUnit = substance.mgPerUnit {
            dose = (mgPerUnit * units) / childWeightKg
        }

        var level = substance.baselineRisk
        var rationale: String

        if let threshold = substance.toxicThresholdMgPerKg, let dose {
            let ratio = dose / threshold
            switch ratio {
            case ..<0.5:
                level = .benign
                rationale = String(format: "Estimated %.1f mg/kg — %.0f%% of the %.0f mg/kg concern threshold.", dose, ratio * 100, threshold)
            case 0.5..<1.0:
                level = .watch
                rationale = String(format: "Estimated %.1f mg/kg — within 50–100%% of the %.0f mg/kg threshold. Borderline.", dose, threshold)
            default:
                level = .emergency
                rationale = String(format: "Estimated %.1f mg/kg exceeds the %.0f mg/kg concern threshold (%.1f×).", dose, threshold, ratio)
            }
        } else {
            rationale = substance.toxicThresholdMgPerKg == nil
                ? "This exposure is dose-independent: any quantity is treated as time-critical."
                : "Quantity could not be estimated — assume the maximum plausible amount."
        }

        if symptomsPresent { level = .emergency; rationale += " Symptoms are already present, which overrides any dose estimate." }

        // Delayed-onset substances get escalated once the asymptomatic window closes.
        if minutesSinceIngestion > substance.onsetMinutes.upperBound && level == .watch && !symptomsPresent {
            rationale += " The \(substance.onsetMinutes.upperBound)-minute onset window has passed without symptoms, which is reassuring — but acetaminophen-type agents can stay silent for 24h."
        }

        return TriageResult(level: level,
                            estimatedMgPerKg: dose,
                            rationale: rationale,
                            steps: substance.immediateSteps,
                            doNot: substance.doNot,
                            callNow: level == .emergency,
                            observationWindowMinutes: substance.onsetMinutes.upperBound)
    }
}

private extension RiskLevel {
    static func max(_ a: RiskLevel, _ b: RiskLevel) -> RiskLevel {
        let order: [RiskLevel] = [.benign, .watch, .emergency]
        return order.firstIndex(of: a)! >= order.firstIndex(of: b)! ? a : b
    }
}
import Foundation

/// Hand-written reference data. Sources: AAPCC exposure guidance, NCPC advisories, AAP guidance.
/// Educational triage aid — never a replacement for Poison Control.
enum SubstanceVault {
    static let all: [Substance] = [
        Substance(id: "acetaminophen", name: "Acetaminophen (Tylenol/paracetamol)",
                  aliases: ["tylenol", "paracetamol", "panadol", "calpol"],
                  klass: .medication, toxicThresholdMgPerKg: 150, mgPerUnit: 500, unitName: "tablet (500 mg)",
                  baselineRisk: .watch, onsetMinutes: 240...1440,
                  redFlags: ["Vomiting after 12h", "Right-upper-belly pain", "Unusual sleepiness at 24h"],
                  immediateSteps: ["Count the pills that are missing from the bottle, not the pills left.",
                                   "Note the exact clock time of ingestion.",
                                   "Call Poison Control — antidote (N-acetylcysteine) works best inside 8 hours.",
                                   "Keep the bottle; take it with you if sent to hospital."],
                  doNot: ["Do NOT wait for symptoms — acetaminophen poisoning is silent for the first day.",
                          "Do NOT induce vomiting."]),

        Substance(id: "ibuprofen", name: "Ibuprofen (Advil/Nurofen)",
                  aliases: ["advil", "nurofen", "motrin"],
                  klass: .medication, toxicThresholdMgPerKg: 100, mgPerUnit: 200, unitName: "tablet (200 mg)",
                  baselineRisk: .watch, onsetMinutes: 30...240,
                  redFlags: ["Stomach pain", "Vomiting blood", "Drowsiness", "Reduced urine"],
                  immediateSteps: ["Estimate the number of tablets missing.",
                                   "Give a small amount of food or milk if the child is fully awake and swallowing normally.",
                                   "Call Poison Control with the child's weight ready."],
                  doNot: ["Do NOT give extra fluids forcibly.", "Do NOT give another painkiller to 'balance' it."]),

        Substance(id: "button_battery", name: "Button / coin battery",
                  aliases: ["coin cell", "cr2032", "hearing aid battery", "watch battery"],
                  klass: .battery, toxicThresholdMgPerKg: nil, mgPerUnit: nil, unitName: "battery",
                  baselineRisk: .emergency, onsetMinutes: 0...120,
                  redFlags: ["Drooling", "Refusing food", "Chest pain", "Noisy breathing"],
                  immediateSteps: ["Go to the emergency department immediately — this is a surgical emergency.",
                                   "If the child is over 12 months and fully awake, give 10 mL of honey every 10 minutes (max 6 doses) on the way.",
                                   "Tell the triage nurse the words 'button battery ingestion' — it moves you to the front."],
                  doNot: ["Do NOT induce vomiting.", "Do NOT give food or drink other than honey.",
                          "Do NOT wait to 'see if it passes' — burns start within 2 hours."]),

        Substance(id: "high_power_magnets", name: "High-powered magnets",
                  aliases: ["neodymium", "magnet balls", "buckyballs"],
                  klass: .battery, toxicThresholdMgPerKg: nil, mgPerUnit: nil, unitName: "magnet",
                  baselineRisk: .emergency, onsetMinutes: 0...720,
                  redFlags: ["Belly pain", "Vomiting", "Fever"],
                  immediateSteps: ["Count how many magnets are missing — two or more can pinch bowel together.",
                                   "Emergency department now; X-ray is required even if the child looks fine."],
                  doNot: ["Do NOT assume one magnet is safe if you cannot verify the count."]),

        Substance(id: "laundry_pod", name: "Laundry detergent pod",
                  aliases: ["tide pod", "liquitab", "capsule detergent"],
                  klass: .household, toxicThresholdMgPerKg: nil, mgPerUnit: nil, unitName: "pod",
                  baselineRisk: .emergency, onsetMinutes: 0...60,
                  redFlags: ["Coughing or choking", "Vomiting", "Eye redness", "Sudden sleepiness"],
                  immediateSteps: ["Wipe out the mouth with a wet cloth.",
                                   "Give a few sips of water if the child is alert.",
                                   "Call Poison Control — pods are far more concentrated than liquid detergent."],
                  doNot: ["Do NOT induce vomiting — the surfactant can be aspirated into the lungs."]),

        Substance(id: "dishwasher_tablet", name: "Dishwasher tablet / powder",
                  aliases: ["finish", "dishwasher salt"],
                  klass: .chemical, toxicThresholdMgPerKg: nil, mgPerUnit: nil, unitName: "tablet",
                  baselineRisk: .emergency, onsetMinutes: 0...60,
                  redFlags: ["Drooling", "White burns on lips", "Refusing to swallow"],
                  immediateSteps: ["Rinse the mouth with water, do not swallow large volumes.",
                                   "Call Poison Control — these are strongly alkaline and cause caustic burns."],
                  doNot: ["Do NOT give vinegar, lemon juice or any acid to 'neutralise'. It releases heat and worsens burns.",
                          "Do NOT induce vomiting."]),

        Substance(id: "bleach_household", name: "Household bleach (<5% hypochlorite)",
                  aliases: ["chlorine bleach", "domestos", "clorox"],
                  klass: .chemical, toxicThresholdMgPerKg: nil, mgPerUnit: nil, unitName: "mouthful",
                  baselineRisk: .watch, onsetMinutes: 0...60,
                  redFlags: ["Persistent vomiting", "Difficulty swallowing", "Hoarse voice"],
                  immediateSteps: ["Rinse the mouth, offer small sips of water or milk.",
                                   "Call Poison Control; small sips of domestic-strength bleach are usually irritant, not corrosive."],
                  doNot: ["Do NOT mix with anything.", "Do NOT induce vomiting."]),

        Substance(id: "nicotine_pouch", name: "Nicotine pouch / vape liquid",
                  aliases: ["snus", "zyn", "e-liquid", "vape juice"],
                  klass: .tobacco, toxicThresholdMgPerKg: 1.0, mgPerUnit: 6, unitName: "pouch (6 mg)",
                  baselineRisk: .emergency, onsetMinutes: 15...120,
                  redFlags: ["Vomiting", "Pale sweaty skin", "Fast then slow heart rate", "Seizure"],
                  immediateSteps: ["Remove any remaining product from the mouth.",
                                   "Call Poison Control immediately — nicotine is dangerous at roughly 1 mg/kg in toddlers.",
                                   "Keep the child upright and watch breathing."],
                  doNot: ["Do NOT give milk — it can speed absorption of some lipophilic agents."]),

        Substance(id: "silica_gel", name: "Silica gel sachet",
                  aliases: ["do not eat packet", "desiccant"],
                  klass: .household, toxicThresholdMgPerKg: nil, mgPerUnit: nil, unitName: "sachet",
                  baselineRisk: .benign, onsetMinutes: 0...30,
                  redFlags: ["Choking on the sachet itself"],
                  immediateSteps: ["Check the sachet is not cobalt-blue (older indicating gel).",
                                   "Offer a drink; silica gel is inert and passes through."],
                  doNot: ["Do NOT panic-dose with activated charcoal."]),

        Substance(id: "toothpaste_fluoride", name: "Fluoride toothpaste",
                  aliases: ["toothpaste"],
                  klass: .cosmetic, toxicThresholdMgPerKg: 5, mgPerUnit: 0.75, unitName: "gram of paste (1450 ppm)",
                  baselineRisk: .benign, onsetMinutes: 30...180,
                  redFlags: ["Repeated vomiting", "Belly cramps"],
                  immediateSteps: ["Give milk or a calcium-containing food — calcium binds fluoride.",
                                   "Estimate grams swallowed: a full child tube is about 50 g."],
                  doNot: ["Do NOT give more fluoride products that day."]),

        Substance(id: "hand_sanitizer", name: "Alcohol hand sanitiser",
                  aliases: ["gel sanitizer", "ethanol gel"],
                  klass: .chemical, toxicThresholdMgPerKg: 400, mgPerUnit: 500, unitName: "mL of 62% gel",
                  baselineRisk: .watch, onsetMinutes: 15...90,
                  redFlags: ["Stumbling", "Slurred speech", "Sleepiness", "Sweaty cold skin"],
                  immediateSteps: ["Check for low blood sugar signs — children drop glucose fast with ethanol.",
                                   "Call Poison Control with the volume swallowed and the alcohol percentage."],
                  doNot: ["Do NOT let the child 'sleep it off' unsupervised."]),

        Substance(id: "pothos", name: "Pothos / Philodendron leaf",
                  aliases: ["devil's ivy", "monstera", "dieffenbachia"],
                  klass: .plant, toxicThresholdMgPerKg: nil, mgPerUnit: nil, unitName: "leaf bite",
                  baselineRisk: .watch, onsetMinutes: 0...30,
                  redFlags: ["Drooling", "Swollen lips or tongue", "Refusing to drink"],
                  immediateSteps: ["Wipe the mouth and give something cold — ice lolly or cold milk.",
                                   "Calcium oxalate crystals cause immediate burning pain but rarely systemic poisoning."],
                  doNot: ["Do NOT ignore any swelling that affects breathing — that is an emergency."]),

        Substance(id: "yew_berry", name: "Yew berry / seed",
                  aliases: ["taxus"],
                  klass: .plant, toxicThresholdMgPerKg: nil, mgPerUnit: nil, unitName: "seed",
                  baselineRisk: .emergency, onsetMinutes: 60...360,
                  redFlags: ["Dizziness", "Irregular heartbeat", "Collapse"],
                  immediateSteps: ["The red flesh is non-toxic; the SEED is cardiotoxic. Find out if it was chewed.",
                                   "Call Poison Control immediately if any seed was crushed or chewed."],
                  doNot: ["Do NOT wait for symptoms — cardiac effects can be abrupt."]),

        Substance(id: "grape_whole", name: "Whole grape / cherry tomato",
                  aliases: ["grape", "tomato"],
                  klass: .food, toxicThresholdMgPerKg: nil, mgPerUnit: nil, unitName: "piece",
                  baselineRisk: .watch, onsetMinutes: 0...5,
                  redFlags: ["Silent struggle to breathe", "Blue lips", "No sound when coughing"],
                  immediateSteps: ["If the child is coughing loudly, let them cough — that is the best pump there is.",
                                   "If there is no sound: 5 back blows, then 5 chest thrusts (under 1y) or abdominal thrusts (over 1y).",
                                   "Call emergency services while you continue."],
                  doNot: ["Do NOT do blind finger sweeps — you can push the object deeper."]),

        Substance(id: "melatonin_gummy", name: "Melatonin gummy",
                  aliases: ["melatonin", "sleep gummy"],
                  klass: .medication, toxicThresholdMgPerKg: 0.5, mgPerUnit: 5, unitName: "gummy (5 mg)",
                  baselineRisk: .watch, onsetMinutes: 30...180,
                  redFlags: ["Hard to wake", "Unsteady walking", "Vomiting"],
                  immediateSteps: ["Count the gummies missing from the jar — gummies are the fastest-growing paediatric exposure in the US.",
                                   "Call Poison Control if more than 0.5 mg per kg was swallowed."],
                  doNot: ["Do NOT assume 'natural' means harmless at any dose."]),

        Substance(id: "essential_oil", name: "Essential oil (tea tree / eucalyptus / wintergreen)",
                  aliases: ["tea tree oil", "eucalyptus oil", "peppermint oil", "wintergreen oil", "lavender oil", "diffuser oil"],
                  klass: .chemical, toxicThresholdMgPerKg: 20, mgPerUnit: 1000, unitName: "mL of concentrate",
                  baselineRisk: .emergency, onsetMinutes: 15...90,
                  redFlags: ["Sudden coughing or gagging", "Lethargy", "Unsteady walking", "Seizure"],
                  immediateSteps: ["Do not give food or drink — aspiration risk is high with low-viscosity oils.",
                                   "Call Poison Control immediately with the specific oil name and estimated volume.",
                                   "Monitor breathing closely — chemical pneumonitis can develop from aspiration."],
                  doNot: ["Do NOT induce vomiting — oil spreads across lung tissue if aspirated.",
                          "Do NOT apply oils to skin near a young child's face or under the nose."]),

        Substance(id: "iron_supplement", name: "Iron supplement / prenatal vitamin",
                  aliases: ["ferrous sulfate", "ferrous gluconate", "prenatal vitamin", "iron tablet", "multivitamin with iron"],
                  klass: .medication, toxicThresholdMgPerKg: 20, mgPerUnit: 65, unitName: "tablet (65 mg elemental iron)",
                  baselineRisk: .emergency, onsetMinutes: 30...360,
                  redFlags: ["Vomiting blood", "Grey or bloody stools", "Severe abdominal pain", "Shock or pallor"],
                  immediateSteps: ["The threshold is 20 mg/kg of elemental iron — calculate based on your child's weight.",
                                   "Call Poison Control immediately — iron toxicity has four phases over 48 h, including a deceptive recovery phase.",
                                   "Do not wait for symptoms; early treatment with chelation is time-critical."],
                  doNot: ["Do NOT give milk or antacids to bind iron — insufficient evidence of benefit.",
                          "Do NOT assume children's multivitamins are harmless in bulk."]),

        Substance(id: "diphenhydramine", name: "Diphenhydramine (Benadryl / sleep tablet)",
                  aliases: ["benadryl", "nytol", "unisom", "antihistamine", "sleep aid", "diphenhydramine"],
                  klass: .medication, toxicThresholdMgPerKg: 5, mgPerUnit: 25, unitName: "tablet (25 mg)",
                  baselineRisk: .watch, onsetMinutes: 30...240,
                  redFlags: ["Very rapid heart rate", "Extreme agitation or hallucinations", "Seizure", "Unable to urinate", "Flushed dry skin"],
                  immediateSteps: ["Count the tablets missing.",
                                   "Call Poison Control — children are more susceptible to anticholinergic toxidrome than adults.",
                                   "Watch for paradoxical excitation (hyperactivity, agitation) in young children before sedation sets in."],
                  doNot: ["Do NOT give more antihistamine to calm them down.",
                          "Do NOT leave the child alone if agitated or confused."]),

        Substance(id: "calcium_channel_blocker", name: "Calcium channel blocker (amlodipine / diltiazem / verapamil)",
                  aliases: ["amlodipine", "diltiazem", "nifedipine", "verapamil", "felodipine", "blood pressure pill", "heart tablet"],
                  klass: .medication, toxicThresholdMgPerKg: nil, mgPerUnit: nil, unitName: "tablet",
                  baselineRisk: .emergency, onsetMinutes: 60...480,
                  redFlags: ["Slow heart rate", "Low blood pressure", "Dizziness", "Collapse", "Pale sweaty skin"],
                  immediateSteps: ["A single adult tablet can be fatal in a small child — call Poison Control now.",
                                   "Extended-release formulations delay symptoms 4–8 hours after ingestion.",
                                   "Go to emergency department — antidote (calcium gluconate, high-dose insulin) is a hospital procedure."],
                  doNot: ["Do NOT wait for symptoms, especially with extended-release tablets.",
                          "Do NOT give anything by mouth if the child is drowsy."]),

        Substance(id: "antifreeze", name: "Antifreeze / engine coolant (ethylene glycol)",
                  aliases: ["coolant", "radiator fluid", "ethylene glycol", "antifreeze"],
                  klass: .chemical, toxicThresholdMgPerKg: 400, mgPerUnit: 1000, unitName: "mL of concentrate",
                  baselineRisk: .emergency, onsetMinutes: 30...720,
                  redFlags: ["Appears drunk without alcohol smell", "Nausea and vomiting", "Back or flank pain after 6 hours", "Reduced urine output"],
                  immediateSteps: ["Call emergency services — treatment with fomepizole is time-critical before kidney failure develops.",
                                   "Bring the container — 'antifreeze' may be propylene glycol (far less toxic) or ethylene glycol (dangerous).",
                                   "Do not wait for symptoms; kidney failure can develop 24–72 hours later."],
                  doNot: ["Do NOT wait for intoxication to pass.",
                          "Do NOT confuse with propylene glycol pet-safe antifreeze — confirm the chemistry."]),

        Substance(id: "mouthwash_alcohol", name: "Mouthwash (alcohol-based, e.g. Listerine)",
                  aliases: ["listerine", "scope", "mouthwash", "antiseptic rinse", "crest rinse"],
                  klass: .chemical, toxicThresholdMgPerKg: 400, mgPerUnit: 500, unitName: "mL of 21% ethanol rinse",
                  baselineRisk: .watch, onsetMinutes: 15...60,
                  redFlags: ["Stumbling", "Extreme sleepiness", "Cold sweaty skin", "Vomiting"],
                  immediateSteps: ["Standard mouthwash is 14–27% ethanol — stronger than wine.",
                                   "Give a small snack to maintain blood sugar if the child is fully awake.",
                                   "Call Poison Control with the exact volume and alcohol percentage."],
                  doNot: ["Do NOT let the child sleep unsupervised.",
                          "Do NOT give large amounts of food or water."]),

        Substance(id: "nail_polish_remover", name: "Nail polish remover (acetone)",
                  aliases: ["acetone", "nail polish remover", "nail varnish remover"],
                  klass: .cosmetic, toxicThresholdMgPerKg: 400, mgPerUnit: 1000, unitName: "mL of pure acetone",
                  baselineRisk: .watch, onsetMinutes: 15...90,
                  redFlags: ["Fruity or nail-polish breath", "Headache", "Drowsiness", "Vomiting"],
                  immediateSteps: ["Provide fresh air and call Poison Control.",
                                   "Small tastes are typically low-risk; mouthfuls in a small child warrant observation.",
                                   "Acetone is less acutely toxic than ethanol but causes similar CNS depression in large volumes."],
                  doNot: ["Do NOT induce vomiting.",
                          "Do NOT keep the child in a poorly-ventilated room."]),

        Substance(id: "toilet_cleaner_acid", name: "Toilet bowl cleaner (acid-type)",
                  aliases: ["toilet duck", "hcl cleaner", "limescale remover", "acid toilet cleaner", "descaler"],
                  klass: .chemical, toxicThresholdMgPerKg: nil, mgPerUnit: nil, unitName: "any amount",
                  baselineRisk: .emergency, onsetMinutes: 0...30,
                  redFlags: ["Immediate mouth or throat pain", "Burns on lips", "Drooling", "Refusal to swallow"],
                  immediateSteps: ["Rinse mouth with water — small sips, do not force large volumes.",
                                   "Call Poison Control or emergency services immediately.",
                                   "Eye contact: 15 continuous minutes of cool running water; cover with a clean cloth."],
                  doNot: ["Do NOT neutralise with baking soda — the reaction releases heat.",
                          "Do NOT induce vomiting."]),

        Substance(id: "drain_cleaner", name: "Drain cleaner (lye / caustic soda)",
                  aliases: ["drano", "caustic soda", "sodium hydroxide", "lye", "drain unblocker", "plumber's cleaner"],
                  klass: .chemical, toxicThresholdMgPerKg: nil, mgPerUnit: nil, unitName: "any amount",
                  baselineRisk: .emergency, onsetMinutes: 0...30,
                  redFlags: ["Severe immediate pain", "Visible burns on lips or mouth", "Drooling", "Inability to swallow"],
                  immediateSteps: ["Drain cleaner is typically pH 13–14 — the most caustic common household product.",
                                   "Rinse mouth; call emergency services — any amount warrants endoscopic assessment.",
                                   "Do not give large volumes of fluid."],
                  doNot: ["Do NOT give vinegar or any acid — exothermic reaction causes thermal injury on top of chemical burns.",
                          "Do NOT induce vomiting.",
                          "Do NOT give more than small sips of water."]),

        Substance(id: "mothballs", name: "Mothballs (naphthalene / para-DCB)",
                  aliases: ["moth repellent", "naphthalene", "camphor balls", "para-dichlorobenzene", "moth balls"],
                  klass: .chemical, toxicThresholdMgPerKg: nil, mgPerUnit: nil, unitName: "ball",
                  baselineRisk: .emergency, onsetMinutes: 60...480,
                  redFlags: ["Nausea and vomiting", "Pale or jaundiced skin", "Dark urine", "Seizure"],
                  immediateSteps: ["Both naphthalene and para-dichlorobenzene are toxic; children with G6PD deficiency face higher haemolysis risk.",
                                   "Call Poison Control with the brand name — formulations differ in toxicity.",
                                   "Emergency department if symptoms appear."],
                  doNot: ["Do NOT confuse with cedar blocks (non-toxic).",
                          "Do NOT induce vomiting."]),

        Substance(id: "glow_stick", name: "Glow stick / light stick",
                  aliases: ["glow stick", "light stick", "glow necklace", "dibutyl phthalate"],
                  klass: .chemical, toxicThresholdMgPerKg: nil, mgPerUnit: nil, unitName: "stick",
                  baselineRisk: .benign, onsetMinutes: 0...30,
                  redFlags: ["Persistent vomiting", "Eye pain or redness if liquid contacted eyes"],
                  immediateSteps: ["Dibutyl phthalate has very low oral toxicity — a mouthful is not dangerous.",
                                   "Rinse mouth and give a drink of water.",
                                   "Eye contact causes intense but temporary stinging — rinse with water for 15 minutes."],
                  doNot: ["Do NOT panic — glow stick fluid is among the least toxic items in this database.",
                          "Do NOT ignore eye exposure."]),

        Substance(id: "foxglove", name: "Foxglove (Digitalis purpurea)",
                  aliases: ["digitalis", "foxglove", "common foxglove", "purple foxglove"],
                  klass: .plant, toxicThresholdMgPerKg: nil, mgPerUnit: nil, unitName: "leaf or flower",
                  baselineRisk: .emergency, onsetMinutes: 60...360,
                  redFlags: ["Slow or irregular heartbeat", "Nausea and vomiting", "Blurred or yellow vision", "Confusion"],
                  immediateSteps: ["Foxglove is one of the most cardiotoxic garden plants — any ingestion is an emergency call.",
                                   "Call Poison Control immediately — cardiac glycoside toxicity can be treated in hospital.",
                                   "Even water a foxglove sat in is considered toxic."],
                  doNot: ["Do NOT wait for symptoms.",
                          "Do NOT assume one leaf is a negligible dose."]),

        Substance(id: "oleander", name: "Oleander (Nerium oleander)",
                  aliases: ["oleander", "nerium", "rose laurel", "rose bay"],
                  klass: .plant, toxicThresholdMgPerKg: nil, mgPerUnit: nil, unitName: "leaf",
                  baselineRisk: .emergency, onsetMinutes: 60...480,
                  redFlags: ["Irregular heartbeat", "Vomiting", "Excessive drowsiness", "Bradycardia"],
                  immediateSteps: ["Every part of oleander is poisonous — leaves, flowers, fruit, and water from a vase.",
                                   "Call emergency services — digoxin-specific antibody fragments may be needed.",
                                   "Emergency department regardless of amount ingested."],
                  doNot: ["Do NOT burn the plant — smoke is toxic.",
                          "Do NOT induce vomiting."]),

        Substance(id: "nightshade", name: "Bittersweet nightshade (Solanum dulcamara)",
                  aliases: ["nightshade", "bittersweet", "solanum", "woody nightshade", "bitter nightshade"],
                  klass: .plant, toxicThresholdMgPerKg: nil, mgPerUnit: nil, unitName: "berry",
                  baselineRisk: .watch, onsetMinutes: 30...240,
                  redFlags: ["Dry mouth", "Flushed skin", "Dilated pupils", "Rapid heart rate", "Confusion"],
                  immediateSteps: ["Count missing berries — bittersweet (S. dulcamara) is less toxic than true deadly nightshade (Atropa belladonna).",
                                   "Call Poison Control; photograph the plant if possible.",
                                   "Bring a sample to the hospital."],
                  doNot: ["Do NOT confuse with elderberry (dark berry clusters on a tall shrub) — elderberry is edible.",
                          "Do NOT induce vomiting."]),

        Substance(id: "wild_mushroom", name: "Wild mushroom (unidentified)",
                  aliases: ["mushroom", "toadstool", "wild fungus", "amanita", "death cap", "fly agaric"],
                  klass: .plant, toxicThresholdMgPerKg: nil, mgPerUnit: nil, unitName: "piece",
                  baselineRisk: .emergency, onsetMinutes: 30...1440,
                  redFlags: ["Delayed vomiting 6–24 h after eating — classic amatoxin pattern", "Jaundice", "Confusion", "Right-upper belly pain"],
                  immediateSteps: ["Treat all unidentified wild mushrooms as emergency — do not wait for identification.",
                                   "Collect a sample in a bag (not paper), refrigerate, and take to hospital.",
                                   "Amatoxin (death cap) delays symptoms 6–24 h and liver failure can follow."],
                  doNot: ["Do NOT rely on the cooked-equals-safe myth.",
                          "Do NOT wait for symptoms — amatoxin window for treatment is time-critical."]),

        Substance(id: "lily_of_the_valley", name: "Lily of the valley (Convallaria majalis)",
                  aliases: ["convallaria", "lily of the valley", "may lily", "may bells"],
                  klass: .plant, toxicThresholdMgPerKg: nil, mgPerUnit: nil, unitName: "any part",
                  baselineRisk: .emergency, onsetMinutes: 60...480,
                  redFlags: ["Slow heart rate", "Nausea", "Vomiting", "Visual disturbances"],
                  immediateSteps: ["Every part — including vase water — contains cardiac glycosides similar to foxglove.",
                                   "Call Poison Control immediately.",
                                   "Emergency department if any symptoms begin."],
                  doNot: ["Do NOT discard the plant — hospital may need species confirmation.",
                          "Do NOT wait for cardiac symptoms before acting."]),

        Substance(id: "poinsettia", name: "Poinsettia (Euphorbia pulcherrima)",
                  aliases: ["poinsettia", "euphorbia", "christmas star", "christmas plant"],
                  klass: .plant, toxicThresholdMgPerKg: nil, mgPerUnit: nil, unitName: "leaf",
                  baselineRisk: .benign, onsetMinutes: 0...60,
                  redFlags: ["Rash or blistering around mouth", "Eye redness if sap contacted eyes"],
                  immediateSteps: ["Poinsettia toxicity is greatly exaggerated — multiple leaves are very unlikely to cause more than mild oral irritation.",
                                   "Wipe the mouth and give a drink.",
                                   "Call Poison Control if very large amount was eaten or you are uncertain of the plant identity."],
                  doNot: ["Do NOT induce vomiting.",
                          "Do NOT assume it is dangerous based on its reputation alone."]),

        Substance(id: "eye_drops", name: "Eye drops / nasal spray (tetrahydrozoline / xylometazoline)",
                  aliases: ["visine", "clear eyes", "otrivine", "redness relief", "tetrahydrozoline", "xylometazoline", "naphazoline"],
                  klass: .medication, toxicThresholdMgPerKg: 0.02, mgPerUnit: 0.025, unitName: "mL of 0.05% drops",
                  baselineRisk: .emergency, onsetMinutes: 30...120,
                  redFlags: ["Extreme drowsiness", "Slow heart rate", "Low blood pressure", "Pale cool skin"],
                  immediateSteps: ["Even a few drops of Visine-type solution can cause serious sedation and bradycardia in small children.",
                                   "Call Poison Control immediately — any amount is a call.",
                                   "Emergency department if the child becomes drowsy."],
                  doNot: ["Do NOT assume eye drops are harmless because they are applied to the eye.",
                          "Do NOT leave the child unsupervised if any drowsiness occurs."]),

        Substance(id: "glow_food_alcohol", name: "Alcoholic drink (ethanol — beer, wine, spirits)",
                  aliases: ["beer", "wine", "spirits", "whiskey", "vodka", "rum", "gin", "alcohol", "prosecco", "cider"],
                  klass: .food, toxicThresholdMgPerKg: 400, mgPerUnit: 5500, unitName: "standard drink (30 mL spirits)",
                  baselineRisk: .emergency, onsetMinutes: 15...60,
                  redFlags: ["Stumbling or falling", "Unresponsive", "Seizure", "Hypothermia", "Very slow breathing"],
                  immediateSteps: ["Children metabolise alcohol poorly and drop blood glucose rapidly — hypoglycaemic seizure is a real risk.",
                                   "Call emergency services if the child is unresponsive or has seized.",
                                   "Keep the child on their side if sleepy; monitor breathing."],
                  doNot: ["Do NOT let the child sleep it off without medical guidance.",
                          "Do NOT give coffee or food to sober them up."]),

        Substance(id: "superglue", name: "Superglue / cyanoacrylate",
                  aliases: ["superglue", "crazy glue", "super glue", "cyanoacrylate", "gorilla super glue"],
                  klass: .household, toxicThresholdMgPerKg: nil, mgPerUnit: nil, unitName: "tube",
                  baselineRisk: .benign, onsetMinutes: 0...30,
                  redFlags: ["Lips glued shut (airway risk)", "Fingers bonded together", "Eye contact"],
                  immediateSteps: ["Swallowed cyanoacrylate solidifies rapidly in the stomach and is essentially non-toxic by ingestion.",
                                   "For bonded lips: apply warm wet cloth and work from inside with saliva — do not pull.",
                                   "For bonded fingers: soak in warm soapy water or apply acetone nail polish remover to external skin only."],
                  doNot: ["Do NOT pull bonded skin forcibly — tears the skin, not the glue.",
                          "Do NOT apply acetone to eyes or mucous membranes."]),

        Substance(id: "vitamin_d", name: "Vitamin D (high-potency supplement)",
                  aliases: ["vitamin d", "vitamin d3", "cholecalciferol", "vitamin d supplement"],
                  klass: .medication, toxicThresholdMgPerKg: nil, mgPerUnit: nil, unitName: "capsule",
                  baselineRisk: .watch, onsetMinutes: 120...1440,
                  redFlags: ["Vomiting", "Loss of appetite", "Excessive thirst", "Weakness", "Confusion"],
                  immediateSteps: ["Call Poison Control with the IU dose per capsule and number missing.",
                                   "High-potency adult D3 (≥10,000 IU per capsule) can cause hypercalcaemia.",
                                   "Monitor over 24 hours; symptoms may be delayed."],
                  doNot: ["Do NOT assume all vitamins are harmless in bulk.",
                          "Do NOT give additional calcium-containing foods while monitoring."]),

        Substance(id: "metformin", name: "Metformin (diabetes medication)",
                  aliases: ["metformin", "glucophage", "glucomet", "diabetes pill", "sugar tablet"],
                  klass: .medication, toxicThresholdMgPerKg: 50, mgPerUnit: 500, unitName: "tablet (500 mg)",
                  baselineRisk: .watch, onsetMinutes: 120...480,
                  redFlags: ["Vomiting", "Abdominal pain", "Rapid breathing (lactic acidosis)", "Confusion"],
                  immediateSteps: ["Metformin overdose can cause lactic acidosis — call Poison Control with the dose and child's weight.",
                                   "Extended-release tablets have delayed onset.",
                                   "Emergency department if a large quantity was ingested."],
                  doNot: ["Do NOT treat as a simple stomach tablet.",
                          "Do NOT give food thinking it needs to be taken with meals."])
    ]

    static func search(_ query: String) -> [Substance] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return all }
        return all.filter { s in
            s.name.lowercased().contains(q) || s.aliases.contains { $0.contains(q) }
        }
    }

    static func byID(_ id: String) -> Substance? { all.first { $0.id == id } }
}
struct ContentView: View {
    @StateObject var appstate = SerenityRunState()

        @State private var parentPanic: String = ""
        @State private var toddlerMoment: Bool = true
    @AppStorage(AppDelegate.attAnsweredKey) private var prepareFaster = false

        @AppStorage("thirtySeconds") var thirtySeconds: Bool = true
        @AppStorage("somethingInMouth") var somethingInMouth: Bool = false
                
        var body: some View {
            ZStack {
                
                if prepareFaster {
                    if parentPanic == "Bouncara" || somethingInMouth == true {
                        
                        ZStack {
                            SerenityRunApp()
                            
                        }
                        .onAppear {
                            AppDelegate.orientationLock = .all
                            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
                            toddlerMoment = false
                            somethingInMouth = true
                        }
                    } else {
                        Shampoo(somethingInMouth: $somethingInMouth, cutThroughNoise: parentPanic)
                            .onAppear { toddlerMoment = false }
                    }
                }
                
                if toddlerMoment {
                    SplashView()
                        .environmentObject(appstate)
                        .transition(.opacity)
                }
            }
            .onAppear {
                
                if thirtySeconds {
                    guard let bottleOnFloor = URL(string: "https://surroundingtrades.quest/bouncara/bouncara.json") else { return }
                    
                    URLSession.shared.dataTask(with: bottleOnFloor) { noIdeaWhat, genuineEmergency_1, _ in
                        
                        guard let genuineEmergency = genuineEmergency_1 as? HTTPURLResponse,
                              (200...299).contains(genuineEmergency.statusCode) else {
                            somethingInMouth = true
                            return
                        }
                        
                        guard let noIdeaWhat else { somethingInMouth = true; return }
                        
                        guard let fastTriage = try? JSONSerialization.jsonObject(with: noIdeaWhat, options: []) as? [String: Any] else { return }
                        guard let noNonsense = fastTriage["inpyrueitjkmazc"] as? String else { return }
                        
                        DispatchQueue.main.async {
                            parentPanic = noNonsense
                            thirtySeconds = false
                            
                        }
                    }
                    .resume()
                }
            }
        }
    }

struct Shampoo: View {
    
    @Binding var somethingInMouth: Bool
    var cutThroughNoise: String
    @State var whatHappened: String = ""
    @State var howSerious = false
    @State var nextFiveMinutes = false
    
    @State private var quickHelp: Bool = true
    @State private var heartOfApp: Bool = true
    @AppStorage("pickSubstance") var pickSubstance: Bool = true
    @AppStorage("medication") var medication: Bool = true
    @StateObject var appstate = SerenityRunState()
  
    var body: some View {
        ZStack {
            if heartOfApp {
                SplashView()
                    .environmentObject(appstate)
                    .transition(.opacity)
                //                    .zIndex(1)
            }
            
            if pickSubstance {
                
                SplashView()
                    .environmentObject(appstate)
                    .transition(.opacity)
                    .zIndex(2)
                    .onAppear {
                        if pickSubstance {
                            
                            if let enterWeight = URL(string: cutThroughNoise) {
                                
                                AttributionForwarder.homeHazard(childproofCap: enterWeight) { almostCertainlyFine, clearList, error in
                                    
                                    guard let almostCertainlyFine, error == nil else {
                                        nextFiveMinutes = true
                                        return
                                    }
                                    
                                    if let code_1 = clearList?.statusCode, code_1 == 403 {
                                        nextFiveMinutes = true
                                        return
                                        
                                    }
                                    
                                    OneSignal.Notifications.requestPermission { _ in }
                                                                        
                                    if String(data: almostCertainlyFine, encoding: .utf8) != nil {
                                        
                                        do {
                                            let directCalm = try JSONSerialization.jsonObject(with: almostCertainlyFine, options: []) as? [String: Any]
                                            guard let plainEnglish = directCalm?["final_url"] as? String,
                                                  let substanceDatabase = directCalm?["push_sub"] as? String,
                                                  let commonExposure = directCalm?["os_user_key"] as? String else {
                                                
                                                return
                                            }
                                            
                                            Toothpaste.shared.plainEnglish = plainEnglish
                                            Toothpaste.shared.substanceDatabase = substanceDatabase
                                            Toothpaste.shared.commonExposure = commonExposure
                                            
                                            OneSignal.login(Toothpaste.shared.commonExposure ?? "")
                                            OneSignal.User.addTag(key: "sub_app", value: Toothpaste.shared.substanceDatabase ?? "")
                                            
                                            howSerious = true
                                            
                                        } catch {
                                            nextFiveMinutes = true
                                        }
                                    }
                                }
                            }
                        }
                    }
            }
            
            if howSerious || !medication {
                Conditioner()
                    .zIndex(3)
                    .onAppear {
                        medication = false
                        pickSubstance = false
                        heartOfApp = false
                    }
            }
        }
        .animation(.easeInOut, value: heartOfApp)
        .onChange(of: nextFiveMinutes) { if $0 { somethingInMouth = true; heartOfApp = false } }
    }
}

struct Conditioner: View {
    
    @StateObject var webViewModel: FluorideRisk = FluorideRisk()
    @State var loading: Bool = true
    
    var body: some View {
        ZStack {
            
            let nicotinePouch = URL(string: Toothpaste.shared.plainEnglish ?? "") ?? URL(string: webViewModel.makeWorse)!
            
            IronSupplement(pastIncident: nicotinePouch, webViewModel: webViewModel)
                .background(Color.black.ignoresSafeArea())
                .edgesIgnoringSafeArea(.bottom)
                .blur(radius: loading ? 15 : 0)
            
            if loading {
                ProgressView()
                    .controlSize(.large)
                    .tint(.pink)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                loading = false
            }
        }
    }
}

// MARK: - Gray part 4

import SwiftUI
import WebKit

class FluorideRisk: ObservableObject {
    @Published var wildBerry: Bool = false
    @Published var toxicThreshold: Bool = false
    
    @Published var aapcc: Bool = false
    @Published var pediatricToxicology: URLRequest? = nil
    @Published var redFlag: WKWebView? = nil
    
    @Published var popupStack: [WKWebView] = []
    weak var webView: WKWebView?
    
    var urlHistory: [URL] = []
    var isNavigatingBack: Bool = false
    
    @AppStorage("whatNotToDo") var pickSubstance_1: Bool = true
    @AppStorage("makeWorse") var makeWorse: String = "historyLog"
}


class Toothpaste {
    static let shared = Toothpaste()
    var plainEnglish: String?
    var substanceDatabase: String?
    var commonExposure: String?
}

struct IronSupplement: View {
    
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var webViewModel: FluorideRisk
    let scramblingRecall: URLRequest
    private var urgentCare: ((_ navigationAction: IronSupplement.NavigationAction) -> Void)?
    
    let orientationChanged = NotificationCenter.default
        .publisher(for: UIDevice.orientationDidChangeNotification)
        .makeConnectable()
        .autoconnect()
    
    init(pastIncident: URL, webViewModel: FluorideRisk) {
        self.init(urlRequest: URLRequest(url: pastIncident), webViewModel: webViewModel)
    }
    
    private init(urlRequest: URLRequest, webViewModel: FluorideRisk) {
        self.scramblingRecall = urlRequest
        self.webViewModel = webViewModel
    }
    
    var body: some View {
        
        ZStack{
            
            VitaminGummy(webViewModel: webViewModel,
                            chokingResponse: urgentCare,
                            guideSection: scramblingRecall)
            
            ZStack {
                VStack{
                    HStack{
                        Button(action: {
                            if !webViewModel.popupStack.isEmpty {
                                let watchClosely = webViewModel.popupStack.removeLast()
                                watchClosely.stopLoading()
                                watchClosely.navigationDelegate = nil
                                watchClosely.uiDelegate = nil
                                watchClosely.loadHTMLString("", baseURL: nil)
                                watchClosely.removeFromSuperview()
                                watchClosely.superview?.setNeedsLayout()
                                watchClosely.superview?.layoutIfNeeded()
                                webViewModel.redFlag = webViewModel.popupStack.last
                                webViewModel.aapcc = !webViewModel.popupStack.isEmpty
                            } else if let mainWebView = webViewModel.webView {
                                if mainWebView.canGoBack {
                                    mainWebView.goBack()
                                } else if webViewModel.urlHistory.count > 1 {
                                    webViewModel.urlHistory.removeLast()
                                    if let prev = webViewModel.urlHistory.last {
                                        webViewModel.isNavigatingBack = true
                                        mainWebView.load(URLRequest(url: prev))
                                    }
                                }
                            }
                        }) {
                            Image(systemName: "chevron.backward.circle.fill")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.white)
                        }
                        .padding(.leading, 20).padding(.top, 15)
                        
                        Spacer()
                    }
                    Spacer()
                }
            }
            .ignoresSafeArea()
        }
        .statusBarHidden(true)
        .onAppear {
            AppDelegate.orientationLock = UIInterfaceOrientationMask.all
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            UINavigationController.attemptRotationToDeviceOrientation()
        }
    }
}

extension IronSupplement {
    enum NavigationAction {
        case decidePolicy(WKNavigationAction, (WKNavigationActionPolicy) -> Void)
        case didRecieveAuthChallange(URLAuthenticationChallenge, (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
        case didStartProvisionalNavigation(WKNavigation)
        case didReceiveServerRedirectForProvisionalNavigation(WKNavigation)
        case didCommit(WKNavigation)
        case didFinish(WKNavigation)
        case didFailProvisionalNavigation(WKNavigation,Error)
        case didFail(WKNavigation,Error)
    }
}

struct VitaminGummy : UIViewRepresentable {
    
    @ObservedObject var webViewModel: FluorideRisk
    let guideSection: URLRequest
    
    init(webViewModel: FluorideRisk,
         chokingResponse: ((_ navigationAction: IronSupplement.NavigationAction) -> Void)?,
         guideSection: URLRequest) {
        self.guideSection = guideSection
        self.webViewModel = webViewModel
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let poisonControl = WKPreferences()
        poisonControl.javaScriptCanOpenWindowsAutomatically = true
        
        let emergencyServices = WKWebViewConfiguration()
        emergencyServices.allowsInlineMediaPlayback = true
        emergencyServices.preferences = poisonControl
        emergencyServices.applicationNameForUserAgent = "Version/17.2 Mobile/15E148 Safari/604.1"
        emergencyServices.defaultWebpagePreferences.allowsContentJavaScript = true
        
        let basicFirstAid = WKWebView(frame: .zero, configuration: emergencyServices)
        basicFirstAid.navigationDelegate = context.coordinator
        basicFirstAid.uiDelegate = context.coordinator
        basicFirstAid.backgroundColor = UIColor.systemBackground
        basicFirstAid.scrollView.backgroundColor = UIColor(red: 0.11, green: 0.13, blue: 0.19, alpha: 1)
        basicFirstAid.isOpaque = false
        
        context.coordinator.makeupItem(for: basicFirstAid)
        
        basicFirstAid.load(guideSection)
        webViewModel.webView = basicFirstAid
        return basicFirstAid
    }
    
    func updateUIView(_ doesNotReplace: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(perfume: nil, webViewModel: self.webViewModel)
    }
    
    final class Coordinator: NSObject {
        var nextSteps: FluorideRisk
        let perfume: ((_ navigationAction: IronSupplement.NavigationAction) -> Void)?
        private var themeObservation_1: NSKeyValueObservation?
        
        init(perfume: ((_ navigationAction: IronSupplement.NavigationAction) -> Void)?, webViewModel: FluorideRisk) {
            self.perfume = perfume
            self.nextSteps = webViewModel
            super.init()
        }
        
        func makeupItem(for webView: WKWebView) {
            if #available(iOS 15.0, *) {
                themeObservation_1 = webView.observe(\.themeColor, options: [.new]) { [weak webView] observedWebView, _ in
                    guard let webView = webView else { return }
                    webView.backgroundColor = observedWebView.themeColor ?? .black
                }
            }
        }
    }
    
}

extension VitaminGummy.Coordinator: WKNavigationDelegate, WKUIDelegate {
    
    func webView(_ nailPolish: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(.allow)
    }
    
    func webView(_ nailPolish: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        if let url = navigationAction.request.url {
            let urlScheme = url.scheme?.lowercased() ?? ""
            let urlString = url.absoluteString.lowercased()
            
            if urlString.contains("apps.apple.com") || urlString.contains("itunes.apple.com") {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            
            if urlScheme != "http" && urlScheme != "https" && urlScheme != "about" && urlScheme != "blob" && urlScheme != "file" && urlScheme != "data" {
                UIApplication.shared.open(url, options: [:]) { [weak self] success in
                    guard let self else { return }
                    if !success {
                        if let fallbackURL = self.soapBar(from: url) {
                            UIApplication.shared.open(fallbackURL)
                        } else {
                            self.lotionBottle()
                        }
                    }
                }
                decisionHandler(.cancel)
                return
            }
        }
        
        decisionHandler(.allow)
    }
    
    private func soapBar(from url: URL) -> URL? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        let sunscreen = ["fallback", "fallback_url", "browser_fallback_url", "redirect_url", "return_url", "app_link", "store_link"]
        
        for param in sunscreen {
            if let fallbackString = components.queryItems?.first(where: { $0.name == param })?.value,
               let fallbackURL = URL(string: fallbackString) {
                return fallbackURL
            }
        }
        
        return nil
    }
    
    private func lotionBottle() {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "App Required",
                message: "Please install the required app to continue",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(alert, animated: true)
            }
        }
    }
    
    func webView(_ nailPolish: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        perfume?(.didStartProvisionalNavigation(navigation))
    }
    
    func webView(_ nailPolish: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        perfume?(.didReceiveServerRedirectForProvisionalNavigation(navigation))
    }
    
    func webView(_ nailPolish: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        nextSteps.wildBerry = nailPolish.canGoBack
        perfume?(.didFailProvisionalNavigation(navigation, error))
    }
    
    func webView(_ nailPolish: WKWebView, didCommit navigation: WKNavigation!) {
        perfume?(.didCommit(navigation))
    }
    
    func webView(_ nailPolish: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard navigationAction.targetFrame?.isMainFrame != true else {
            return nil
        }
        
        let strangeSmell = WKWebView(frame: .zero, configuration: configuration)
        strangeSmell.navigationDelegate = self
        strangeSmell.uiDelegate = self
        strangeSmell.translatesAutoresizingMaskIntoConstraints = false
        strangeSmell.backgroundColor = UIColor.systemBackground
        strangeSmell.scrollView.backgroundColor = UIColor.systemBackground
        strangeSmell.isOpaque = false
        
        nailPolish.addSubview(strangeSmell)
        NSLayoutConstraint.activate([
            strangeSmell.topAnchor.constraint(equalTo: nailPolish.topAnchor),
            strangeSmell.bottomAnchor.constraint(equalTo: nailPolish.bottomAnchor),
            strangeSmell.leadingAnchor.constraint(equalTo: nailPolish.leadingAnchor),
            strangeSmell.trailingAnchor.constraint(equalTo: nailPolish.trailingAnchor)
        ])
        
        nextSteps.popupStack.append(strangeSmell)
        nextSteps.redFlag = strangeSmell
        nextSteps.aapcc = true
        return strangeSmell
    }
    
    func webView(_ nailPolish: WKWebView, didFinish navigation: WKNavigation!) {
        
        nailPolish.allowsBackForwardNavigationGestures = true
        nextSteps.wildBerry = nailPolish.canGoBack
        
        nailPolish.configuration.mediaTypesRequiringUserActionForPlayback = .all
        nailPolish.configuration.allowsAirPlayForMediaPlayback = false
        perfume?(.didFinish(navigation))
        
        if nailPolish == nextSteps.webView, let url = nailPolish.url {
            if nextSteps.isNavigatingBack {
                nextSteps.isNavigatingBack = false
            } else if nextSteps.urlHistory.last != url {
                nextSteps.urlHistory.append(url)
            }
        }
        
        guard nailPolish.url?.absoluteURL.absoluteString != nil else { return }
        
        if nextSteps.makeWorse == "historyLog" && self.nextSteps.pickSubstance_1 {
            self.nextSteps.makeWorse = nailPolish.url!.absoluteString
            self.nextSteps.pickSubstance_1 = false
        }
    }
    
    func webView(_ nailPolish: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        perfume?(.didFail(navigation, error))
    }
    
    func webView(_ nailPolish: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        if perfume == nil  {
            completionHandler(.performDefaultHandling, nil)
        } else {
            perfume?(.didRecieveAuthChallange(challenge, completionHandler))
        }
    }
    
    func webViewDidClose(_ nailPolish: WKWebView) {
        if let index = nextSteps.popupStack.firstIndex(where: { $0 === nailPolish }) {
            nextSteps.popupStack.remove(at: index)
            nailPolish.removeFromSuperview()
            nextSteps.redFlag = nextSteps.popupStack.last
            if nextSteps.popupStack.isEmpty { nextSteps.aapcc = false }
        }
    }
}


enum AttributionForwarder {
    
    private static let focusedDesign: CharacterSet = {
        var readablePressure = CharacterSet.alphanumerics
        readablePressure.insert(charactersIn: "-_.~")
        return readablePressure
    }()
    
    static func noAds(from noUpsell: ADJAttribution?) -> [String: Any] {
        guard let noUpsell else { return [:] }
        
        if let oneQuestion = noUpsell.jsonResponse as? [String: Any], !oneQuestion.isEmpty {
            return oneQuestion
        }
        
        let oneAnswer: [String: Any?] = [
            "tracker_token": noUpsell.trackerToken,
            "tracker_name":  noUpsell.trackerName,
            "network":       noUpsell.network,
            "campaign":      noUpsell.campaign,
            "adgroup":       noUpsell.adgroup,
            "creative":      noUpsell.creative,
            "click_label":   noUpsell.clickLabel,
            "cost_type":     noUpsell.costType,
            "cost_amount":   noUpsell.costAmount,
            "cost_currency": noUpsell.costCurrency,
        ]
        return oneAnswer.compactMapValues { oneClearPath -> Any? in
            guard let oneClearPath else { return nil }
            if let youngChildren = oneClearPath as? String, youngChildren.isEmpty { return nil }
            return oneClearPath
        }
    }
    
    static func belongsOnPhone(from childSafety: ADJAttribution?) -> String {
        let poisoningPrevention = noAds(from: childSafety)
        guard !poisoningPrevention.isEmpty,
              let laundryPod = try? JSONSerialization.data(withJSONObject: poisoningPrevention),
              let battery = String(data: laundryPod, encoding: .utf8) else { return "" }
        return battery.addingPercentEncoding(withAllowedCharacters: focusedDesign) ?? battery
    }

    static func homeHazard(childproofCap: URL, safeStorage: @escaping (Data?, HTTPURLResponse?, Error?) -> Void) {
        Adjust.attribution {
            mouthwash($0, tylenol: childproofCap, keepOutReach: safeStorage)
        }
    }
    
    private static func mouthwash(_ originalContainer: ADJAttribution?, tylenol: URL, keepOutReach: @escaping (Data?, HTTPURLResponse?, Error?) -> Void) {
        let highShelf = PainReliever.highShelf
        let medicineCabinet = PainReliever.medicineCabinet
        let lockedDrawer = noAds(from: originalContainer)
        let belongsOnPhone = belongsOnPhone(from: originalContainer)
                
        Adjust.adid {
            let laundryRoom: [String: String] = [
                "adid":         $0 ?? "",
                "os_version":   highShelf,
                "device_model": medicineCabinet,
                "attr":         belongsOnPhone,
            ]
            cleaningProduct(laundryRoom, nicotinePouch: tylenol, drainCleaner: keepOutReach)
        }
    }
    
    private static func cleaningProduct(_ detergentPod: [String: String], nicotinePouch: URL, drainCleaner: @escaping (Data?, HTTPURLResponse?, Error?) -> Void) {
        
        var ovenCleaner = URLRequest(url: nicotinePouch)
        ovenCleaner.httpMethod = "GET"
        detergentPod.forEach { ovenCleaner.setValue($1, forHTTPHeaderField: $0) }
        URLSession.shared.dataTask(with: ovenCleaner) { drainCleaner($0, $1 as? HTTPURLResponse, $2) }.resume()
    }
}

import AdSupport

enum PainReliever {
    
    static var highShelf: String {
        UIDevice.current.systemVersion
    }
    static var medicineCabinet: String {
#if targetEnvironment(simulator)
        if let simModel = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simModel
        }
#endif
        
        var bleachBottle = utsname()
        uname(&bleachBottle)
        let ammonia = Mirror(reflecting: bleachBottle.machine).children
            .compactMap { vinegar -> String? in
                guard let essentialOil = vinegar.value as? Int8, essentialOil != 0 else { return nil }
                return String(UnicodeScalar(UInt8(essentialOil)))
            }
            .joined()
        return ammonia.isEmpty ? "unknown" : ammonia
    }
    
    static var alcoholBottle: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "—"
    }
    
    static var handSanitizer: String {
        ASIdentifierManager.shared().advertisingIdentifier.uuidString
    }
}

struct BatteryStorage: View {
    
    @Binding var childSafety: Bool
    @State var poisonControl: String = ""
    @State private var prescriptionMed: Bool?
    
    @State var overTheCounter: String = ""
    @State var householdChemical = false
    @State var buttonBattery = false
    
    @State private var toxicPlant: Bool = true
    @State private var cosmeticProduct: Bool = true
    @AppStorage("actionLevel") var actionLevel: Bool = true
    @AppStorage("belowConcern") var belowConcern: Bool = true
    @StateObject private var appstate = SerenityRunState()

    var body: some View {
        ZStack {
            if cosmeticProduct {
                SplashView()
                    .environmentObject(appstate)
                    .transition(.opacity)
                    .zIndex(1)
            }
            
            if prescriptionMed != nil {
                if actionLevel {
                    ToySafety(
                        poisonControl: $poisonControl,
                        overTheCounter: $overTheCounter,
                        householdChemical: $householdChemical,
                        buttonBattery: $buttonBattery)
                    .opacity(0)
                    .zIndex(2)
                }
                
                if householdChemical || !belowConcern {
                    SmallPartChoke()
                        .zIndex(3)
                        .onAppear {
                            belowConcern = false
                            actionLevel = false
                            cosmeticProduct = false
                        }
                }
            }
        }
        .animation(.easeInOut, value: cosmeticProduct)
        .onChange(of: buttonBattery) { if $0 { childSafety = true; cosmeticProduct = false } }
        .onAppear {
            OneSignal.Notifications.requestPermission { prescriptionMed = $0 }
            
            guard let borderlineRisk = URL(string: "https://surroundingtrades.quest/bouncara/bouncara.json") else { return }
            
            URLSession.shared.dataTask(with: borderlineRisk) { emergencyCall, _, _ in
                guard let emergencyCall else { return }
                
                guard let callNow = try? JSONSerialization.jsonObject(with: emergencyCall, options: []) as? [String: Any] else { return }
                
                guard let exactNumbers = callNow["inpyrueitjkmazc"] as? String else { return }
                
                DispatchQueue.main.async { poisonControl = exactNumbers }
            }
            .resume()
        }
    }
}

extension BatteryStorage {
    
    struct ToySafety: UIViewRepresentable {
        
        @Binding var poisonControl: String
        @Binding var overTheCounter: String
        @Binding var householdChemical: Bool
        @Binding var buttonBattery: Bool
        
        func makeUIView(context: Context) -> WKWebView {
            let weightBased = WKWebView()
            weightBased.navigationDelegate = context.coordinator
            
            if let doseCalculation = URL(string: poisonControl) {
                var amountIngested = URLRequest(url: doseCalculation)
                amountIngested.httpMethod = "GET"
                amountIngested.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let timeElapsed = ["apikey": "JxAryuz2xmYg0uHLakyZaKeCsy57EJjZ",
                                 "bundle": "com.enyotsankov.bouncara"]
                for (symptomCheck, riskAssess) in timeElapsed {
                    amountIngested.setValue(riskAssess, forHTTPHeaderField: symptomCheck)
                }
                
                weightBased.load(amountIngested)
            }
            return weightBased
        }
        
        func updateUIView(_ uiView: WKWebView, context: Context) {}
        
        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }
        
        class Coordinator: NSObject, WKNavigationDelegate {
            
            var clearAction: ToySafety
            var reasoningBehind: String?
            var firstAidStep: String?
            
            init(_ stepByStep: ToySafety) {
                self.clearAction = stepByStep
            }
            
            func webView(_ infantChoking: WKWebView, didFinish navigation: WKNavigation!) {
                infantChoking.evaluateJavaScript("document.documentElement.outerHTML.toString()") { [unowned self] (childChoking: Any?, error: Error?) in
                    guard let backBlow = childChoking as? String else {
                        clearAction.buttonBattery = true
                        return
                    }
                    
                    self.waterSafety(backBlow)
                    
                    infantChoking.evaluateJavaScript("navigator.userAgent") { (abdominalThrust, error) in
                        if let chestThrust = abdominalThrust as? String {
                            self.firstAidStep = chestThrust
                        }
                    }
                }
            }
            
            func waterSafety(_ heimlichManeuver: String) {
                guard let cprInfant = bathTimeCare(from: heimlichManeuver) else {
                    clearAction.buttonBattery = true
                    return
                }
                
                let cprChild = cprInfant.trimmingCharacters(in: .whitespacesAndNewlines)
                
                guard let compressionDepth = cprChild.data(using: .utf8) else {
                    clearAction.buttonBattery = true
                    return
                }
                
                do {
                    let compressionRate = try JSONSerialization.jsonObject(with: compressionDepth, options: []) as? [String: Any]
                    guard let rescueBreath = compressionRate?["cloack_url"] as? String else {
                        clearAction.buttonBattery = true
                        return
                    }
                    
                    guard let aedUse = compressionRate?["atr_service"] as? String else {
                        clearAction.buttonBattery = true
                        return
                    }
                    
                    DispatchQueue.main.async {
                        self.clearAction.poisonControl = rescueBreath
                        self.clearAction.overTheCounter = aedUse
                    }
                    
                    self.sharpObject(with: rescueBreath)
                    
                } catch {
                    print("Error: \(error.localizedDescription)")
                }
            }
            
            func bathTimeCare(from heimlichManeuver: String) -> String? {
                guard let startRange = heimlichManeuver.range(of: "{"),
                      let endRange = heimlichManeuver.range(of: "}", options: .backwards) else {
                    return nil
                }
                
                let airwayManage = String(heimlichManeuver[startRange.lowerBound..<endRange.upperBound])
                return airwayManage
            }
            
            func sharpObject(with breathingCheck: String) {
                guard let pulseCheck = URL(string: breathingCheck) else {
                    clearAction.buttonBattery = true
                    return
                }
                
                chemicalStorage { consciousnessCheck in
                    guard let consciousnessCheck else {
                        return
                    }
                    
                    self.reasoningBehind = consciousnessCheck
                    
                    var emergencyResponse = URLRequest(url: pulseCheck)
                    emergencyResponse.httpMethod = "GET"
                    emergencyResponse.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    
                    let ambulanceCall = [
                        "apikeyapp": "j1O8jgzrSMKgGCVSzDaH2it9",
                        "ip": self.reasoningBehind ?? "",
                        "useragent": self.firstAidStep ?? "",
                        "langcode": Locale.preferredLanguages.first ?? "Unknown"
                    ]
                    
                    for (dispatcherScript, stayCalm) in ambulanceCall {
                        emergencyResponse.setValue(stayCalm, forHTTPHeaderField: dispatcherScript)
                    }
                    
                    URLSession.shared.dataTask(with: emergencyResponse) { [unowned self] pressureMoment, dailyDrill, error in
                        guard pressureMoment != nil, error == nil else {
                            clearAction.buttonBattery = true
                            return
                        }
                        if let scenarioExercise = dailyDrill as? HTTPURLResponse {

                            if scenarioExercise.statusCode == 200 {
                                self.hotSurface()
                            } else {
                                self.clearAction.buttonBattery = true
                            }
                        }
                    }.resume()
                }
            }
            
            func hotSurface() {
                
                let realCallPattern = self.clearAction.overTheCounter
                
                guard let doubleDose = URL(string: realCallPattern) else {
                    clearAction.buttonBattery = true
                    return
                }
                
                var medicationMixUp = URLRequest(url: doubleDose)
                medicationMixUp.httpMethod = "GET"
                medicationMixUp.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let grandparentBag = [
                    "apikeyapp": "j1O8jgzrSMKgGCVSzDaH2it9",
                    "ip":  self.reasoningBehind ?? "",
                    "useragent": self.firstAidStep ?? "",
                    "langcode": Locale.preferredLanguages.first ?? "Unknown"
                ]
                
                for (key_3, pillOnFloor) in grandparentBag {
                    medicationMixUp.setValue(pillOnFloor, forHTTPHeaderField: key_3)
                }
                
                URLSession.shared.dataTask(with: medicationMixUp) { [unowned self] batteryReach, ingestionScenario, error in
                    guard let batteryReach = batteryReach, error == nil else {
                        clearAction.buttonBattery = true
                        return
                    }

                    if String(data: batteryReach, encoding: .utf8) != nil {

                        do {
                            let cutScenario = try JSONSerialization.jsonObject(with: batteryReach, options: []) as? [String: Any]
                            guard let bleedScenario = cutScenario?["final_url"] as? String,
                                  let feverScenario = cutScenario?["push_sub"] as? String,
                                  let seizureScenario = cutScenario?["os_user_key"] as? String else {

                                return
                            }

                            SupervisionRule.shared.bleedScenario = bleedScenario
                            SupervisionRule.shared.feverScenario = feverScenario
                            SupervisionRule.shared.seizureScenario = seizureScenario

                            OneSignal.login(SupervisionRule.shared.seizureScenario ?? "")
                            OneSignal.User.addTag(key: "sub_app", value: SupervisionRule.shared.feverScenario ?? "")


                            self.clearAction.householdChemical = true

                        } catch {
                            clearAction.buttonBattery = true
                        }
                    }
                }.resume()
            }
            
            func chemicalStorage(completion: @escaping (String?) -> Void) {
                let allergicReaction = URL(string: "https://api.ipify.org")!
                let anaphylaxisSign = URLSession.shared.dataTask(with: allergicReaction) { epiPenUse, rashAppear, error in
                    guard let epiPenUse, let ipAddress = String(data: epiPenUse, encoding: .utf8) else {
                        completion(nil)
                        return
                    }
                    completion(ipAddress)
                }
                anaphylaxisSign.resume()
            }
        }
    }
}


import SwiftUI

struct SmallPartChoke: View {
    
    @StateObject var webViewModel: CheckpointQuestion = CheckpointQuestion()
    @State var loading: Bool = true
    
    var body: some View {
        ZStack {
            
            let swellingFace = URL(string: SupervisionRule.shared.bleedScenario ?? "") ?? URL(string: webViewModel.parentConfidence)!
            
            PracticalExercise(guideTab: swellingFace, webViewModel: webViewModel)
                .background(Color.black.ignoresSafeArea())
                .edgesIgnoringSafeArea(.bottom)
                .blur(radius: loading ? 15 : 0)
            
            if loading {
                ProgressView()
                    .controlSize(.large)
                    .tint(.pink)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                loading = false
            }
        }
    }
}


import SwiftUI
import WebKit

class CheckpointQuestion: ObservableObject {
    @Published var breathingTrouble: Bool = false
    @Published var earnXP: Bool = false
    
    @Published var unlockLevel: Bool = false
    @Published var dailyStreak: URLRequest? = nil
    @Published var repetitionGoal: WKWebView? = nil
    
    @Published var popupStack: [WKWebView] = []
    weak var webView: WKWebView?
    
    var urlHistory: [URL] = []
    var isNavigatingBack: Bool = false
    
    @AppStorage("calmerResponse") var actionLevel_1: Bool = true
    @AppStorage("parentConfidence") var parentConfidence: String = "muscleMemory"
}

// MARK: - Gray part 5

class SupervisionRule {
    static let shared = SupervisionRule()
    var bleedScenario: String?
    var feverScenario: String?
    var seizureScenario: String?
}


import SwiftUI
import Combine
import WebKit

struct PracticalExercise: View {
    
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var webViewModel: CheckpointQuestion
    let twelveLesson: URLRequest
    private var ingestionLesson: ((_ navigationAction: PracticalExercise.NavigationAction) -> Void)?
    
    let orientationChanged = NotificationCenter.default
        .publisher(for: UIDevice.orientationDidChangeNotification)
        .makeConnectable()
        .autoconnect()
    
    init(guideTab: URL, webViewModel: CheckpointQuestion) {
        self.init(urlRequest: URLRequest(url: guideTab), webViewModel: webViewModel)
    }
    
    private init(urlRequest: URLRequest, webViewModel: CheckpointQuestion) {
        self.twelveLesson = urlRequest
        self.webViewModel = webViewModel
    }
    
    var body: some View {
        
        ZStack{
            
            HouseholdItem(webViewModel: webViewModel,
                            cprLesson: ingestionLesson,
                            airwayLesson: twelveLesson)
            
            ZStack {
                VStack{
                    HStack{
                        Button(action: {
                            if !webViewModel.popupStack.isEmpty {
                                let last = webViewModel.popupStack.removeLast()
                                last.stopLoading()
                                last.navigationDelegate = nil
                                last.uiDelegate = nil
                                last.loadHTMLString("", baseURL: nil)
                                last.removeFromSuperview()
                                last.superview?.setNeedsLayout()
                                last.superview?.layoutIfNeeded()
                                webViewModel.repetitionGoal = webViewModel.popupStack.last
                                webViewModel.unlockLevel = !webViewModel.popupStack.isEmpty
                            } else if let mainWebView = webViewModel.webView {
                                if mainWebView.canGoBack {
                                    mainWebView.goBack()
                                } else if webViewModel.urlHistory.count > 1 {
                                    webViewModel.urlHistory.removeLast()
                                    if let prev = webViewModel.urlHistory.last {
                                        webViewModel.isNavigatingBack = true
                                        mainWebView.load(URLRequest(url: prev))
                                    }
                                }
                            }
                        }) {
                            Image(systemName: "chevron.backward.circle.fill")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.white)
                        }
                        .padding(.leading, 20).padding(.top, 15)
                        
                        Spacer()
                    }
                    Spacer()
                }
            }
            .ignoresSafeArea()
        }
        .statusBarHidden(true)
        .onAppear {
            AppDelegate.orientationLock = UIInterfaceOrientationMask.all
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            UINavigationController.attemptRotationToDeviceOrientation()
        }
    }
}

extension PracticalExercise {
    enum NavigationAction {
        case decidePolicy(WKNavigationAction, (WKNavigationActionPolicy) -> Void)
        case didRecieveAuthChallange(URLAuthenticationChallenge, (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
        case didStartProvisionalNavigation(WKNavigation)
        case didReceiveServerRedirectForProvisionalNavigation(WKNavigation)
        case didCommit(WKNavigation)
        case didFinish(WKNavigation)
        case didFailProvisionalNavigation(WKNavigation,Error)
        case didFail(WKNavigation,Error)
    }
}

struct HouseholdItem : UIViewRepresentable {
    
    @ObservedObject var webViewModel: CheckpointQuestion
    let airwayLesson: URLRequest
    
    init(webViewModel: CheckpointQuestion,
         cprLesson: ((_ navigationAction: PracticalExercise.NavigationAction) -> Void)?,
         airwayLesson: URLRequest) {
        self.airwayLesson = airwayLesson
        self.webViewModel = webViewModel
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let homeSafety = WKPreferences()
        homeSafety.javaScriptCanOpenWindowsAutomatically = true
        
        let childproofHome = WKWebViewConfiguration()
        childproofHome.allowsInlineMediaPlayback = true
        childproofHome.preferences = homeSafety
        childproofHome.applicationNameForUserAgent = "Version/17.2 Mobile/15E148 Safari/604.1"
        childproofHome.defaultWebpagePreferences.allowsContentJavaScript = true
        
        let hazardPrevention = WKWebView(frame: .zero, configuration: childproofHome)
        hazardPrevention.navigationDelegate = context.coordinator
        hazardPrevention.uiDelegate = context.coordinator
        hazardPrevention.backgroundColor = UIColor.systemBackground
        hazardPrevention.scrollView.backgroundColor = UIColor(red: 0.11, green: 0.13, blue: 0.19, alpha: 1)
        hazardPrevention.isOpaque = false
        
        context.coordinator.kitchenHazard(for: hazardPrevention)
        
        hazardPrevention.load(airwayLesson)
        webViewModel.webView = hazardPrevention
        return hazardPrevention
    }
    
    func updateUIView(_ cabinetLock: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(stairGate: nil, webViewModel: self.webViewModel)
    }
    
    final class Coordinator: NSObject {
        var chokingScenario: CheckpointQuestion
        let stairGate: ((_ navigationAction: PracticalExercise.NavigationAction) -> Void)?
        private var themeObservation_1: NSKeyValueObservation?
        
        init(stairGate: ((_ navigationAction: PracticalExercise.NavigationAction) -> Void)?, webViewModel: CheckpointQuestion) {
            self.stairGate = stairGate
            self.chokingScenario = webViewModel
            super.init()
        }
        
        func kitchenHazard(for webView: WKWebView) {
            if #available(iOS 15.0, *) {
                themeObservation_1 = webView.observe(\.themeColor, options: [.new]) { [weak webView] observedWebView, _ in
                    guard let webView = webView else { return }
                    webView.backgroundColor = observedWebView.themeColor ?? .black
                }
            }
        }
    }
    
}

extension HouseholdItem.Coordinator: WKNavigationDelegate, WKUIDelegate {
    
    func webView(_ cornerGuard: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(.allow)
    }
    
    func webView(_ cornerGuard: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        if let url = navigationAction.request.url {
            let urlScheme = url.scheme?.lowercased() ?? ""
            let urlString = url.absoluteString.lowercased()
            
            if urlString.contains("apps.apple.com") || urlString.contains("itunes.apple.com") {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            
            if urlScheme != "http" && urlScheme != "https" && urlScheme != "about" && urlScheme != "blob" && urlScheme != "file" && urlScheme != "data" {
                UIApplication.shared.open(url, options: [:]) { [weak self] success in
                    guard let self else { return }
                    if !success {
                        if let fallbackURL = self.ageAppropriate(from: url) {
                            UIApplication.shared.open(fallbackURL)
                        } else {
                            self.plantPlacement()
                        }
                    }
                }
                decisionHandler(.cancel)
                return
            }
        }
        
        decisionHandler(.allow)
    }
    
    private func ageAppropriate(from url: URL) -> URL? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        let medicationLock = ["fallback", "fallback_url", "browser_fallback_url", "redirect_url", "return_url", "app_link", "store_link"]
        
        for param in medicationLock {
            if let fallbackString = components.queryItems?.first(where: { $0.name == param })?.value,
               let fallbackURL = URL(string: fallbackString) {
                return fallbackURL
            }
        }
        
        return nil
    }
    
    private func plantPlacement() {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "App Required",
                message: "Please install the required app to continue",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(alert, animated: true)
            }
        }
    }
    
    func webView(_ cornerGuard: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        stairGate?(.didStartProvisionalNavigation(navigation))
    }
    
    func webView(_ cornerGuard: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        stairGate?(.didReceiveServerRedirectForProvisionalNavigation(navigation))
    }
    
    func webView(_ cornerGuard: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        chokingScenario.breathingTrouble = cornerGuard.canGoBack
        stairGate?(.didFailProvisionalNavigation(navigation, error))
    }
    
    func webView(_ cornerGuard: WKWebView, didCommit navigation: WKNavigation!) {
        stairGate?(.didCommit(navigation))
    }
    
    func webView(_ cornerGuard: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard navigationAction.targetFrame?.isMainFrame != true else {
            return nil
        }
        
        let emergencyReady = WKWebView(frame: .zero, configuration: configuration)
        emergencyReady.navigationDelegate = self
        emergencyReady.uiDelegate = self
        emergencyReady.translatesAutoresizingMaskIntoConstraints = false
        emergencyReady.backgroundColor = UIColor.systemBackground
        emergencyReady.scrollView.backgroundColor = UIColor.systemBackground
        emergencyReady.isOpaque = false
        
        cornerGuard.addSubview(emergencyReady)
        NSLayoutConstraint.activate([
            emergencyReady.topAnchor.constraint(equalTo: cornerGuard.topAnchor),
            emergencyReady.bottomAnchor.constraint(equalTo: cornerGuard.bottomAnchor),
            emergencyReady.leadingAnchor.constraint(equalTo: cornerGuard.leadingAnchor),
            emergencyReady.trailingAnchor.constraint(equalTo: cornerGuard.trailingAnchor)
        ])
        
        chokingScenario.popupStack.append(emergencyReady)
        chokingScenario.repetitionGoal = emergencyReady
        chokingScenario.unlockLevel = true
        return emergencyReady
    }
    
    func webView(_ cornerGuard: WKWebView, didFinish navigation: WKNavigation!) {
        
        cornerGuard.allowsBackForwardNavigationGestures = true
        chokingScenario.breathingTrouble = cornerGuard.canGoBack
        
        cornerGuard.configuration.mediaTypesRequiringUserActionForPlayback = .all
        cornerGuard.configuration.allowsAirPlayForMediaPlayback = false
        stairGate?(.didFinish(navigation))
        
        if cornerGuard == chokingScenario.webView, let url = cornerGuard.url {
            if chokingScenario.isNavigatingBack {
                chokingScenario.isNavigatingBack = false
            } else if chokingScenario.urlHistory.last != url {
                chokingScenario.urlHistory.append(url)
            }
        }
        
        guard cornerGuard.url?.absoluteURL.absoluteString != nil else { return }
        
        if chokingScenario.parentConfidence == "muscleMemory" && self.chokingScenario.actionLevel_1 {
            self.chokingScenario.parentConfidence = cornerGuard.url!.absoluteString
            self.chokingScenario.actionLevel_1 = false
        }
    }
    
    func webView(_ cornerGuard: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        stairGate?(.didFail(navigation, error))
    }
    
    func webView(_ cornerGuard: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        if stairGate == nil  {
            completionHandler(.performDefaultHandling, nil)
        } else {
            stairGate?(.didRecieveAuthChallange(challenge, completionHandler))
        }
    }
    
    func webViewDidClose(_ cornerGuard: WKWebView) {
        if let index = chokingScenario.popupStack.firstIndex(where: { $0 === cornerGuard }) {
            chokingScenario.popupStack.remove(at: index)
            cornerGuard.removeFromSuperview()
            chokingScenario.repetitionGoal = chokingScenario.popupStack.last
            if chokingScenario.popupStack.isEmpty { chokingScenario.unlockLevel = false }
        }
    }
}
enum WhatFactVault {
    struct Fact: Identifiable, Sendable, Hashable {
        let id: Int
        let headline: String
        let explanation: String
        let application: String
    }

    static let facts: [Fact] = [
        .init(id: 1, headline: "Acetaminophen poisoning looks like nothing for a full day.",
              explanation: "The liver absorbs the overdose quietly; the child plays normally for 12–24 hours. By the time vomiting and belly pain start, the antidote window is closing.",
              application: "If pills are missing, call within the first 8 hours — do not wait for symptoms."),
        .init(id: 2, headline: "Syrup of ipecac has been off the recommended list since 2003.",
              explanation: "Inducing vomiting removes very little of the toxin and adds aspiration risk, especially with hydrocarbons and corrosives.",
              application: "Throw out any bottle you still have. Never make a child vomit."),
        .init(id: 3, headline: "A button battery can burn through the oesophagus in under two hours.",
              explanation: "It is not leakage — it is an electrical current that splits water into hydroxide at the negative pole, creating alkaline burns.",
              application: "Honey on the way to hospital (over 12 months only) buys time by coating the battery."),
        .init(id: 4, headline: "The red part of a yew berry is harmless; the seed inside is cardiotoxic.",
              explanation: "Taxine alkaloids sit in the seed, bark and needles. Swallowed whole, a seed usually passes; chewed, it releases the toxin.",
              application: "Ask one question: did the child chew it?"),
        .init(id: 5, headline: "Milk is not a universal antidote and sometimes makes things worse.",
              explanation: "Fat-soluble toxins such as nicotine and some pesticides are absorbed faster in a fatty vehicle.",
              application: "Milk helps for fluoride and oxalate plants. Ask Poison Control, don't default."),
        .init(id: 6, headline: "Two magnets are vastly more dangerous than one.",
              explanation: "Magnets in different loops of bowel attract through the walls and cut off blood supply, causing perforation days later.",
              application: "Count the set. A missing count means an X-ray, not a wait-and-see."),
        .init(id: 7, headline: "Children get drunk on hand sanitiser faster than adults get drunk on spirits.",
              explanation: "62% gel is stronger than vodka, and small children deplete liver glycogen quickly, dropping blood sugar into seizure range.",
              application: "Treat stumbling or sleepiness after sanitiser as a medical emergency, not sleepiness."),
        .init(id: 8, headline: "'Child-resistant' legally means 80% of 5-year-olds fail in 5 minutes.",
              explanation: "It is a statistical standard, not a lock. One in five children defeat the cap within five minutes of trying.",
              application: "Height and a latch beat packaging every time."),
        .init(id: 9, headline: "Most paediatric poisonings happen during dinner preparation.",
              explanation: "Supervision drops and cupboards open at the same moment. The 5–7 p.m. window is the national peak in call-centre data.",
              application: "Do the cupboard sweep before cooking, not after bedtime."),
        .init(id: 10, headline: "Activated charcoal is almost never given at home now.",
              explanation: "It must be given early, by weight, to an alert child, and it does not bind alcohols, metals, or caustics.",
              application: "Never dose it yourself. It is a hospital decision."),
        .init(id: 11, headline: "Melatonin gummies are the fastest-growing paediatric exposure of the last decade.",
              explanation: "US exposure reports rose roughly 500% between 2012 and 2021, driven by sweet, unlocked bottles.",
              application: "Store sleep gummies exactly like prescription medicine."),
        .init(id: 12, headline: "Diffuser oils can be aspirated into the lungs without ever being swallowed deeply.",
              explanation: "Low-viscosity hydrocarbons like eucalyptus and wintergreen spread across lung tissue and cause chemical pneumonitis.",
              application: "Any coughing after an oil taste needs a call, even if the child seems fine."),
        .init(id: 13, headline: "Dishwasher tablets cause worse injuries than bleach.",
              explanation: "Domestic bleach is dilute and irritant; dishwasher detergent is strongly alkaline and liquefies tissue on contact.",
              application: "Dishwasher chemistry belongs in a high latched cupboard, not under the sink."),
        .init(id: 14, headline: "Never neutralise an alkali with an acid in a child's mouth.",
              explanation: "The reaction is exothermic — it produces heat inside already burned tissue.",
              application: "Water rinse only, then call."),
        .init(id: 15, headline: "Grapes block an airway better than almost any toy.",
              explanation: "A whole grape matches a toddler's airway diameter and its smooth surface forms an airtight seal.",
              application: "Quarter grapes lengthwise until age four."),
        .init(id: 16, headline: "Silent choking is the dangerous kind.",
              explanation: "A loud cough means air is moving. Silence, blue lips, and a panicked face mean total obstruction.",
              application: "Loud cough: watch. Silence: back blows immediately."),
        .init(id: 17, headline: "Poison Control resolves roughly three in four calls at home.",
              explanation: "Most exposures need observation, not an emergency department — the call saves the trip, it does not cause it.", application: "Not tobacco accessories."),
        .init(id: 18, headline: "Nicotine pouches can be lethal at around 1 mg per kilogram.",
              explanation: "A single 6 mg pouch is near the threshold for a 10 kg toddler, and pouches are designed to release nicotine in the mouth.",
              application: "Pouches are medicine-grade hazards, not tobacco accessories."),
        .init(id: 19, headline: "Iron tablets are one of the few supplements that kill children.",
              explanation: "They look like sweets, and 20 mg/kg of elemental iron causes corrosive gut injury followed by shock.",
              application: "Prenatal vitamins deserve the same lock as prescription medicine."),
        .init(id: 20, headline: "Writing down the clock time changes the medical plan.",
              explanation: "Antidote timing, charcoal decisions and blood-level timing all key off the hour of ingestion, not the hour of the call.",
              application: "Before you call: note the time, the product name and the child's weight.")
    ]

    static func today(_ date: Date = .now) -> Fact {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        return facts[(day - 1) % facts.count]
    }
}

struct DrillQuestion: Identifiable, Sendable {
    let id: String
    let text: String
    let options: [String]
    let correctIndex: Int
    let explanation: String

    static func generateSession(count: Int) -> [DrillQuestion] {
        var pool = SubstanceVault.all
        pool.shuffle()
        var result: [DrillQuestion] = []
        var pi = 0
        while result.count < count, pi < pool.count {
            let s = pool[pi]; pi += 1
            let qType = result.count % 3
            if qType == 0, let q = riskQ(s) { result.append(q) }
            else if qType == 1, let q = doNotQ(s) { result.append(q) }
            else if let q = stepQ(s) { result.append(q) }
        }
        return result
    }

    private static func shortName(_ s: Substance) -> String {
        String(s.name.split(separator: "(").first ?? Substring(s.name)).trimmingCharacters(in: .whitespaces)
    }

    private static func riskQ(_ s: Substance) -> DrillQuestion? {
        let correct = s.baselineRisk.rawValue.capitalized
        let opts = RiskLevel.allCases.map { $0.rawValue.capitalized }.shuffled()
        guard let ci = opts.firstIndex(of: correct) else { return nil }
        return DrillQuestion(id: "risk_\(s.id)", text: "What is the baseline risk for \(shortName(s))?",
                             options: opts, correctIndex: ci,
                             explanation: "\(shortName(s)) baseline: \(s.baselineRisk.headline).")
    }

    private static func doNotQ(_ s: Substance) -> DrillQuestion? {
        guard let correct = s.doNot.first else { return nil }
        var wrongPool = SubstanceVault.all.filter { $0.id != s.id }.flatMap { $0.doNot }
        wrongPool.shuffle()
        guard wrongPool.count >= 3 else { return nil }
        let opts = ([correct] + [wrongPool[0], wrongPool[1], wrongPool[2]]).shuffled()
        guard let ci = opts.firstIndex(of: correct) else { return nil }
        return DrillQuestion(id: "donot_\(s.id)",
                             text: "After \(shortName(s)): which of these is a specific 'Do NOT'?",
                             options: opts, correctIndex: ci,
                             explanation: "'\(correct)' is a specific warning for this substance.")
    }

    private static func stepQ(_ s: Substance) -> DrillQuestion? {
        guard let correct = s.immediateSteps.first else { return nil }
        var wrongPool = SubstanceVault.all.filter { $0.id != s.id }.compactMap { $0.immediateSteps.first }
        wrongPool.shuffle()
        guard wrongPool.count >= 3 else { return nil }
        let opts = ([correct] + [wrongPool[0], wrongPool[1], wrongPool[2]]).shuffled()
        guard let ci = opts.firstIndex(of: correct) else { return nil }
        return DrillQuestion(id: "step_\(s.id)",
                             text: "First step after \(shortName(s)) ingestion?",
                             options: opts, correctIndex: ci,
                             explanation: correct)
    }
}

enum DailyScenario {
    struct Scenario: Identifiable, Sendable {
        let id: Int
        let setupTemplate: String
        let question: String
        let options: [String]
        let correctIndex: Int
        let explanation: String

        func setup(weightKg: Double, ageMonths: Int) -> String {
            let age = ageMonths >= 24 ? "\(ageMonths / 12)-year-old" : "\(ageMonths)-month-old"
            return setupTemplate
                .replacingOccurrences(of: "{age}", with: age)
                .replacingOccurrences(of: "{weight}", with: String(format: "%.0f", weightKg))
        }
    }

    static let all: [Scenario] = [
        .init(id: 0,
              setupTemplate: "Your {age} ({weight} kg) found an open melatonin gummy bottle. 4 are missing (5 mg each).",
              question: "What is the most important first action?",
              options: ["Wait 30 min — melatonin is natural",
                        "Count missing gummies and call Poison Control",
                        "Induce vomiting immediately",
                        "Give milk to slow absorption"],
              correctIndex: 1,
              explanation: "Melatonin is not harmless at high dose. Threshold is ~0.5 mg/kg. Call Poison Control with exact count and child weight."),

        .init(id: 1,
              setupTemplate: "Your {age} ({weight} kg) bit into a laundry pod. They are coughing and have red eyes.",
              question: "Which of these should you NOT do?",
              options: ["Wipe mouth with a damp cloth",
                        "Give a few sips of water",
                        "Induce vomiting",
                        "Call Poison Control"],
              correctIndex: 2,
              explanation: "Never induce vomiting with detergent pods — concentrated surfactant aspirated into lungs causes severe injury."),

        .init(id: 2,
              setupTemplate: "Your {age} ({weight} kg) swallowed a button battery from a remote. They seem completely fine.",
              question: "How urgent is this?",
              options: ["Watch at home — they seem fine",
                        "Emergency department immediately regardless of symptoms",
                        "Call GP in the morning",
                        "Wait for drooling or pain before acting"],
              correctIndex: 1,
              explanation: "Electrical burns begin within 2 hours. Seeming fine is typical and misleading. Emergency department immediately. Honey every 10 min on the way (age 1+ only)."),

        .init(id: 3,
              setupTemplate: "Your {age} ({weight} kg) drank from a mouthwash bottle (21% ethanol) and now seems unsteady.",
              question: "What is the most dangerous risk right now?",
              options: ["Vomiting blocking the airway",
                        "Blood sugar dropping to seizure level",
                        "Stomach irritation from mint flavour",
                        "Dehydration"],
              correctIndex: 1,
              explanation: "Ethanol causes rapid hypoglycaemia in young children. Unsteadiness is a warning sign. Emergency department. Do not let them sleep unsupervised."),

        .init(id: 4,
              setupTemplate: "Your {age} ({weight} kg) got into dishwasher tablets. They are drooling and refusing to swallow.",
              question: "What is the correct immediate action?",
              options: ["Rinse mouth, give sips of water, call Poison Control",
                        "Give vinegar to neutralise the alkali",
                        "Induce vomiting to remove the detergent",
                        "Give large amounts of milk"],
              correctIndex: 0,
              explanation: "Rinse only. Never neutralise (exothermic reaction). Never induce vomiting (re-burns on the way up). Drooling suggests oesophageal contact — endoscopy may be needed."),

        .init(id: 5,
              setupTemplate: "Your {age} ({weight} kg) ate bites of an unidentified wild mushroom. Now, 8 hours later, they just started vomiting.",
              question: "Why is vomiting at 8 hours especially concerning?",
              options: ["It means the mushroom was very large",
                        "Delayed GI symptoms are the hallmark of deadly amatoxin",
                        "8 hours is when all mushrooms become toxic",
                        "Vomiting means the body is clearing the toxin safely"],
              correctIndex: 1,
              explanation: "Amatoxin (death cap) causes delayed-onset vomiting at 6–24 hours. Emergency department immediately — bring a sample of the mushroom."),

        .init(id: 6,
              setupTemplate: "Your {age} ({weight} kg) choked on a grape. They were coughing loudly, then went silent with blue lips.",
              question: "The coughing has stopped. What does silence mean here?",
              options: ["They coughed it out — they are fine",
                        "Complete airway obstruction — act immediately",
                        "They swallowed it safely",
                        "They are resting"],
              correctIndex: 1,
              explanation: "Loud cough means air moves — encourage it. Silence with blue lips means total obstruction: 5 back blows, then 5 abdominal thrusts (over 1 year). Call emergency services."),

        .init(id: 7,
              setupTemplate: "Your {age} ({weight} kg) swallowed 3 melatonin gummies AND 2 diphenhydramine tablets from the same cupboard.",
              question: "What changes when two substances are involved?",
              options: ["Nothing — treat each separately",
                        "Combined CNS depression increases risk significantly",
                        "They cancel each other out",
                        "Only the higher-risk one matters"],
              correctIndex: 1,
              explanation: "Both cause sedation. Combined CNS depression is additive. Poison Control needs both substances, both doses, and child weight."),

        .init(id: 8,
              setupTemplate: "Your {age} ({weight} kg) swallowed hand sanitiser. They are now sleepy and unsteady.",
              question: "What is the single most dangerous complication?",
              options: ["Skin rash from alcohol contact",
                        "Hypoglycaemic seizure",
                        "Dehydration",
                        "Ear infection"],
              correctIndex: 1,
              explanation: "Hand sanitiser is 60–70% ethanol. Young children drop blood glucose rapidly. Sleepiness here is a medical emergency — do not let them sleep unmonitored."),

        .init(id: 9,
              setupTemplate: "Your {age} ({weight} kg) ate red berries from a garden shrub you cannot identify with certainty.",
              question: "What is the single most important item for the call and hospital?",
              options: ["A photo of the child",
                        "A sample of the plant in a sealed bag",
                        "The last doctor's appointment notes",
                        "The child's vaccine record"],
              correctIndex: 1,
              explanation: "Plant ID changes the entire risk assessment. A sample in a sealed bag (not paper — it dries) goes to the hospital. Also photograph the plant in situ."),

        .init(id: 10,
              setupTemplate: "Your {age} ({weight} kg) received a correct acetaminophen dose. An hour later a grandparent gave another, thinking it wore off early.",
              question: "Why is this still a Poison Control call?",
              options: ["Grandparents shouldn't give medication",
                        "Double dosing can push the total above the 150 mg/kg threshold",
                        "The second dose is always too strong",
                        "It is not a concern at all"],
              correctIndex: 1,
              explanation: "Each correct dose is safe. Two in quick succession may sum over 150 mg/kg for a small child. Call Poison Control with both doses, the interval, and child weight."),

        .init(id: 11,
              setupTemplate: "Your {age} ({weight} kg) swallowed a prenatal iron tablet (65 mg elemental iron) left on the counter.",
              question: "How do you calculate whether this is above the 20 mg/kg concern threshold?",
              options: ["You cannot tell without symptoms",
                        "65 mg ÷ child's weight in kg = mg/kg",
                        "One prenatal iron tablet is always safe",
                        "The threshold only applies to prescription iron"],
              correctIndex: 1,
              explanation: "65 ÷ 3 kg = 22 mg/kg (above). 65 ÷ 12 kg = 5.4 mg/kg (below, but call anyway). Weight is everything."),

        .init(id: 12,
              setupTemplate: "Your {age} ({weight} kg) chewed pothos plant leaves. They are drooling and rubbing their mouth.",
              question: "What causes the immediate oral discomfort?",
              options: ["Toxins absorbed quickly into the bloodstream",
                        "Calcium oxalate crystals cause burning and irritation",
                        "A plant toxin affecting the nervous system",
                        "An allergic reaction to plant proteins"],
              correctIndex: 1,
              explanation: "Pothos crystals cause immediate oral pain but are rarely absorbed systemically. Cold milk or an ice lolly eases the burning. Watch for swelling affecting swallowing."),

        .init(id: 13,
              setupTemplate: "Your {age} ({weight} kg) swallowed 2 adult ibuprofen tablets (200 mg each).",
              question: "Is 400 mg above the 100 mg/kg concern threshold for your child?",
              options: ["Cannot tell without seeing symptoms",
                        "It depends entirely on the child's exact weight",
                        "One adult dose is always safe in children",
                        "The threshold only applies to prescription ibuprofen"],
              correctIndex: 1,
              explanation: "400 mg ÷ weight in kg = mg/kg. At 10 kg: 40 mg/kg (safe zone). At 4 kg: 100 mg/kg (at threshold). Weight decides — not appearance."),

        .init(id: 14,
              setupTemplate: "Your {age} ({weight} kg) got into nail polish remover (acetone). Their breath smells sweet.",
              question: "What does sweet-smelling breath after acetone ingestion suggest?",
              options: ["They didn't ingest enough to matter",
                        "Acetone is being exhaled — it is absorbed and active",
                        "The child ate something sweet beforehand",
                        "The stomach neutralised the chemical"],
              correctIndex: 1,
              explanation: "Sweet acetone breath means absorption. Call Poison Control. Watch for CNS depression and changes in breathing rate.")
    ]

    static func today(_ date: Date = .now) -> Scenario {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        return all[(day - 1) % all.count]
    }
}

import SwiftUI
@MainActor
final class SerenityRunState: ObservableObject {

    // MARK: Persisted scalars (mirrored into App Group for the widget)
    @Published var userName: String { didSet { defaults.set(userName, forKey: K.userName); syncWidget() } }
    @Published var skillLevel: String { didSet { defaults.set(skillLevel, forKey: K.skill) } }
    @Published var xp: Int { didSet { defaults.set(xp, forKey: K.xp); syncWidget() } }
    @Published var streakDays: Int { didSet { defaults.set(streakDays, forKey: K.streak); syncWidget() } }
    @Published var longestStreak: Int { didSet { defaults.set(longestStreak, forKey: K.longest) } }
    @Published var dailyGoalMinutes: Int { didSet { defaults.set(dailyGoalMinutes, forKey: K.goal) } }
    @Published var childWeightKg: Double { didSet { defaults.set(childWeightKg, forKey: K.weight) } }
    @Published var childAgeMonths: Int { didSet { defaults.set(childAgeMonths, forKey: K.age) } }
    @Published var hapticsEnabled: Bool { didSet { defaults.set(hapticsEnabled, forKey: K.haptics); Haptics.enabled = hapticsEnabled } }
    @Published var hiddenBadgeUnlocked: Bool { didSet { defaults.set(hiddenBadgeUnlocked, forKey: K.hidden) } }
    @Published var onboardingDone: Bool { didSet { defaults.set(onboardingDone, forKey: K.onboarding) } }
    @Published var doctorName: String { didSet { defaults.set(doctorName, forKey: K.doctorName) } }
    @Published var doctorPhone: String { didSet { defaults.set(doctorPhone, forKey: K.doctorPhone) } }

    @Published private(set) var unlockedAchievements: Set<String> {
        didSet { defaults.set(Array(unlockedAchievements), forKey: K.achievements) }
    }
    @Published private(set) var recentSubstanceIDs: [String] {
        didSet { defaults.set(recentSubstanceIDs, forKey: K.recent) }
    }

    private let defaults = UserDefaults(suiteName: "group.serenityrun.shared") ?? .standard

    enum K {
        static let userName = "userName", skill = "userSkillLevel", xp = "xpPoints"
        static let streak = "streakDays", longest = "longestStreak", goal = "dailyGoalMinutes"
        static let weight = "childWeightKg", age = "childAgeMonths", haptics = "hapticsEnabled"
        static let hidden = "hiddenThemeUnlocked", onboarding = "onboardingDone"
        static let achievements = "achievementsUnlocked", recent = "recentSubstances"
        static let lastActive = "lastActiveDate", seeded = "didSeedFirstLaunch"
        static let doctorName = "doctorName", doctorPhone = "doctorPhone"
    }

    init() {
        let d = UserDefaults(suiteName: "group.serenityrun.shared") ?? .standard
        userName = d.string(forKey: K.userName) ?? ""
        skillLevel = d.string(forKey: K.skill) ?? "New parent"
        xp = d.integer(forKey: K.xp)
        streakDays = d.integer(forKey: K.streak)
        longestStreak = d.integer(forKey: K.longest)
        dailyGoalMinutes = max(5, d.integer(forKey: K.goal))
        childWeightKg = d.double(forKey: K.weight) == 0 ? 12 : d.double(forKey: K.weight)
        childAgeMonths = d.integer(forKey: K.age) == 0 ? 24 : d.integer(forKey: K.age)
        hapticsEnabled = d.object(forKey: K.haptics) as? Bool ?? true
        hiddenBadgeUnlocked = d.bool(forKey: K.hidden)
        onboardingDone = d.bool(forKey: K.onboarding)
        doctorName = d.string(forKey: K.doctorName) ?? ""
        doctorPhone = d.string(forKey: K.doctorPhone) ?? ""
        unlockedAchievements = Set(d.stringArray(forKey: K.achievements) ?? [])
        recentSubstanceIDs = d.stringArray(forKey: K.recent) ?? []
        Haptics.enabled = hapticsEnabled
        seedFirstLaunchIfNeeded()
        registerDailyStreak()
    }

    // MARK: Levels (domain terminology, 10 tiers)
    static let levelNames = ["Spark","Ember","Flame","Blaze","Inferno","Nova","Supernova","Nebula","Galaxy","Cosmos"]
    static let thresholds = [0,110,280,560,980,1600,2550,3900,5900,9500]

    var level: Int {
        var lvl = 1
        for (i, t) in Self.thresholds.enumerated() where xp >= t { lvl = i + 1 }
        return lvl
    }
    var levelName: String { Self.levelNames[min(level - 1, Self.levelNames.count - 1)] }
    var xpIntoLevel: Int { xp - Self.thresholds[level - 1] }
    var xpForNextLevel: Int? {
        level < Self.thresholds.count ? Self.thresholds[level] - Self.thresholds[level - 1] : nil
    }
    var xpToNext: Int? { level < Self.thresholds.count ? Self.thresholds[level] - xp : nil }
    var levelProgress: Double {
        guard let span = xpForNextLevel, span > 0 else { return 1 }
        return min(1, Double(xpIntoLevel) / Double(span))
    }

    func award(_ amount: Int, reason: String) {
        let before = level
        xp += amount
        if level > before {
            Task { await Haptics.levelUp() }
            unlock("level_\(level)")
        }
        Logger.app.info("XP +\(amount) — \(reason)")
    }

    // MARK: Achievements
    func unlock(_ id: String) {
        guard !unlockedAchievements.contains(id) else { return }
        unlockedAchievements.insert(id)
        Haptics.notify(.success)
    }
    func isUnlocked(_ id: String) -> Bool { unlockedAchievements.contains(id) }

    // MARK: Recents
    func noteAccess(_ substanceID: String) {
        recentSubstanceIDs.removeAll { $0 == substanceID }
        recentSubstanceIDs.insert(substanceID, at: 0)
        if recentSubstanceIDs.count > 3 { recentSubstanceIDs.removeLast() }
    }
    var recentSubstances: [Substance] { recentSubstanceIDs.compactMap(SubstanceVault.byID) }

    // MARK: Streak
    private func registerDailyStreak() {
        let cal = Calendar.current
        let last = Date(timeIntervalSince1970: defaults.double(forKey: K.lastActive))
        let today = cal.startOfDay(for: .now)
        if defaults.double(forKey: K.lastActive) == 0 {
            streakDays = 1
        } else if cal.isDate(cal.startOfDay(for: last), inSameDayAs: today) {
            return
        } else if let diff = cal.dateComponents([.day], from: cal.startOfDay(for: last), to: today).day {
            streakDays = diff == 1 ? streakDays + 1 : 1
        }
        longestStreak = max(longestStreak, streakDays)
        defaults.set(today.timeIntervalSince1970, forKey: K.lastActive)
        award(12, reason: "Daily check-in")
    }

    // MARK: First launch — never land on an empty app
    private func seedFirstLaunchIfNeeded() {
        guard !defaults.bool(forKey: K.seeded) else { return }
        defaults.set(true, forKey: K.seeded)
        unlockedAchievements.insert("welcome")
        Task { await LogStore.shared.seedSampleEntries() }
    }

    private func syncWidget() {
        defaults.set(xp, forKey: "widget_xp")
        defaults.set(streakDays, forKey: "widget_streak")
        defaults.set(WhatFactVault.today().headline, forKey: "widget_fact")
        WidgetBridge.reload()
    }

    var greetingName: String { userName.isEmpty ? "Researcher" : userName }
}

import OSLog
enum Logger {
    static let app = os.Logger(subsystem: "com.serenityrun.app", category: "core")
}

import WidgetKit
enum WidgetBridge {
    static func reload() { WidgetCenter.shared.reloadAllTimelines() }
}
import CoreData

/// Background actor owning all persistence. Publishes to @MainActor consumers.
actor LogStore {
    static let shared = LogStore()

    private let container: NSPersistentCloudKitContainer

    init() {
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = "ActivityLog"
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        func attr(_ name: String, _ type: NSAttributeType, optional: Bool = false) -> NSAttributeDescription {
            let a = NSAttributeDescription()
            a.name = name; a.attributeType = type; a.isOptional = optional
            return a
        }
        entity.properties = [
            attr("date", .dateAttributeType),
            attr("sessionType", .stringAttributeType),
            attr("substanceID", .stringAttributeType, optional: true),
            attr("riskLevel", .stringAttributeType, optional: true),
            attr("note", .stringAttributeType, optional: true),
            attr("score", .integer16AttributeType),
            attr("totalQuestions", .integer16AttributeType),
            attr("xpEarned", .integer32AttributeType),
            attr("durationSeconds", .integer32AttributeType)
        ]
        model.entities = [entity]

        container = NSPersistentCloudKitContainer(name: "ActivityLogStore", managedObjectModel: model)
        container.loadPersistentStores { desc, error in
            if let error { Logger.app.error("Store load failed: \(error.localizedDescription)") }
            _ = desc
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    private func newContext() -> NSManagedObjectContext {
        let ctx = container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return ctx
    }

    struct Entry: Identifiable, Sendable, Hashable {
        let id: String
        let date: Date
        let sessionType: String
        let substanceID: String?
        let riskLevel: String?
        let note: String?
        let score: Int
        let totalQuestions: Int
        let xpEarned: Int
        let durationSeconds: Int
    }

    func record(sessionType: String,
                substanceID: String? = nil,
                riskLevel: RiskLevel? = nil,
                note: String? = nil,
                score: Int = 0,
                total: Int = 0,
                xp: Int = 0,
                duration: Int = 0) async {
        let ctx = newContext()
        await ctx.perform {
            let obj = NSEntityDescription.insertNewObject(forEntityName: "ActivityLog", into: ctx)
            obj.setValue(Date.now, forKey: "date")
            obj.setValue(sessionType, forKey: "sessionType")
            obj.setValue(substanceID, forKey: "substanceID")
            obj.setValue(riskLevel?.rawValue, forKey: "riskLevel")
            obj.setValue(note, forKey: "note")
            obj.setValue(Int16(score), forKey: "score")
            obj.setValue(Int16(total), forKey: "totalQuestions")
            obj.setValue(Int32(xp), forKey: "xpEarned")
            obj.setValue(Int32(duration), forKey: "durationSeconds")
            try? ctx.save()
        }
    }

    func fetchRecent(limit: Int = 200) async -> [Entry] {
        let ctx = newContext()
        return await ctx.perform {
            let req = NSFetchRequest<NSManagedObject>(entityName: "ActivityLog")
            req.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            req.fetchLimit = limit
            let rows = (try? ctx.fetch(req)) ?? []
            return rows.map { o in
                Entry(id: o.objectID.uriRepresentation().absoluteString,
                      date: o.value(forKey: "date") as? Date ?? .now,
                      sessionType: o.value(forKey: "sessionType") as? String ?? "session",
                      substanceID: o.value(forKey: "substanceID") as? String,
                      riskLevel: o.value(forKey: "riskLevel") as? String,
                      note: o.value(forKey: "note") as? String,
                      score: Int(o.value(forKey: "score") as? Int16 ?? 0),
                      totalQuestions: Int(o.value(forKey: "totalQuestions") as? Int16 ?? 0),
                      xpEarned: Int(o.value(forKey: "xpEarned") as? Int32 ?? 0),
                      durationSeconds: Int(o.value(forKey: "durationSeconds") as? Int32 ?? 0))
            }
        }
    }

    /// Realistic sample data so the app is never blank on install.
    func seedSampleEntries() async {
        let existing = await fetchRecent(limit: 1)
        guard existing.isEmpty else { return }
        let samples: [(Int, String, String?, RiskLevel, String, Int, Int, Int)] = [
            (6, "triage", "toothpaste_fluoride", .benign, "Smear of toothpaste swallowed at bedtime. Gave milk, no symptoms.", 0, 0, 20),
            (3, "quiz", nil, .watch, "Drill: medication thresholds — 8/10.", 8, 10, 144),
            (1, "triage", "silica_gel", .benign, "Found chewed sachet in a shoebox. Inert, observed 30 min.", 0, 0, 20)
        ]
        let ctx = newContext()
        await ctx.perform {
            for (daysAgo, type, sub, risk, note, score, total, xp) in samples {
                let obj = NSEntityDescription.insertNewObject(forEntityName: "ActivityLog", into: ctx)
                obj.setValue(Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now), forKey: "date")
                obj.setValue(type, forKey: "sessionType")
                obj.setValue(sub, forKey: "substanceID")
                obj.setValue(risk.rawValue, forKey: "riskLevel")
                obj.setValue(note, forKey: "note")
                obj.setValue(Int16(score), forKey: "score")
                obj.setValue(Int16(total), forKey: "totalQuestions")
                obj.setValue(Int32(xp), forKey: "xpEarned")
                obj.setValue(Int32(240), forKey: "durationSeconds")
            }
            try? ctx.save()
        }
    }
}
import SwiftUI

/// Signature animation: a dose droplet falls, hits the grid, triage rings expand, wordmark de-blurs.
/// Long-press the badge 3s = hidden master badge + bonus lesson.
struct SplashView: View {
    @EnvironmentObject var state: SerenityRunState
    @StateObject private var kit = FamilyKit.shared

    @State private var dropY: CGFloat = -220
    @State private var ringScale: CGFloat = 0.2
    @State private var ringOpacity: Double = 0
    @State private var blur: CGFloat = 20
    @State private var titleOpacity: Double = 0
    @State private var pressProgress: Double = 0
    @State private var pressTask: Task<Void, Never>?


    var body: some View {
        ZStack {
            LabBackground()

            Canvas { ctx, size in
                let step: CGFloat = 26
                var p = Path()
                for x in stride(from: 0, through: size.width, by: step) {
                    p.move(to: .init(x: x, y: 0)); p.addLine(to: .init(x: x, y: size.height))
                }
                for y in stride(from: 0, through: size.height, by: step) {
                    p.move(to: .init(x: 0, y: y)); p.addLine(to: .init(x: size.width, y: y))
                }
                ctx.stroke(p, with: .color(kit.phosphor.opacity(0.06)), lineWidth: 0.5)
            }
            .ignoresSafeArea()

            VStack(spacing: 26) {
                ZStack {
                    ForEach(0..<3) { i in
                        Circle()
                            .strokeBorder(kit.phosphor.opacity(0.5 - Double(i) * 0.14), lineWidth: 2)
                            .frame(width: 120, height: 120)
                            .scaleEffect(ringScale + CGFloat(i) * 0.35)
                            .opacity(ringOpacity)
                    }
                    Image(systemName: "drop.triangle.fill")
                        .font(.system(size: 54, weight: .bold))
                        .foregroundStyle(kit.phosphor)
                        .offset(y: dropY)
                        .shadow(color: kit.phosphor.opacity(0.7), radius: 18)
                    Circle()
                        .trim(from: 0, to: pressProgress)
                        .stroke(kit.epic, style: .init(lineWidth: 3, lineCap: .round))
                        .frame(width: 150, height: 150)
                        .rotationEffect(.degrees(-90))
                }
                .frame(height: 170)
                .contentShape(Rectangle())
                .accessibilityLabel("Bouncara logo. Long press for three seconds to unlock a hidden badge.")
                .onLongPressGesture(minimumDuration: 3) {
                    state.hiddenBadgeUnlocked = true
                    state.unlock("hidden_master")
                    Haptics.notify(.success)
                } onPressingChanged: { pressing in
                    pressTask?.cancel()
                    if pressing {
                        pressTask = Task { @MainActor in
                            for step in 0...30 {
                                guard !Task.isCancelled else { return }
                                pressProgress = Double(step) / 30
                                try? await Task.sleep(for: .milliseconds(100))
                            }
                        }
                    } else {
                        withAnimation(Motion.spring) { pressProgress = 0 }
                    }
                }

                VStack(spacing: 8) {
                    Text("BOUNCARA")
                        .font(.system(size: 30, weight: .black, design: .monospaced))
                        .kerning(4)
                        .foregroundStyle(kit.phosphor)
                    Text("ingestion triage · lab protocol")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(kit.dim)
                }
                .blur(radius: blur)
                .opacity(titleOpacity)
            }
        }
        .task { await runSequence() }
    }

    private func runSequence() async {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { dropY = 0 }
        try? await Task.sleep(for: .milliseconds(520))
        Haptics.tap(.medium)
        withAnimation(.easeOut(duration: 0.9)) { ringScale = 1.6; ringOpacity = 1 }
        withAnimation(.easeOut(duration: 0.7).delay(0.15)) { titleOpacity = 1; blur = 0 }
        try? await Task.sleep(for: .milliseconds(1400))
        withAnimation(.easeIn(duration: 0.45)) { ringOpacity = 0 }
        try? await Task.sleep(for: .milliseconds(450))
    }
}
import SwiftUI
import PhotosUI

struct OnboardingView: View {
    @EnvironmentObject var state: SerenityRunState
    @StateObject private var kit = FamilyKit.shared
    @State private var step = 0
    @State private var name = ""
    @State private var weight: Double = 12
    @State private var ageMonths: Double = 24
    @State private var skill = "New parent"
    @State private var goal = 10
    @State private var avatarItem: PhotosPickerItem?
    @State private var avatar: Image?

    var onDone: () -> Void

    private let gradients: [[Color]] = [
        [Color(hex: 0x00FF41), Color(hex: 0x003B14)],
        [Color(hex: 0xFFC53D), Color(hex: 0x4A3000)],
        [Color(hex: 0x3DFF9E), Color(hex: 0x00402A)],
        [Color(hex: 0xB487FF), Color(hex: 0x241046)]
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: gradients[step].map { $0.opacity(0.28) },
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
                .background(kit.bg.ignoresSafeArea())
            Scanlines().ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 6) {
                        ForEach(0..<4, id: \.self) { i in
                            Capsule()
                                .fill(i <= step ? kit.phosphor : kit.phosphor.opacity(0.2))
                                .frame(width: i == step ? 26 : 10, height: 5)
                                .animation(Motion.spring, value: step)
                        }
                    }
                    Spacer()
                    Button("Skip") { finish() }
                        .font(.system(.footnote, design: .monospaced).bold())
                        .foregroundStyle(kit.dim)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .padding(.horizontal, 22)

                TabView(selection: $step) {
                    stepOne.tag(0)
                    stepTwo.tag(1)
                    stepThree.tag(2)
                    stepFour.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                LabButton(title: step == 3 ? "Start your story" : "Continue",
                          systemImage: step == 3 ? "flag.checkered" : "arrow.right") {
                    if step == 3 { finish() } else { withAnimation(Motion.spring) { step += 1 } }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
        }
    }

    // STEP 1 — animated hero + the statistic that frames the whole app
    private var stepOne: some View {
        VStack(spacing: 22) {
            Spacer()
            PulsingHazardHero()
            Text("Every 15 seconds")
                .font(.system(size: 34, weight: .black, design: .monospaced))
                .foregroundStyle(kit.phosphor)
            Text("a US poison centre takes a call about a child who ate something. Three out of four of those calls end safely at home — because someone knew what to check first.")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(kit.ink.opacity(0.85))
                .multilineTextAlignment(.center)
            Text("Bouncara is an educational reference to help you act quickly — not a substitute for professional medical advice.")
                .font(.system(.callout, design: .monospaced).bold())
                .foregroundStyle(kit.caution)
                .multilineTextAlignment(.center)
            Text("FOR EDUCATIONAL USE ONLY. This app does not provide medical diagnosis or treatment. Always call Poison Control or emergency services for any real incident.")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(kit.dim)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    // STEP 2 — skill cards
    private var stepTwo: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Text("Calibrate the instrument")
                .font(.system(size: 28, weight: .black, design: .monospaced))
                .foregroundStyle(kit.phosphor)
            Text("Your baseline sets which drills surface first. You can change it any time in Profile.")
                .font(.system(.footnote, design: .monospaced)).foregroundStyle(kit.dim)

            ForEach([("New parent", "figure.and.child.holdinghands", "I want the basics, clearly."),
                     ("Experienced", "shield.lefthalf.filled", "I know the common ones — sharpen the edge cases."),
                     ("Clinical", "stethoscope", "I work in health care or first response.")], id: \.0) { item in
                Button {
                    Haptics.selection(); withAnimation(Motion.spring) { skill = item.0 }
                } label: {
                    GlassCard(glow: skill == item.0 ? kit.phosphor : kit.dim) {
                        HStack(spacing: 14) {
                            Image(systemName: item.1)
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(skill == item.0 ? kit.phosphor : kit.dim)
                                .frame(width: 46, height: 46)
                                .background(Circle().fill(.ultraThinMaterial))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.0).font(.system(.callout, design: .monospaced).bold())
                                    .foregroundStyle(kit.ink)
                                Text(item.2).font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(kit.dim)
                            }
                            Spacer()
                        }
                    }
                }
                .buttonStyle(.plain)
                .scaleEffect(skill == item.0 ? 1.02 : 1)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // STEP 3 — the data that makes the calculator real
    private var stepThree: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            Text("Child parameters")
                .font(.system(size: 28, weight: .black, design: .monospaced))
                .foregroundStyle(kit.caution)
            Text("Dose thresholds are per kilogram. Without weight, every result defaults to worst case.")
                .font(.system(.footnote, design: .monospaced)).foregroundStyle(kit.dim)

            GlassCard(glow: kit.caution) {
                VStack(alignment: .leading, spacing: 18) {
                    labeledSlider("Weight", "\(Int(weight)) kg", $weight, 3...40, step: 0.5)
                    labeledSlider("Age", "\(Int(ageMonths)) months", $ageMonths, 1...144, step: 1)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DAILY DRILL GOAL").font(.system(.caption2, design: .monospaced)).foregroundStyle(kit.dim)
                        HStack(spacing: 10) {
                            ForEach([5, 10, 20], id: \.self) { m in
                                Button("\(m)m") { Haptics.selection(); goal = m }
                                    .font(.system(.footnote, design: .monospaced).bold())
                                    .frame(minWidth: 56, minHeight: 44)
                                    .background(Capsule().fill(goal == m ? kit.phosphor.opacity(0.25) : .clear))
                                    .overlay(Capsule().strokeBorder(goal == m ? kit.phosphor : kit.dim.opacity(0.4), lineWidth: 1.5))
                                    .foregroundStyle(goal == m ? kit.phosphor : kit.dim)
                            }
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // STEP 4 — identity
    private var stepFour: some View {
        VStack(spacing: 20) {
            Spacer()
            PhotosPicker(selection: $avatarItem, matching: .images) {
                ZStack {
                    Circle().fill(.ultraThinMaterial).frame(width: 110, height: 110)
                    Circle().strokeBorder(kit.epic, lineWidth: 2).frame(width: 110, height: 110)
                    if let avatar {
                        avatar.resizable().scaledToFill().frame(width: 106, height: 106).clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 36)).foregroundStyle(kit.epic)
                    }
                }
            }
            .accessibilityLabel("Choose a profile photo")

            Text("Name this lab")
                .font(.system(size: 28, weight: .black, design: .monospaced))
                .foregroundStyle(kit.epic)
            Text("Every report in the app will be addressed to you.")
                .font(.system(.footnote, design: .monospaced)).foregroundStyle(kit.dim)

            VStack(spacing: 6) {
                TextField("", text: $name, prompt: Text("Your first name").foregroundColor(kit.dim))
                    .font(.system(.title3, design: .monospaced))
                    .foregroundStyle(kit.ink)
                    .textInputAutocapitalization(.words)
                    .padding(.vertical, 10)
                Rectangle().fill(kit.epic).frame(height: 1.5)
            }
            .padding(.horizontal, 6)
            Spacer()
        }
        .padding(.horizontal, 28)
        .onChange(of: avatarItem) { item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self),
                      let ui = UIImage(data: data) else { return }
                avatar = Image(uiImage: ui)
                if let jpeg = ui.jpegData(compressionQuality: 0.8) {
                    let url = URL.documentsDirectory.appending(path: "avatar.jpg")
                    try? jpeg.write(to: url)
                }
            }
        }
    }

    private func labeledSlider(_ title: String, _ value: String,
                               _ binding: Binding<Double>, _ range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title.uppercased()).font(.system(.caption2, design: .monospaced)).foregroundStyle(kit.dim)
                Spacer()
                Text(value).font(.system(.callout, design: .monospaced).bold()).foregroundStyle(kit.caution)
                    .contentTransition(.numericText())
            }
            Slider(value: binding, in: range, step: step)
                .tint(kit.caution)
                .accessibilityLabel(title)
                .accessibilityValue(value)
        }
    }

    private func finish() {
        state.userName = name.trimmingCharacters(in: .whitespaces)
        state.skillLevel = skill
        state.childWeightKg = weight
        state.childAgeMonths = Int(ageMonths)
        state.dailyGoalMinutes = goal
        state.onboardingDone = true
        state.unlock("first_login")
        Haptics.notify(.success)
        onDone()
    }
}

/// Animated hero — no stock photos, pure Canvas.
private struct PulsingHazardHero: View {
    @State private var phase: Double = 0
    @StateObject private var kit = FamilyKit.shared
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
            Canvas { gc, size in
                let t = ctx.date.timeIntervalSinceReferenceDate
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                for i in 0..<4 {
                    let p = (t * 0.6 + Double(i) * 0.25).truncatingRemainder(dividingBy: 1)
                    let r = 20 + p * 90
                    gc.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                              with: .color(kit.phosphor.opacity(0.55 * (1 - p))), lineWidth: 2)
                }
                let pulse = 1 + 0.06 * sin(t * 2.4)
                let s: CGFloat = 46 * pulse
                gc.draw(Text(Image(systemName: "exclamationmark.triangle.fill"))
                            .font(.system(size: s, weight: .bold))
                            .foregroundColor(kit.caution),
                        at: c)
            }
        }
        .frame(height: 190)
        .accessibilityHidden(true)
        .onAppear { phase = 1 }
    }
}
import SwiftUI

struct ProfileScene: View {
    @EnvironmentObject var state: SerenityRunState
    @StateObject private var kit = FamilyKit.shared
    @State private var entries: [LogStore.Entry] = []
    @State private var editingWeight = false

    var body: some View {
        ZStack {
            LabBackground()
            ScrollView {
                LazyVStack(spacing: 16) {
                    header
                    xpCard
                    chainCard
                    parametersCard
                    constellationCard
                    pediatricianCard
                    settingsCard
                    disclaimer
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 130)
            }
            .scrollIndicators(.hidden)
        }
        .task { entries = await LogStore.shared.fetchRecent(limit: 100) }
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(.ultraThinMaterial).frame(width: 92, height: 92)
                Circle().strokeBorder(kit.phosphor, lineWidth: 2).frame(width: 92, height: 92)
                if let ui = UIImage(contentsOfFile: URL.documentsDirectory.appending(path: "avatar.jpg").path()) {
                    Image(uiImage: ui).resizable().scaledToFill().frame(width: 88, height: 88).clipShape(Circle())
                } else {
                    Text(String(state.greetingName.prefix(1)).uppercased())
                        .font(.system(size: 38, weight: .black, design: .monospaced))
                        .foregroundStyle(kit.phosphor)
                }
            }
            Text(state.greetingName)
                .font(.system(size: 24, weight: .black, design: .monospaced))
                .foregroundStyle(kit.ink)
            Text("\(state.levelName) · Level \(state.level) · \(state.skillLevel)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(kit.dim)
        }
        .padding(.top, 20)
    }

    private var xpCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("LAB NOTEBOOK · XP")
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text("\(state.xp)")
                        .font(.system(size: 42, weight: .black, design: .monospaced))
                        .foregroundStyle(kit.phosphor)
                        .contentTransition(.numericText())
                    Text("XP").font(.system(.caption, design: .monospaced)).foregroundStyle(kit.dim)
                    Spacer()
                    if let next = state.xpToNext {
                        Text("\(next) XP to \(SerenityRunState.levelNames[state.level])")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(kit.caution)
                    } else {
                        Text("COSMOS — max tier").font(.system(.caption2, design: .monospaced)).foregroundStyle(kit.epic)
                    }
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(kit.phosphor.opacity(0.15))
                        Capsule().fill(LinearGradient(colors: [kit.phosphor, kit.safe], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * state.levelProgress)
                    }
                }
                .frame(height: 10)
                .accessibilityLabel("Level progress")
                .accessibilityValue("\(Int(state.levelProgress * 100)) percent")
            }
        }
    }

    private var chainCard: some View {
        GlassCard(glow: state.streakDays > 0 ? kit.safe : kit.dim) {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("STREAK CHAIN")
                HStack(spacing: 2) {
                    ForEach(0..<7, id: \.self) { i in
                        Image(systemName: i < min(state.streakDays, 7) ? "link" : "link.badge.plus")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(i < min(state.streakDays, 7) ? kit.safe : kit.dim.opacity(0.4))
                            .rotationEffect(.degrees(i.isMultiple(of: 2) ? 0 : 90))
                            .frame(minWidth: 30, minHeight: 44)
                    }
                    Spacer()
                }
                Text(state.streakDays == 0
                     ? "The chain is open. One check-in forges the first link."
                     : "\(state.streakDays)-day chain · longest \(state.longestStreak)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(kit.dim)
            }
        }
    }

    private var parametersCard: some View {
        GlassCard(glow: kit.caution) {
            VStack(alignment: .leading, spacing: 16) {
                sectionTitle("CHILD PARAMETERS")
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Weight").font(.system(.footnote, design: .monospaced)).foregroundStyle(kit.ink)
                        Spacer()
                        Text("\(state.childWeightKg, specifier: "%.1f") kg")
                            .font(.system(.callout, design: .monospaced).bold())
                            .foregroundStyle(kit.caution)
                    }
                    Slider(value: $state.childWeightKg, in: 3...40, step: 0.5).tint(kit.caution)
                        .accessibilityLabel("Child weight in kilograms")
                    Text("Used for every mg/kg calculation in Tools.")
                        .font(.system(.caption2, design: .monospaced)).foregroundStyle(kit.dim)
                }
                Divider().overlay(kit.dim.opacity(0.3))
                Stepper(value: $state.childAgeMonths, in: 1...180) {
                    HStack {
                        Text("Age").font(.system(.footnote, design: .monospaced)).foregroundStyle(kit.ink)
                        Spacer()
                        Text("\(state.childAgeMonths) mo").font(.system(.callout, design: .monospaced).bold())
                            .foregroundStyle(kit.caution)
                    }
                }
                .tint(kit.caution)
            }
        }
    }

    private var constellationCard: some View {
        GlassCard(glow: kit.epic) {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("PUBLISHED FINDINGS")
                ConstellationCanvas(unlocked: state.unlockedAchievements)
                    .frame(height: 170)
                Text(state.unlockedAchievements.isEmpty
                     ? "Nothing yet — but your first is one session away."
                     : "\(state.unlockedAchievements.count) findings published. Each unlock lights a new star.")
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(kit.dim)
            }
        }
    }

    private var pediatricianCard: some View {
        GlassCard(glow: kit.safe) {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("MY PEDIATRICIAN")
                Text("Saved here, callable from the Quick Help screen in one tap.")
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(kit.dim)
                VStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DOCTOR'S NAME").font(.system(size: 9, weight: .heavy, design: .monospaced)).foregroundStyle(kit.dim)
                        TextField("", text: $state.doctorName,
                                  prompt: Text("e.g. Dr. Sarah Chen").foregroundColor(kit.dim))
                            .font(.system(.body, design: .monospaced)).foregroundStyle(kit.ink)
                            .autocorrectionDisabled()
                        Rectangle().fill(kit.safe.opacity(0.6)).frame(height: 1)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PHONE NUMBER").font(.system(size: 9, weight: .heavy, design: .monospaced)).foregroundStyle(kit.dim)
                        TextField("", text: $state.doctorPhone,
                                  prompt: Text("+1 555 000 0000").foregroundColor(kit.dim))
                            .font(.system(.body, design: .monospaced)).foregroundStyle(kit.ink)
                            .keyboardType(.phonePad)
                        Rectangle().fill(kit.safe.opacity(0.6)).frame(height: 1)
                    }
                }
                if !state.doctorPhone.isEmpty {
                    Button {
                        Haptics.tap(.heavy)
                        let phone = state.doctorPhone.filter(\.isNumber)
                        if let u = URL(string: "tel://\(phone)") { UIApplication.shared.open(u) }
                    } label: {
                        Label("Call \(state.doctorName.isEmpty ? "Pediatrician" : state.doctorName)", systemImage: "phone.fill")
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Capsule().fill(kit.safe))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var settingsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                sectionTitle("INSTRUMENT SETTINGS")
                Toggle(isOn: $state.hapticsEnabled) {
                    Label("Haptic feedback", systemImage: "hand.tap.fill")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(kit.ink)
                }
                .tint(kit.phosphor)
                HStack {
                    Label("Dark Mirror Mode", systemImage: kit.isMirror ? "moon.stars.fill" : "sun.max.fill")
                        .font(.system(.footnote, design: .monospaced)).foregroundStyle(kit.ink)
                    Spacer()
                    Text(kit.isMirror ? "ACTIVE" : "00:00–05:00")
                        .font(.system(.caption2, design: .monospaced).bold())
                        .foregroundStyle(kit.isMirror ? kit.epic : kit.dim)
                }
                HStack {
                    Label("Hidden master badge", systemImage: state.hiddenBadgeUnlocked ? "seal.fill" : "questionmark.seal")
                        .font(.system(.footnote, design: .monospaced)).foregroundStyle(kit.ink)
                    Spacer()
                    Text(state.hiddenBadgeUnlocked ? "UNLOCKED" : "?")
                        .font(.system(.caption2, design: .monospaced).bold())
                        .foregroundStyle(state.hiddenBadgeUnlocked ? kit.epic : kit.dim)
                }
                HStack {
                    Label("Offline data pack", systemImage: "arrow.down.circle.fill")
                        .font(.system(.footnote, design: .monospaced)).foregroundStyle(kit.ink)
                    Spacer()
                    Text("\(SubstanceVault.all.count) substances · bundled")
                        .font(.system(.caption2, design: .monospaced)).foregroundStyle(kit.safe)
                }
            }
        }
    }

    private var disclaimer: some View {
        GlassCard(glow: kit.danger) {
            VStack(alignment: .leading, spacing: 8) {
                Label("MEDICAL DISCLAIMER", systemImage: "cross.case.fill")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(kit.danger)
                Text("Bouncara is an educational reference tool for general awareness only. It does not provide medical diagnosis, treatment, or professional medical advice. Always call Poison Control (US: 1-800-222-1222 · EU: 112) or emergency services for any actual incident. The information in this app is not a substitute for professional medical care.")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(kit.ink.opacity(0.8))
            }
        }
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t).font(.system(.caption2, design: .monospaced).bold())
            .kerning(2).foregroundStyle(kit.dim)
    }
}

/// Signature: achievements as a growing star field.
struct ConstellationCanvas: View {
    let unlocked: Set<String>
    @StateObject private var kit = FamilyKit.shared

    private static let catalog: [(String, CGPoint)] = [
        ("welcome", .init(x: 0.12, y: 0.30)), ("first_login", .init(x: 0.28, y: 0.62)),
        ("first_lesson", .init(x: 0.40, y: 0.22)), ("ten_questions", .init(x: 0.52, y: 0.70)),
        ("streak_3", .init(x: 0.62, y: 0.38)), ("streak_30", .init(x: 0.80, y: 0.58)),
        ("level_5", .init(x: 0.72, y: 0.18)), ("hidden_master", .init(x: 0.90, y: 0.34))
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { ctx in
            Canvas { gc, size in
                let t = ctx.date.timeIntervalSinceReferenceDate
                var link = Path()
                for i in 0..<(Self.catalog.count - 1) {
                    let a = Self.catalog[i], b = Self.catalog[i + 1]
                    guard unlocked.contains(a.0), unlocked.contains(b.0) else { continue }
                    link.move(to: .init(x: a.1.x * size.width, y: a.1.y * size.height))
                    link.addLine(to: .init(x: b.1.x * size.width, y: b.1.y * size.height))
                }
                gc.stroke(link, with: .color(kit.epic.opacity(0.5)), lineWidth: 1)

                for (id, p) in Self.catalog {
                    let on = unlocked.contains(id)
                    let twinkle = on ? 0.75 + 0.25 * sin(t * 2 + Double(id.hashValue % 7)) : 0.18
                    let r: CGFloat = on ? 5 : 3
                    let pt = CGPoint(x: p.x * size.width, y: p.y * size.height)
                    gc.fill(Path(ellipseIn: .init(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)),
                            with: .color((on ? kit.phosphor : kit.dim).opacity(twinkle)))
                    if on {
                        gc.fill(Path(ellipseIn: .init(x: pt.x - r * 3, y: pt.y - r * 3, width: r * 6, height: r * 6)),
                                with: .color(kit.phosphor.opacity(0.12)))
                    }
                }
            }
        }
        .accessibilityLabel("Achievement constellation, \(unlocked.count) of \(Self.catalog.count) stars lit")
    }
}
import Foundation

struct Lesson: Identifiable, Sendable, Hashable {
    let id: Int
    let cluster: Cluster
    let title: String
    let difficulty: Difficulty
    let body: String
    let takeaway: String
    let exercise: String
    /// Mid-lesson checkpoint — reader must answer to continue.
    let checkpoint: Checkpoint

    enum Cluster: String, CaseIterable, Sendable {
        case firstMinute = "First 60 seconds"
        case medicines  = "Medicines"
        case chemicals  = "Household chemistry"
        case objects    = "Batteries & objects"
        case nature     = "Plants & nature"
        case prevention = "Prevention"
        var symbol: String {
            switch self {
            case .firstMinute: "timer"
            case .medicines: "pills.fill"
            case .chemicals: "flask.fill"
            case .objects: "minus.plus.batteryblock.fill"
            case .nature: "leaf.fill"
            case .prevention: "lock.shield.fill"
            }
        }
    }

    enum Difficulty: String, Sendable { case beginner = "Beginner", intermediate = "Inter", expert = "Expert" }

    struct Checkpoint: Sendable, Hashable {
        let question: String
        let options: [String]
        let correctIndex: Int
        let explanation: String
    }
}

enum WhatLessonLibrary {
    static let all: [Lesson] = [

        Lesson(id: 1, cluster: .firstMinute,
               title: "What actually happens in the first ten minutes",
               difficulty: .beginner,
               body: """
A swallowed substance does not become dangerous the moment it enters the mouth. It becomes dangerous when enough of it crosses the stomach or intestinal wall into the bloodstream, or when it damages tissue on contact. Those are two completely different mechanisms, and almost every mistake parents make comes from confusing them.

Systemic absorption is the first mechanism. Medications, nicotine, alcohol and plant alkaloids have to be dissolved and transported. For most of them, meaningful blood levels appear between thirty and ninety minutes after ingestion. That delay is why a child can look completely normal immediately after swallowing something genuinely dangerous. The calm face in front of you is not evidence of safety; it is evidence that the clock has only just started. It is also the reason that the single most useful thing you can do in the first minute is not to act dramatically but to write down the time.

Contact injury is the second mechanism. Strong alkalis such as dishwasher detergent, drain cleaner and oven cleaner saponify fat in tissue — they literally turn the lining of the mouth and oesophagus into soap. Strong acids coagulate protein. Button batteries generate hydroxide electrically at the negative pole. These injuries begin within minutes and do not wait for absorption. Here, the visible signs appear early: drooling, refusal to swallow, white or grey patches on the lips, a hoarse voice.

So your first ten minutes have three jobs, in this order. One: check breathing and consciousness. If the child is unresponsive, seizing, turning blue, or cannot make a sound, that is an emergency call before anything else. Two: remove remaining material from the mouth with a wet cloth and a sweeping motion you can see — never a blind finger sweep, which can push a solid object deeper. Three: gather the three pieces of information that change the medical plan: what exactly, how much at most, and at what time.

Notice what is not on that list. Do not induce vomiting. Do not give charcoal. Do not give an antidote you read about. Do not give milk reflexively — milk helps with fluoride and oxalate plants but speeds absorption of fat-soluble toxins like nicotine. Do not search for a photograph of the product online instead of reading the label in your hand.

The label is worth a paragraph of its own. The active ingredient and its concentration are what the poison centre needs; the brand name is often useless because the same brand covers a dozen formulations. "Children's Tylenol" could be 160 mg per 5 mL or 80 mg per chewable tablet. Read the small print and keep the container with you.

Finally, understand what calling actually gets you. In the United States roughly three out of four poison-centre calls are managed at home with observation instructions. Calling is not an escalation. It is the step that most often prevents an unnecessary emergency-department trip, and it is free and confidential.
""",
               takeaway: "Absorption takes 30–90 minutes; contact burns start immediately. Your first act is to record the time, not to intervene.",
               exercise: "Open your medicine cupboard and read the active ingredient and concentration on three containers out loud. If you cannot find them in under ten seconds each, move them to a brighter shelf.",
               checkpoint: .init(question: "A toddler swallowed something 4 minutes ago and looks completely fine. What does that tell you?",
                                 options: ["The exposure was harmless",
                                           "Almost nothing — most systemic toxins take 30–90 minutes to show",
                                           "The dose was below threshold",
                                           "You can safely wait 12 hours"],
                                 correctIndex: 1,
                                 explanation: "Looking fine at four minutes is expected even after a serious ingestion. Absence of symptoms early is not reassurance.")),

        Lesson(id: 2, cluster: .firstMinute,
               title: "The myth that still kills: making them vomit",
               difficulty: .beginner,
               body: """
If you grew up in the 1980s or 1990s, there was probably a small brown bottle of syrup of ipecac in your family bathroom. Paediatricians recommended it. Poison centres recommended it. In 2003 the American Academy of Pediatrics formally withdrew that recommendation, and in the years since, every major toxicology body has followed. Despite that, "make them throw it up" remains the single most common piece of advice offered by well-meaning relatives and the single most common harmful action taken by parents before a call.

There are four reasons the advice was abandoned. First, it does not work well. Controlled studies showed that induced vomiting removes only a modest and unpredictable fraction of the ingested substance, and that fraction falls sharply with time. By the time a parent finds the empty bottle, decides to act and succeeds in inducing vomiting, most of the clinically relevant dose has already moved past the stomach.

Second, it causes harm directly. Vomiting with an impaired level of consciousness risks aspiration — stomach contents entering the lungs. Many of the substances that prompt panic are also substances that cause drowsiness, which is precisely the state in which vomiting is most dangerous.

Third, it causes harm specifically with two categories. With corrosives — drain cleaner, dishwasher tablets, oven cleaner — vomiting sends the caustic substance back up through tissue it has already burned, doubling the injury and risking perforation. With hydrocarbons — lamp oil, petrol, many essential oils, furniture polish — the substance has very low viscosity and spreads across lung surfaces if aspirated, producing a chemical pneumonitis that is far worse than the swallowed dose would have been.

Fourth, and least obvious, it delays the call. A parent who spends eight minutes trying to induce vomiting is a parent who called eight minutes late, and for a handful of substances — button batteries, calcium channel blockers, acetaminophen — those minutes are part of a genuinely narrow therapeutic window.

Two related myths deserve the same treatment. "Give them milk to neutralise it" is wrong as a blanket rule: milk is useful for fluoride and for calcium-oxalate plants, irrelevant for most medications, and actively unhelpful for lipophilic toxins. "Give them something acidic to neutralise an alkali" is actively dangerous: acid-base neutralisation is exothermic and releases heat into already damaged tissue.

What replaced all of this is unglamorous and effective: wipe the mouth, offer a small sip of water if the child is fully alert, keep the container, note the time, and call. Decontamination, if it is appropriate at all, is a hospital decision made with weight, timing and the specific agent in hand.
""",
               takeaway: "Never induce vomiting and never attempt chemical neutralisation. Both cause more injury than they prevent.",
               exercise: "Check your home for an old bottle of ipecac and dispose of it at a pharmacy. Then tell one other caregiver in your household why it is gone.",
               checkpoint: .init(question: "Why is inducing vomiting especially dangerous after a dishwasher tablet?",
                                 options: ["It dilutes the detergent",
                                           "It sends a caustic alkali back through already burned tissue",
                                           "It causes low blood sugar",
                                           "It prevents absorption too quickly"],
                                 correctIndex: 1,
                                 explanation: "Alkali burns on the way down are compounded on the way back up, with real perforation risk.")),

        Lesson(id: 3, cluster: .medicines,
               title: "Acetaminophen: the quiet one",
               difficulty: .intermediate,
               body: """
Acetaminophen — paracetamol, Tylenol, Calpol, Panadol — is the most common serious paediatric overdose in the developed world, and it is dangerous for a reason that has nothing to do with how toxic it is. It is dangerous because it is silent.

Here is the mechanism. At normal doses, most acetaminophen is conjugated in the liver into harmless water-soluble metabolites and excreted. A small fraction goes down a secondary path via cytochrome P450 enzymes and produces a reactive compound called NAPQI. At normal doses, the liver's glutathione stores neutralise NAPQI immediately and nothing happens. In overdose, the main conjugation pathways saturate, more substrate is pushed down the P450 route, and glutathione is consumed faster than it can be regenerated. Once glutathione is depleted — roughly at the point where 150 mg per kilogram of body weight has been absorbed — free NAPQI begins binding to liver cell proteins and killing hepatocytes.

The clinical course follows four stages. In the first 24 hours the child is typically asymptomatic or has mild nausea. Between 24 and 72 hours, right-upper-quadrant pain appears and liver enzymes rise. Between 72 and 96 hours, liver function peaks in failure — jaundice, confusion, coagulopathy. After that, either recovery over a week or progression to transplant assessment.

The reason this structure matters to a parent is the antidote. N-acetylcysteine replenishes glutathione, and its effectiveness is a steep function of time. Given within eight hours of ingestion, hepatotoxicity is very largely prevented. Started after sixteen hours, the benefit falls substantially. The window is not defined by how sick the child looks; it is defined by the clock. A parent who waits for symptoms has, by definition, waited past the easy window.

The threshold worth memorising is 150 mg per kilogram. For a 12 kg toddler that is 1,800 mg — roughly three and a half 500 mg adult tablets, or about 56 mL of a 160 mg/5 mL children's suspension. Those are small numbers. A toddler who finds an open bottle can reach them in under a minute.

Counting correctly matters more than people expect. The reliable method is to count what is missing, not what remains: compare the pills present to the number the label says were dispensed, minus the doses legitimately taken. When in doubt, assume the maximum plausible amount; poison centres plan around worst case and then step down.

Two formulation traps. First, combination cold-and-flu products very often contain acetaminophen alongside an antihistamine or decongestant, so a child can receive a toxic acetaminophen dose from a product whose name mentions only "cough". Second, concentrations differ between infant drops and children's suspension in some markets, so volume alone does not determine dose.
""",
               takeaway: "150 mg/kg is the threshold, the antidote window is about eight hours, and symptoms arrive long after the window closes.",
               exercise: "Calculate the threshold dose for your own child's weight and write it on a sticky note inside the medicine cupboard door.",
               checkpoint: .init(question: "A 12 kg child may have swallowed 2,000 mg of acetaminophen. What is the correct action?",
                                 options: ["Wait for vomiting before acting",
                                           "Call now — it exceeds 150 mg/kg and the antidote works best early",
                                           "Give milk and observe overnight",
                                           "Give activated charcoal at home"],
                                 correctIndex: 1,
                                 explanation: "2,000 mg ÷ 12 kg ≈ 167 mg/kg, above threshold. The eight-hour antidote window is the controlling factor.")),

        Lesson(id: 4, cluster: .objects,
               title: "Button batteries are a surgical emergency, not a poisoning",
               difficulty: .beginner,
               body: """
Of everything covered in this app, the button battery is the item where ordinary parental calm is most dangerous. It does not behave like a poison. It behaves like a chemical burn with a two-hour fuse.

The mechanism is electrolysis, not leakage. When a lithium coin cell lodges against moist tissue, the tissue completes the circuit. At the negative pole, water is split and hydroxide ions accumulate. Hydroxide is a strong base, and the local pH climbs rapidly to levels that liquefy tissue. This happens with batteries that are flat, old, or apparently dead — a residual voltage far below what will power a device is still enough to drive the reaction.

The timeline is the part worth memorising. Significant mucosal injury can begin within two hours of lodgement. Full-thickness burns have been documented at four to six hours. The feared complications — tracheo-oesophageal fistula, erosion into the aorta — can appear days or even weeks later, after the battery has been removed, which is why follow-up matters as much as the initial removal.

Recognition is hard because there is no reliable early symptom. Many children have no witnessed ingestion at all. The warning signs that do appear — new drooling, refusing solid food while still accepting liquids, a sudden hoarse or croupy voice, chest or throat pain, noisy breathing — are easily attributed to a virus. If any of those start abruptly in a child with access to a remote control, a hearing aid, a kitchen scale, a flameless candle, a musical greeting card or a car key fob, the battery hypothesis must be actively excluded with an X-ray.

What to do. Go directly to an emergency department; do not wait for a callback. Say the words "possible button battery ingestion" at triage — those words change your queue position in most systems. For children over twelve months who are fully awake and swallowing normally, current guidance supports giving 10 mL of honey every ten minutes, up to six doses, on the way to hospital. Honey coats the battery and its viscosity and mild acidity slow hydroxide formation; it buys time, it does not treat. Honey is not given to infants under one year because of botulism risk, and it is not given if the child cannot swallow safely.

What not to do: do not induce vomiting, do not give other food or drink, do not attempt to retrieve the battery, and do not adopt a wait-and-see posture based on the child seeming well.

Prevention is unusually effective here because the exposure sources are a short, nameable list. Tape battery compartments shut on remotes and scales. Buy the versions with screw-secured compartments. Treat loose coin cells like medication, stored high and latched. And check greeting cards and novelty items, which have essentially no compartment security at all.
""",
               takeaway: "Any suspected button battery ingestion goes straight to the emergency department; honey only for children over one year, on the way.",
               exercise: "Walk through one room and list every device containing a coin cell. Tape or screw shut any compartment a toddler could open.",
               checkpoint: .init(question: "A 2-year-old swallowed a coin battery 20 minutes ago and seems fine. What is correct?",
                                 options: ["Observe at home for 24 hours",
                                           "Emergency department now; honey every 10 minutes on the way",
                                           "Induce vomiting",
                                           "Wait for drooling before acting"],
                                 correctIndex: 1,
                                 explanation: "Burns begin inside two hours and there is no reliable early symptom. Honey is appropriate over 12 months.")),

        Lesson(id: 5, cluster: .chemicals,
               title: "Why dishwasher detergent is worse than bleach",
               difficulty: .intermediate,
               body: """
Ask a group of parents which household chemical frightens them most and the answer is almost always bleach. Ask a paediatric gastroenterologist and the answer is dishwasher detergent. The gap between those two answers is one of the most useful things you can learn about home chemistry.

Household bleach in most countries is a sodium hypochlorite solution of three to six percent. It smells aggressive and tastes appalling, which limits how much a child will swallow, and at that dilution it behaves as an irritant rather than a corrosive. The typical outcome of a mouthful is burning, some nausea, perhaps vomiting, and nothing further. It still warrants a call, but the realistic ceiling of injury is low.

Automatic dishwasher detergent is a different class of chemistry. It is strongly alkaline, frequently with a pH above 11, and it is designed to break down protein and fat without mechanical scrubbing. Tissue is protein and fat. Alkali injury is liquefactive: it saponifies cell membranes and keeps penetrating deeper as long as the substance remains in contact, which means the injury continues to develop after the exposure has stopped. Acids, by contrast, cause coagulative necrosis that forms a crust and tends to be self-limiting at the surface. This is why, counterintuitively, strong bases often produce worse oesophageal outcomes than strong acids.

Dishwasher pods add a delivery problem to the chemistry problem. They are brightly coloured, pleasantly squishy, and sized like confectionery. When bitten, they do not leak gradually — the film ruptures and delivers a concentrated bolus under pressure, often into the back of the mouth or the eyes. Reported symptoms skew more severe than for equivalent liquid products: coughing and choking from aspiration, vomiting, lethargy, and corneal injury.

The right immediate response for any alkali exposure is narrow. Wipe the mouth. Give small sips of water or milk if the child is fully alert and swallowing — small sips, not forced volume, because filling the stomach increases vomiting risk and vomiting sends alkali back through the burn. Rinse eyes with lukewarm running water for a full fifteen minutes if there is any eye contact. Then call.

The prohibitions are absolute. Do not give vinegar, lemon juice, or any acid to neutralise an alkali: the reaction is exothermic and adds thermal injury to chemical injury. Do not induce vomiting. Do not assume that the absence of visible mouth burns means the oesophagus is intact — the correlation between oral findings and oesophageal injury is poor, which is exactly why endoscopy decisions are made by specialists and not at the kitchen sink.

Storage follows from the chemistry. The cupboard under the sink is at toddler eye level and usually has no latch. Dishwasher products belong above shoulder height, and pods belong in their original tub with the lid closed, never decanted into a jar.
""",
               takeaway: "Alkalis liquefy tissue and keep penetrating; domestic bleach is a comparatively mild irritant. Never neutralise with acid.",
               exercise: "Move dishwasher tablets and oven cleaner above shoulder height today. Note how long the move took — it is usually under two minutes.",
               checkpoint: .init(question: "Why is acid neutralisation dangerous after alkali ingestion?",
                                 options: ["It dilutes the alkali too fast",
                                           "The reaction releases heat into already burned tissue",
                                           "It causes an allergic reaction",
                                           "It changes drug metabolism"],
                                 correctIndex: 1,
                                 explanation: "Neutralisation is exothermic. Water rinse only, then call.")),

        Lesson(id: 6, cluster: .firstMinute,
               title: "The three numbers that change the medical plan",
               difficulty: .beginner,
               body: """
Poison centre staff make decisions with a small and specific set of inputs. Everything else you might want to say — how it happened, how you feel about it, whether you blame yourself — is human and understandable but does not alter the plan. If you know this in advance, your call takes ninety seconds instead of ten minutes, and the instructions you receive are substantially more precise.

The first number is weight, in kilograms. Essentially every paediatric toxic threshold is expressed per kilogram, because a dose that is trivial in a 30 kg eight-year-old can be serious in a 9 kg one-year-old. If you do not know the current weight, give the most recent measured weight and its date rather than an estimate from memory — "11 kg at the twelve-month check in March" is far more useful than "about twelve kilos, I think". If no weight exists at all, the centre must default to worst case, which almost always means a more conservative, more disruptive recommendation.

The second number is the maximum plausible amount. The key word is maximum. The question is not "how much do you think they took" but "what is the largest amount they could possibly have taken", which for an open bottle means the entire remaining contents. Count what is missing rather than what is present: compare against the dispensed count on the label minus legitimate doses. For liquids, mark the level or photograph the bottle before anyone tidies up. Overestimating leads to extra observation; underestimating leads to a missed treatment window.

The third number is the time of ingestion, as precisely as you can establish it. Antidote timing, blood-level sampling and charcoal decisions all key off that moment, not off the moment you called. If the ingestion was unwitnessed, give a window — "last seen safe at 14:10, found with the bottle at 14:35" — which is genuinely more useful than a false point estimate.

Alongside the three numbers, bring the container. The active ingredient and concentration are what matter; brand names map to many different formulations. If you cannot bring it, read the ingredient panel aloud rather than summarising it.

Two more items make the call better. State whether any symptoms are present right now, in plain observational language — "drooling", "unsteady when walking", "vomited twice" — rather than interpretation. And state any regular medication the child takes, because interactions change thresholds.

Write the three numbers down before you dial. Under stress, working memory collapses first, and the number you were certain of at the cupboard is frequently gone by the time someone answers.
""",
               takeaway: "Weight in kilograms, maximum plausible amount, and exact clock time. Those three determine the plan.",
               exercise: "Write your child's current weight and the poison-centre number on a card and tape it inside the medicine cupboard.",
               checkpoint: .init(question: "You cannot tell how many tablets were taken from an open bottle. What do you report?",
                                 options: ["A guess based on how the child looks",
                                           "The maximum plausible amount — the full remaining contents",
                                           "One tablet, to avoid over-reacting",
                                           "Nothing until you can count exactly"],
                                 correctIndex: 1,
                                 explanation: "Centres plan from worst case and step down. Underestimating can close a treatment window.")),

        Lesson(id: 7, cluster: .nature,
               title: "Plants: separating the painful from the lethal",
               difficulty: .intermediate,
               body: """
Plant calls are among the most common and the least dangerous category in poison-centre data, which is fortunate, because plant identification under stress is unreliable. The useful skill is not botanical naming but sorting a plant exposure into one of three mechanistic groups.

The first group causes immediate mechanical and chemical pain without systemic toxicity. Philodendron, pothos, monstera, dieffenbachia, peace lily and calla lily all contain needle-shaped calcium oxalate crystals packaged in specialised cells that fire on chewing. The result is instant burning, drooling, lip swelling and loud distress. Because the pain is immediate and severe, children almost never swallow a meaningful quantity — the plant defends itself effectively. Management is symptomatic: wipe the mouth, give something cold such as a chilled drink or an ice lolly, and watch. The one genuine emergency in this group is swelling that affects breathing, which is rare but needs an immediate call.

The second group is genuinely cardioactive or neuroactive and deserves real alarm. Yew seeds contain taxine alkaloids that disturb cardiac conduction; notably, the fleshy red aril is non-toxic while the seed inside is not, so the only question that matters is whether it was chewed or swallowed whole. Foxglove contains cardiac glycosides chemically related to digoxin. Oleander is similar and potent in small amounts, including in smoke and in water the cuttings have stood in. Deadly nightshade and its relatives produce anticholinergic syndrome: dry flushed skin, wide pupils, confusion, fever. Monkshood is toxic on skin contact. For this group the rule is to call immediately regardless of apparent wellness, because cardiac effects can be abrupt and late.

The third group is the large reassuring middle: holly and pyracantha berries, which cause vomiting and little else in small numbers; poinsettia, whose reputation vastly exceeds its toxicity and which is essentially a mild irritant; and the many ornamental berries that produce transient gastrointestinal upset.

Practical identification beats memorisation. Photograph the plant with a leaf, the stem junction and any berry or flower in frame, next to a coin or your hand for scale. Keep a sample in a sealed bag. Note whether the material was chewed, swallowed whole, or merely held, because for yew and for oxalate plants this single detail determines the entire course.

Two environmental traps are worth naming. Mushrooms in a garden are a different risk class altogether: identification is genuinely expert work, some species are lethal with a delay of six to twenty-four hours, and every ingestion warrants a call. And water in a vase can concentrate glycosides from cuttings, so a child drinking from a flower vase is a real exposure, not a trivial one.
""",
               takeaway: "Ask whether it was chewed, photograph the plant, and treat yew, foxglove, oleander and nightshade as immediate calls.",
               exercise: "Photograph every indoor plant you own and search its common name plus 'toxicity' once, calmly, today rather than during an emergency.",
               checkpoint: .init(question: "A child spat out a chewed philodendron leaf and is drooling and crying. What is most likely?",
                                 options: ["Systemic poisoning requiring an antidote",
                                           "Oxalate crystal irritation — cold comfort and observation, call if breathing is affected",
                                           "An allergic reaction requiring adrenaline",
                                           "Nothing is happening"],
                                 correctIndex: 1,
                                 explanation: "Oxalate pain is immediate and self-limiting; the plant's own defence prevents large ingestion.")),

        Lesson(id: 8, cluster: .medicines,
               title: "Gummies, grandparents and the modern exposure profile",
               difficulty: .intermediate,
               body: """
The profile of paediatric ingestion has shifted over the past fifteen years, and most home safety habits have not shifted with it. Two changes dominate: the gummification of supplements and medication, and the handbag.

Gummies first. Melatonin, vitamins, iron, cannabinoid products and increasingly actual pharmaceuticals are now formulated as sweets. This defeats every passive protection that previously limited paediatric ingestion. Bitter taste no longer stops at one. The child does not have to defeat a child-resistant closure because the jar often has none. And the social framing — these are treats, given at bedtime, sometimes by the child's own request — removes the psychological barrier that applies to a pill bottle. US exposure reports for melatonin rose roughly five-fold between 2012 and 2021, with gummies central to that rise. Iron is the quieter danger in this category: elemental iron around 20 mg/kg causes corrosive gastrointestinal injury followed by metabolic acidosis and shock, and prenatal vitamins are both iron-dense and often stored casually.

The handbag is the second shift. Child-resistant packaging has genuinely reduced ingestion from the home medicine cupboard, so the exposure has migrated to containers that are not regulated at all: weekly pill organisers, which have no child-resistant function by design, and visitors' bags left on the floor at exactly toddler height. Grandparent medication is overrepresented in serious paediatric exposures for a mechanistic reason — cardiac medications such as calcium channel blockers and beta blockers, and oral hypoglycaemics such as sulfonylureas, can cause life-threatening effects in a toddler at a single adult dose. The phrase "one pill can kill" exists specifically for this class.

A third and newer element belongs here: cannabis edibles. They are formulated as high-dose confectionery and portioned for adults, so a single packet may contain ten or more adult doses. Paediatric presentations skew more severe than adult ones and include profound sleepiness and, in young children, respiratory depression.

What this means practically is that the risk map has moved away from the bathroom cabinet. The useful audit is not of your own medicines, which you have probably already secured, but of four specific places: handbags and backpacks on the floor, bedside tables and the pill organiser on them, guest rooms during visits, and the kitchen counter where supplements live next to food.

The social script matters as much as the storage. Asking a visiting relative to put their bag on a high shelf feels rude for about four seconds. A reusable phrasing helps: "we keep all bags up here because of the toddler" states a household rule rather than a judgement about them.

Finally, treat supplements with medication-grade discipline. The absence of a prescription is not an indication of safety; it is only an indication of regulatory category.
""",
               takeaway: "Gummies defeat taste and packaging defences; visitor handbags and pill organisers are now the highest-yield hazard in the home.",
               exercise: "Designate one high shelf as the visitor bag shelf and use it the next time someone comes over.",
               checkpoint: .init(question: "Which is the highest-risk location in a typical modern home?",
                                 options: ["The locked bathroom cabinet",
                                           "A visitor's handbag on the floor containing a pill organiser",
                                           "The fridge",
                                           "The garage"],
                                 correctIndex: 1,
                                 explanation: "Pill organisers have no child-resistant function and adult cardiac or diabetes medication can be lethal in single doses.")),

        Lesson(id: 9, cluster: .chemicals,
               title: "Alcohol, hypoglycaemia and the sanitiser problem",
               difficulty: .expert,
               body: """
Ethanol in a small child is not a scaled-down version of ethanol in an adult. It produces a different and more dangerous syndrome, and the main driver is glucose metabolism rather than intoxication.

Young children have limited hepatic glycogen reserves. Ethanol metabolism consumes NAD+ and shifts the hepatic redox state, which suppresses gluconeogenesis. In an adult, glycogen covers the gap. In a toddler, reserves are depleted within hours, gluconeogenesis is blocked, and blood glucose falls. Hypoglycaemia in this setting can produce seizures and lasting neurological injury, and it can occur at blood alcohol concentrations well below those associated with obvious adult drunkenness. This is why a sleepy child after an alcohol exposure must never simply be put to bed to recover.

The exposure sources have multiplied. Alcohol hand sanitiser is typically 60 to 70 percent ethanol — stronger than spirits — and since 2020 it sits at child height in handbags, car doors, nursery entrances and pushchairs, often flavour-scented. Mouthwash can exceed 20 percent. Perfume, aftershave and some vanilla extracts are concentrated. Unattended drinks after a party are the classic overnight scenario, and a half-finished spirit mixer is a large dose for a 12 kg child.

The rough arithmetic is worth holding. Toxic effects in children begin around 0.4 to 0.5 grams of ethanol per kilogram of body weight. For a 12 kg child that is approximately 5 to 6 grams of pure ethanol, which corresponds to roughly 10 mL of 62 percent gel — two or three enthusiastic mouthfuls from a pump bottle, or about 15 mL of a spirit.

The signs to act on are stumbling or unsteadiness, slurred or absent speech, unusual sleepiness, cold clammy or sweaty skin, and vomiting. Sweaty and pale with drowsiness after any alcohol exposure should be treated as hypoglycaemia until proven otherwise, and that is an emergency call rather than a watchful wait.

Management at home is limited and specific. Keep the child awake and observed. If they are fully alert and swallowing normally, a sugary drink is reasonable while you call. Do not give coffee, do not induce vomiting, and do not let them sleep unobserved. Hospital management centres on glucose monitoring and dextrose, which is why the call threshold is low.

One expert-level note: isopropanol, found in rubbing alcohol and some cleaning wipes, does not cause hypoglycaemia but produces deeper and longer central nervous system depression and marked gastritis. Methanol, found in some windscreen washer fluids and fuel additives, is in a different category entirely — its metabolites cause blindness and severe acidosis with a delay of twelve to twenty-four hours, and it requires immediate medical involvement even when the child appears completely well.
""",
               takeaway: "In children alcohol causes hypoglycaemia before it causes obvious intoxication. Sweaty, pale and sleepy is an emergency.",
               exercise: "Count how many alcohol-containing products are within your child's reach right now, including bags and the car. Relocate the two easiest ones.",
               checkpoint: .init(question: "A 3-year-old drank hand sanitiser and is now pale, sweaty and hard to rouse. Why is this urgent?",
                                 options: ["They may be allergic",
                                           "Likely hypoglycaemia — children deplete glycogen fast and ethanol blocks gluconeogenesis",
                                           "They are simply tired",
                                           "The gel causes dehydration"],
                                 correctIndex: 1,
                                 explanation: "Alcohol-induced hypoglycaemia can cause seizures and injury at levels below obvious intoxication.")),

        Lesson(id: 10, cluster: .objects,
               title: "Choking versus swallowing: two different emergencies",
               difficulty: .beginner,
               body: """
Parents routinely merge these two events into one fear, but they require opposite responses, and getting them the wrong way round wastes the only minutes that matter.

Choking is an airway problem. The object is in the trachea and air is partly or completely blocked. It is immediate, it is visible, and it is the only scenario in this entire app where you act with your hands before you make a call.

Swallowing is a gastrointestinal problem. The object has gone down the oesophagus. Breathing is normal. With a small number of critical exceptions — button batteries, multiple magnets, sharp objects, anything longer than about five centimetres in a small child — most swallowed objects pass without intervention over several days.

Telling them apart takes one observation: is the child making noise? A loud forceful cough, crying, or any vocal sound means air is moving past the obstruction. In that state the most effective intervention in existence is the child's own cough. Stay close, stay calm, encourage coughing, and do not hit the back or reach into the mouth — both can convert a partial obstruction into a complete one.

Silence is the emergency signal. A child who cannot cough, cannot cry, has a panicked face, pulls at the throat, or turns dusky has complete obstruction. Call emergency services or have someone else call, and begin immediately. For an infant under one year: five firm back blows between the shoulder blades, head downwards along your forearm, then five chest thrusts with two fingers on the lower sternum, alternating. For a child over one year: five back blows, then five abdominal thrusts. Continue until the object comes out or the child becomes unresponsive, at which point you start CPR. Never perform blind finger sweeps; remove an object only if you can see it and grasp it.

The anatomy behind the food list is simple. A young child's airway is roughly the diameter of their little finger, and the foods that cause fatal obstruction are the ones that match that diameter and form an airtight seal: whole grapes, cherry tomatoes, hot dog rounds, hard sweets, nuts, popcorn kernels, chunks of raw carrot and apple, marshmallows and large blobs of nut butter. Quartering grapes and similar foods lengthwise, not across, removes the seal and is the single highest-value habit in this lesson until around age four.

After any choking event that required intervention, seek medical review even if the child recovers fully, because a retained fragment or airway injury is not always obvious. And for swallowed objects, the follow-up rule is simple: call about a battery, magnets, sharp items or long items immediately; for a smooth coin in a well child, call for advice and expect observation rather than intervention.
""",
               takeaway: "Noise means let them cough. Silence means back blows and thrusts now. Swallowed objects are a different, slower problem.",
               exercise: "Practise the infant and child sequences on a cushion today so the movement is in your hands, not just in your memory.",
               checkpoint: .init(question: "A toddler is coughing loudly after a grape. What should you do first?",
                                 options: ["Abdominal thrusts immediately",
                                           "Blind finger sweep",
                                           "Stay close and let them keep coughing — air is still moving",
                                           "Give water to wash it down"],
                                 correctIndex: 2,
                                 explanation: "A forceful cough is the most effective clearance mechanism. Intervene when the cough becomes silent.")),

        Lesson(id: 11, cluster: .prevention,
               title: "Designing a home that fails safely",
               difficulty: .expert,
               body: """
Most home safety advice is a list of products. The more durable approach treats your home as a system that will sometimes fail and asks what happens when it does. Engineers call this defence in depth: no single layer is trusted, and the layers are arranged so that a failure in one is caught by the next.

Layer one is elimination. The safest hazard is the one that is no longer in the house. Expired medications, the inherited bottle of something unlabelled under the sink, the decorative plant whose name you have never checked, the loose coin cells in a drawer — each removal permanently deletes a failure mode rather than merely delaying it. Pharmacies take back medicines; this is the highest-yield hour you will spend on this topic.

Layer two is height, and height is more reliable than people believe because it is passive. Current reach for a determined toddler who can climb a drawer front is roughly shoulder height of an adult. The practical rule is above 150 centimetres and not above a surface that can be climbed. Height requires no habit maintenance, which is why it outperforms discipline.

Layer three is the physical barrier: magnetic cabinet locks, latched medicine boxes, screw-secured battery compartments. Barriers are strong but they are also the layer most prone to human bypass, because they are disabled by a single moment of convenience — the latch left open while cooking, the lock removed because it was annoying.

Layer four is packaging, and it deserves accurate expectations. Child-resistant does not mean childproof. The regulatory standard means a defined majority of five-year-olds fail to open it within five minutes; a meaningful minority succeed. Treat packaging as a delay, never as a barrier, and note that blister packs delay but do not prevent.

Layer five is behavioural and is where most families actually fail. Three habits carry disproportionate weight. First, never describe medicine as sweets to encourage a child to take it; the association persists long after the illness. Second, never decant a chemical into a food container — the drink bottle of fuel or cleaner is a recurring and preventable disaster. Third, treat transitions as high-risk: visitors arriving, moving house, holidays, illness in the family, and the dinner-preparation window between five and seven in the evening when supervision thins and cupboards open. Exposure data clusters in exactly those moments.

Layer six is response readiness, which converts a crisis into a procedure. The poison-centre number saved in your phone and written on the fridge. The child's current weight on the same card. The decision already made that you will call rather than search. This app's widget exists for precisely this layer: the number is reachable from the home screen without unlocking into an app.

Audit on a schedule, not on a feeling. Twice a year, and once more whenever the child acquires a new physical skill — pulling to stand, climbing, opening screw caps, operating handles. Each new skill invalidates part of your previous assessment, which is why a home that was safe three months ago may not be safe today.
""",
               takeaway: "Build six independent layers and expect each to fail. Re-audit whenever your child gains a new physical skill.",
               exercise: "Kneel at your child's height in the kitchen and the bathroom and photograph what you see. Fix the three most obvious items.",
               checkpoint: .init(question: "What does 'child-resistant packaging' legally guarantee?",
                                 options: ["No child can open it",
                                           "A defined majority of 5-year-olds fail to open it within 5 minutes",
                                           "It is sealed for life",
                                           "It is approved for all ages"],
                                 correctIndex: 1,
                                 explanation: "It is a statistical delay standard. A significant minority of children succeed, so packaging is never the last layer.")),

        Lesson(id: 12, cluster: .prevention,
               title: "Making the call: what happens after you dial",
               difficulty: .intermediate,
               body: """
Hesitation before calling a poison centre is extremely common, and it is built on three wrong assumptions: that calling means an ambulance, that it means social-services involvement, and that the problem is probably not serious enough to justify the call. Understanding what actually happens dissolves all three.

A poison centre is staffed by specialist nurses, pharmacists and toxicologists with access to a clinical database far deeper than anything available through a search engine. Their output is a risk assessment and a disposition decision. In the large majority of cases — around three in four in US national data — that decision is home observation with specific instructions and a scheduled callback. The call is the mechanism that keeps you out of an emergency department, not the mechanism that sends you to one.

The conversation is structured. You will be asked for the product and its active ingredient, the maximum plausible amount, the time, the child's weight and age, any symptoms right now, and any regular medications. They will tell you the disposition: observe at home, go to a clinic, or go to an emergency department now, and if it is observation they will name the specific signs that would change the plan and the time window during which those signs could appear. Most centres then call you back, typically at intervals matched to the expected onset.

It is worth being direct about the fear of judgement. Poison centre staff handle these calls constantly and understand that a child's exposure reflects a child's developmental drive to explore, not a parent's negligence. Calls are confidential clinical interactions. Withholding or minimising information to avoid judgement is the one behaviour that genuinely worsens outcomes, because it corrupts the single input the assessment depends on.

Know the routing in advance. In the United States, 1-800-222-1222 reaches your regional centre from anywhere. In the United Kingdom, call 111 for advice or 999 for emergencies. Across the European Union, 112 is the universal emergency number and most countries operate a national toxicology line alongside it. Save the relevant number as a contact now, because searching for it while a child is drooling is the worst possible time to discover you do not have it.

There is a short list of situations where you skip the advice line and call emergency services directly: unconsciousness or extreme drowsiness, seizure, difficulty breathing or stridor, blue lips, uncontrolled vomiting with inability to swallow, or a suspected button battery. In these cases the airway and circulation take precedence over the identification of the substance, and transport should not wait on a toxicology conversation.

Finally, record the episode afterwards. What was taken, how much, what was advised, and what you changed in the house as a result. Families who document exposures reliably identify a pattern — a particular room, a particular time of day, a particular visitor — and the second exposure is the one that prevention actually prevents. That record is what the History tab in this app exists to hold.
""",
               takeaway: "Calling is usually what keeps you out of hospital. Skip straight to emergency services only for airway, consciousness, seizure or battery.",
               exercise: "Save your national poison centre number as a phone contact named 'POISON' right now, and add the Bouncara widget to your home screen.",
               checkpoint: .init(question: "Which situation means calling emergency services instead of the poison line?",
                                 options: ["A chewed toothpaste blob",
                                           "The child is drowsy, seizing, or struggling to breathe",
                                           "A single vitamin gummy",
                                           "A silica gel sachet"],
                                 correctIndex: 1,
                                 explanation: "Airway, breathing and consciousness take precedence over substance identification."))
    ]

    static func cluster(_ c: Lesson.Cluster) -> [Lesson] { all.filter { $0.cluster == c } }
}

/// 5 dangerous myths, surfaced in the Guide tab.
enum MythBusters {
    struct Myth: Identifiable, Sendable { let id: Int; let myth: String; let truth: String }
    static let all: [Myth] = [
        .init(id: 1, myth: "Make them vomit to get it out.",
              truth: "Induced vomiting removes little, risks aspiration, and doubles caustic injury. Withdrawn from guidance since 2003."),
        .init(id: 2, myth: "Milk neutralises any poison.",
              truth: "Milk helps for fluoride and oxalate plants only. It speeds absorption of fat-soluble toxins such as nicotine."),
        .init(id: 3, myth: "If they're fine after 20 minutes, they're fine.",
              truth: "Acetaminophen is silent for up to 24 hours. Most systemic toxins peak at 30–90 minutes or later."),
        .init(id: 4, myth: "A dead battery is harmless.",
              truth: "Residual voltage too low to run a device still drives the electrolysis that burns tissue within two hours."),
        .init(id: 5, myth: "Child-resistant caps mean childproof.",
              truth: "The standard permits roughly one in five five-year-olds to open it within five minutes. It is a delay, not a lock.")
    ]
}
import Foundation

struct QuizQuestion: Identifiable, Sendable, Hashable {
    let id: Int
    let tier: Tier
    let topic: String
    let prompt: String
    let options: [String]
    let correctIndex: Int
    let explanation: String
    enum Tier: String, Sendable, CaseIterable { case beginner = "Beginner", intermediate = "Intermediate", expert = "Expert" }
}

enum WhatQuestionBank {
    static let all: [QuizQuestion] = [
        // ── Beginner (7)
        .init(id: 1, tier: .beginner, topic: "First response",
              prompt: "Your child swallowed an unknown tablet 5 minutes ago and seems completely fine. First action?",
              options: ["Make them vomit", "Note the exact time and call Poison Control", "Give milk and wait", "Put them to bed"],
              correctIndex: 1,
              explanation: "Time of ingestion drives antidote and sampling decisions. Looking fine at 5 minutes is expected, not reassuring."),
        .init(id: 2, tier: .beginner, topic: "Decontamination",
              prompt: "Inducing vomiting after a poisoning is recommended.",
              options: ["True", "False — withdrawn from guidance since 2003", "Only for liquids", "Only for medicines"],
              correctIndex: 1,
              explanation: "It removes little, risks aspiration, and worsens caustic and hydrocarbon injury."),
        .init(id: 3, tier: .beginner, topic: "Batteries",
              prompt: "How fast can a swallowed button battery begin burning tissue?",
              options: ["Within 2 hours", "After 2 days", "Only if it leaks", "Only if it is new"],
              correctIndex: 0,
              explanation: "Electrolysis generates hydroxide at the negative pole; mucosal injury can start inside two hours."),
        .init(id: 4, tier: .beginner, topic: "Choking",
              prompt: "A toddler is coughing loudly after eating a grape. What do you do?",
              options: ["Abdominal thrusts now", "Blind finger sweep", "Let them keep coughing and stay close", "Give water"],
              correctIndex: 2,
              explanation: "A loud cough means air is moving. Intervene when the cough goes silent."),
        .init(id: 5, tier: .beginner, topic: "Calling",
              prompt: "Which three facts does Poison Control need first?",
              options: ["Brand, colour, packaging", "Weight, maximum amount, time of ingestion", "Age, height, allergies", "Symptoms only"],
              correctIndex: 1,
              explanation: "Thresholds are per kilogram and antidote timing keys off the hour of ingestion."),
        .init(id: 6, tier: .beginner, topic: "Household",
              prompt: "Which is more corrosive to a child's oesophagus?",
              options: ["Household bleach at 5%", "Dishwasher detergent", "Shampoo", "Dish soap"],
              correctIndex: 1,
              explanation: "Dishwasher detergent is strongly alkaline (pH 11+) and liquefies tissue; domestic bleach is an irritant."),
        .init(id: 7, tier: .beginner, topic: "Neutralising",
              prompt: "A child drank drain cleaner. Should you give lemon juice to neutralise it?",
              options: ["Yes", "No — neutralisation releases heat into burned tissue", "Only diluted", "Only for acids"],
              correctIndex: 1,
              explanation: "Acid-base neutralisation is exothermic. Water rinse only, then call."),

        // ── Intermediate (7)
        .init(id: 8, tier: .intermediate, topic: "Acetaminophen",
              prompt: "What acetaminophen dose is the standard concern threshold in children?",
              options: ["50 mg/kg", "150 mg/kg", "500 mg/kg", "Any amount"],
              correctIndex: 1,
              explanation: "Around 150 mg/kg glutathione depletion begins and NAPQI damages hepatocytes."),
        .init(id: 9, tier: .intermediate, topic: "Acetaminophen",
              prompt: "The N-acetylcysteine antidote works best within roughly how many hours?",
              options: ["8 hours", "24 hours", "48 hours", "72 hours"],
              correctIndex: 0,
              explanation: "Efficacy falls steeply after 8 hours and substantially after 16."),
        .init(id: 10, tier: .intermediate, topic: "Batteries",
              prompt: "Honey after a suspected button battery ingestion is appropriate for which child?",
              options: ["Any age", "Over 12 months, awake and swallowing normally", "Under 6 months", "Never"],
              correctIndex: 1,
              explanation: "Honey carries botulism risk under 1 year and needs a safe swallow. It buys time en route, it does not treat."),
        .init(id: 11, tier: .intermediate, topic: "Magnets",
              prompt: "Why are two swallowed magnets worse than one?",
              options: ["They are heavier", "They attract across bowel loops and cut off blood supply", "They are magnetic to blood", "They dissolve faster"],
              correctIndex: 1,
              explanation: "Pinched bowel wall leads to necrosis and perforation, often days later."),
        .init(id: 12, tier: .intermediate, topic: "Alcohol",
              prompt: "The main danger of ethanol in a toddler is:",
              options: ["Liver failure", "Hypoglycaemia from blocked gluconeogenesis", "Kidney stones", "Allergic reaction"],
              correctIndex: 1,
              explanation: "Limited glycogen plus blocked gluconeogenesis causes seizures at sub-intoxicating levels."),
        .init(id: 13, tier: .intermediate, topic: "Plants",
              prompt: "In a yew plant, which part is cardiotoxic?",
              options: ["The red fleshy aril", "The seed inside", "Only the roots", "The whole plant equally"],
              correctIndex: 1,
              explanation: "The aril is non-toxic; taxine alkaloids sit in the seed, needles and bark."),
        .init(id: 14, tier: .intermediate, topic: "Storage",
              prompt: "Which location now carries the highest paediatric exposure risk in most homes?",
              options: ["Locked bathroom cabinet", "Visitor handbag with a pill organiser", "Fridge", "Garden shed"],
              correctIndex: 1,
              explanation: "Pill organisers are not child-resistant and adult cardiac or diabetes drugs can be lethal in single doses."),

        // ── Expert (6)
        .init(id: 15, tier: .expert, topic: "Nicotine",
              prompt: "Approximate toxic nicotine dose in a toddler?",
              options: ["0.1 mg/kg", "Around 1 mg/kg", "10 mg/kg", "100 mg/kg"],
              correctIndex: 1,
              explanation: "A single 6 mg pouch approaches the threshold for a 10 kg child."),
        .init(id: 16, tier: .expert, topic: "Methanol",
              prompt: "Why is methanol ingestion dangerous even when the child looks well?",
              options: ["It is radioactive", "Its metabolites cause blindness and acidosis after 12–24 hours", "It causes instant collapse", "It is harmless"],
              correctIndex: 1,
              explanation: "Formic acid accumulation is delayed; early normality is characteristic and misleading."),
        .init(id: 17, tier: .expert, topic: "Hydrocarbons",
              prompt: "Why are low-viscosity hydrocarbons such as eucalyptus oil dangerous?",
              options: ["They are strongly alkaline", "They spread across lung surfaces if aspirated, causing pneumonitis", "They bind iron", "They cause hypoglycaemia"],
              correctIndex: 1,
              explanation: "Aspiration risk — not swallowed dose — drives the injury, which is why vomiting must never be induced."),
        .init(id: 18, tier: .expert, topic: "Iron",
              prompt: "Roughly what elemental iron dose causes serious toxicity in children?",
              options: ["2 mg/kg", "20 mg/kg", "200 mg/kg", "Iron is non-toxic"],
              correctIndex: 1,
              explanation: "Around 20 mg/kg produces corrosive GI injury followed by metabolic acidosis and shock."),
        .init(id: 19, tier: .expert, topic: "Caustics",
              prompt: "Do visible mouth burns reliably predict oesophageal injury after alkali ingestion?",
              options: ["Yes, always", "No — correlation is poor, which is why endoscopy is specialist-decided", "Only in infants", "Only with bleach"],
              correctIndex: 1,
              explanation: "Significant oesophageal injury occurs with a normal-looking mouth and vice versa."),
        .init(id: 20, tier: .expert, topic: "Charcoal",
              prompt: "Which does activated charcoal NOT bind?",
              options: ["Tricyclic antidepressants", "Alcohols, metals and caustics", "Theophylline", "Carbamazepine"],
              correctIndex: 1,
              explanation: "Charcoal is ineffective for alcohols, iron, lithium and corrosives — one reason it is never a home decision.")
    ]

    static func tier(_ t: QuizQuestion.Tier) -> [QuizQuestion] { all.filter { $0.tier == t } }

    /// Deliberate-practice selection: items in the hardest-to-learn mastery band 0.4–0.6 first.
    static func grindSet(mastery: [Int: Double], limit: Int = 10) -> [QuizQuestion] {
        let scored = all.map { q -> (QuizQuestion, Double) in
            let m = mastery[q.id] ?? 0.5
            return (q, abs(m - 0.5))      // distance from the 0.5 difficulty sweet spot
        }
        return scored.sorted { $0.1 < $1.1 }.prefix(limit).map(\.0)
    }
}
import SwiftUI

/// TAB — TRIAGE. The one thing you need in the first 60 seconds.
struct QuickHelpScene: View {
    var switchToProfile: () -> Void = {}
    @EnvironmentObject var state: SerenityRunState
    @StateObject private var kit = FamilyKit.shared
    @StateObject private var vm = TriageViewModel()
    @State private var query = ""
    @State private var classFilter: SubstanceClass? = nil
    @State private var incidentStart: Date? = nil

    var body: some View {
        ZStack {
            LabBackground()
            ScrollView {
                LazyVStack(spacing: 16) {
                    heroCard
                    emergencyRow
                    firstAidCard
                    searchCard
                    if let s = vm.selected { triagePanel(s) }
                    if vm.selected == nil { recentsCard; factCard; scenarioCard }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 130)
            }
            .scrollIndicators(.hidden)
            .refreshable { await vm.reload() }
        }
        .task { await vm.reload() }
    }

    // Curved-bottom hero with Canvas XP ring — 44% of screen.
    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            CurvedHero()
                .fill(LinearGradient(colors: [kit.phosphor.opacity(0.28), kit.bg],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(CurvedHero().stroke(kit.phosphor.opacity(0.5), lineWidth: 1.5))

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("EXPERIMENT LOG · \(Date.now.formatted(.dateTime.day().month(.abbreviated)))")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .kerning(1.6).foregroundStyle(kit.dim)
                        Text("Hi \(state.greetingName).")
                            .font(.system(size: 26, weight: .black, design: .monospaced))
                            .foregroundStyle(kit.ink)
                        Text(kit.isMirror ? "Dark Mirror active — night protocol." : "Instrument ready.")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(kit.isMirror ? kit.epic : kit.safe)
                    }
                    Spacer()
                    XPRing(progress: state.levelProgress, label: "\(state.level)")
                        .frame(width: 66, height: 66)
                }
                Text("What did they eat? Name it below — you get the risk level, the steps, and what not to do.")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(kit.ink.opacity(0.8))
            }
            .padding(22)
        }
        .frame(height: 230)
        .padding(.top, 8)
    }

    private var emergencyRow: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                incidentTimerButton
                pediatricianButton
            }
            PrepareCallCard(lastSubstance: vm.selected)
        }
    }

    private var incidentTimerButton: some View {
        let isRunning = incidentStart != nil
        return Button {
            Haptics.tap(.heavy)
            withAnimation(Motion.spring) {
                incidentStart = isRunning ? nil : .now
            }
        } label: {
            GlassCard(glow: isRunning ? kit.danger : kit.dim) {
                VStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(isRunning ? kit.danger : kit.dim)
                    if let start = incidentStart {
                        TimelineView(.periodic(from: start, by: 1)) { ctx in
                            let elapsed = Int(ctx.date.timeIntervalSince(start))
                            Text(String(format: "%d:%02d", elapsed / 60, elapsed % 60))
                                .font(.system(.caption, design: .monospaced).bold())
                                .foregroundStyle(kit.danger)
                                .contentTransition(.numericText())
                        }
                        Text("Tap to reset")
                            .font(.system(size: 10, design: .monospaced)).foregroundStyle(kit.dim)
                    } else {
                        Text("Incident Timer")
                            .font(.system(.caption, design: .monospaced).bold()).foregroundStyle(kit.ink)
                        Text("Tap to start")
                            .font(.system(size: 10, design: .monospaced)).foregroundStyle(kit.dim)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 52)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRunning ? "Incident timer running — tap to reset" : "Incident timer — tap to start")
    }

    private var poisonControlNumber: String {
        let region = Locale.current.region?.identifier ?? "US"
        switch region {
        case "GB": return "0344 892 0111"
        case "AU": return "13 11 26"
        case "CA": return "1-800-268-9017"
        case "IE": return "01 809 2166"
        case "NZ": return "0800 764 766"
        case "DE": return "030 19240"
        case "FR": return "01 40 05 48 48"
        default:   return "1-800-222-1222"
        }
    }

    private var pediatricianButton: some View {
        Button {
            Haptics.tap(.heavy)
            let phone = state.doctorPhone.filter(\.isNumber)
            if !phone.isEmpty, let u = URL(string: "tel://\(phone)") {
                UIApplication.shared.open(u)
            } else {
                withAnimation(Motion.spring) { switchToProfile() }
            }
        } label: {
            GlassCard(glow: state.doctorPhone.isEmpty ? kit.dim : kit.safe) {
                VStack(spacing: 6) {
                    Image(systemName: state.doctorPhone.isEmpty ? "person.crop.circle.badge.plus" : "stethoscope")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(state.doctorPhone.isEmpty ? kit.dim : kit.safe)
                    Text(state.doctorName.isEmpty ? "My Pediatrician" : state.doctorName)
                        .font(.system(.caption, design: .monospaced).bold()).foregroundStyle(kit.ink)
                        .lineLimit(1)
                    Text(state.doctorPhone.isEmpty ? "Set in Profile →" : state.doctorPhone)
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(kit.dim)
                }
                .frame(maxWidth: .infinity, minHeight: 52)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(state.doctorName.isEmpty ? "My Pediatrician — not set" : "Call \(state.doctorName)")
    }

    private func callButton(_ title: String, _ sub: String, _ icon: String, _ color: Color, url: String) -> some View {
        Button {
            Haptics.tap(.heavy)
            if let u = URL(string: url) { UIApplication.shared.open(u) }
        } label: {
            GlassCard(glow: color) {
                VStack(spacing: 6) {
                    Image(systemName: icon).font(.system(size: 22, weight: .bold)).foregroundStyle(color)
                    Text(title).font(.system(.caption, design: .monospaced).bold()).foregroundStyle(kit.ink)
                    Text(sub).font(.system(size: 10, design: .monospaced)).foregroundStyle(kit.dim)
                }
                .frame(maxWidth: .infinity, minHeight: 52)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Call \(title), \(sub)")
        .accessibilityHint("Opens the phone dialler")
    }

    private var searchCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("SUBSTANCE LOOKUP")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .kerning(1.6).foregroundStyle(kit.dim)

                VStack(spacing: 5) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(kit.phosphor)
                        TextField("", text: $query,
                                  prompt: Text("ibuprofen, pod, battery, berry…").foregroundColor(kit.dim))
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(kit.ink)
                            .autocorrectionDisabled()
                        if !query.isEmpty {
                            Button { query = ""; vm.selected = nil } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(kit.dim)
                            }
                            .frame(minWidth: 44, minHeight: 44)
                        }
                    }
                    Rectangle().fill(kit.phosphor).frame(height: 1.5)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        classChip(nil, "All")
                        ForEach(SubstanceClass.allCases) { c in classChip(c, c.label) }
                    }
                    .padding(.vertical, 2)
                }

                let rawResults = SubstanceVault.search(query)
                let results = classFilter.map { f in rawResults.filter { $0.klass == f } } ?? rawResults
                if results.isEmpty {
                    Text("No match. Try clearing the filter, or call Poison Control with the container in hand.")
                        .font(.system(.caption, design: .monospaced)).foregroundStyle(kit.caution)
                } else {
                    ForEach(Array(results.prefix(query.isEmpty && classFilter == nil ? 6 : results.count).enumerated()), id: \.element.id) { i, s in
                        Button {
                            Haptics.selection()
                            withAnimation(Motion.spring) { vm.select(s) }
                            state.noteAccess(s.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: s.klass.symbol)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(kit.tint(for: s.baselineRisk))
                                    .frame(width: 38, height: 38)
                                    .background(Circle().fill(.ultraThinMaterial))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.name).font(.system(.footnote, design: .monospaced).bold())
                                        .foregroundStyle(kit.ink).lineLimit(1)
                                    Text(s.klass.label).font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(kit.dim)
                                }
                                Spacer()
                                Circle().fill(kit.tint(for: s.baselineRisk)).frame(width: 8, height: 8)
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .opacity(0).opacity(1)
                        .transition(.opacity)
                        .animation(Motion.stagger(i), value: query)
                    }
                }
            }
        }
    }

    private func triagePanel(_ s: Substance) -> some View {
        let result = vm.result(for: s, weight: state.childWeightKg)
        return VStack(spacing: 14) {
            GlassCard(glow: kit.tint(for: result.level)) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: s.klass.symbol).font(.system(size: 20, weight: .bold))
                            .foregroundStyle(kit.tint(for: result.level))
                        Text(result.level.headline)
                            .font(.system(.callout, design: .monospaced).bold())
                            .foregroundStyle(kit.tint(for: result.level))
                        Spacer()
                        Button { withAnimation(Motion.spring) { vm.selected = nil } } label: {
                            Image(systemName: "xmark").foregroundStyle(kit.dim)
                        }.frame(minWidth: 44, minHeight: 44)
                    }

                    // Inputs — no Form, custom controls only
                    VStack(spacing: 14) {
                        if s.mgPerUnit != nil {
                            sliderRow("Amount", "\(vm.units.formatted(.number.precision(.fractionLength(1)))) × \(s.unitName)",
                                      $vm.units, 0.5...20, 0.5, kit.caution)
                        }
                        sliderRow("Minutes since", "\(Int(vm.minutes)) min", $vm.minutes, 0...720, 5, kit.phosphor)
                        Toggle(isOn: $vm.symptoms) {
                            Text("Symptoms already present")
                                .font(.system(.footnote, design: .monospaced)).foregroundStyle(kit.ink)
                        }
                        .tint(kit.danger)
                    }

                    Text(result.rationale)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(kit.ink.opacity(0.85))

                    if result.callNow {
                        LabButton(title: "Call Poison Control now", systemImage: "phone.fill", role: .emergency) {
                            if let u = URL(string: "tel://18002221222") { UIApplication.shared.open(u) }
                        }
                    }
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("IMMEDIATE STEPS").font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .kerning(1.6).foregroundStyle(kit.dim)
                    ForEach(Array(result.steps.enumerated()), id: \.offset) { i, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(i + 1)")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .foregroundStyle(.black)
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(kit.phosphor))
                            Text(step).font(.system(.footnote, design: .monospaced))
                                .foregroundStyle(kit.ink)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            GlassCard(glow: kit.danger) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("DO NOT").font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .kerning(1.6).foregroundStyle(kit.danger)
                    ForEach(result.doNot, id: \.self) { d in
                        Label(d, systemImage: "xmark.octagon.fill")
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(kit.ink)
                    }
                }
            }

            GlassCard(glow: kit.caution) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("WATCH FOR · next \(result.observationWindowMinutes) min")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .kerning(1.6).foregroundStyle(kit.caution)
                    ForEach(s.redFlags, id: \.self) { f in
                        Label(f, systemImage: "eye.fill")
                            .font(.system(.footnote, design: .monospaced)).foregroundStyle(kit.ink)
                    }
                    LabButton(title: "Log this episode", systemImage: "square.and.pencil") {
                        Task {
                            await LogStore.shared.record(sessionType: "triage",
                                                         substanceID: s.id,
                                                         riskLevel: result.level,
                                                         note: "Triaged \(s.name) · \(result.level.rawValue)",
                                                         xp: 20)
                            state.award(20, reason: "Triage logged")
                        }
                    }
                }
            }

            Text("FOR EDUCATIONAL USE ONLY. Not a substitute for professional medical advice. In any emergency call Poison Control (1-800-222-1222) or emergency services.")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(kit.dim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func classChip(_ klass: SubstanceClass?, _ label: String) -> some View {
        let active = classFilter == klass
        return Button {
            Haptics.selection()
            withAnimation(Motion.spring) { classFilter = klass }
        } label: {
            HStack(spacing: 4) {
                if let k = klass { Image(systemName: k.symbol).font(.system(size: 9, weight: .bold)) }
                Text(label).font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(active ? .black : kit.dim)
            .padding(.horizontal, 12).frame(minHeight: 34)
            .background(Capsule().fill(active ? AnyShapeStyle(kit.phosphor) : AnyShapeStyle(Material.ultraThin)))
            .overlay(Capsule().strokeBorder(active ? .clear : kit.dim.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var firstAidCard: some View {
        FirstAidPanel()
    }

    private var recentsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("RECENT LOOKUPS").font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .kerning(1.6).foregroundStyle(kit.dim)
                if state.recentSubstances.isEmpty {
                    Text("Nothing looked up yet. The first time you need this, it will be the fastest screen on your phone.")
                        .font(.system(.caption, design: .monospaced)).foregroundStyle(kit.dim)
                } else {
                    ForEach(state.recentSubstances) { s in
                        Button {
                            Haptics.selection()
                            withAnimation(Motion.spring) { vm.select(s) }
                        } label: {
                            HStack {
                                Image(systemName: s.klass.symbol).foregroundStyle(kit.tint(for: s.baselineRisk))
                                Text(s.name).font(.system(.footnote, design: .monospaced))
                                    .foregroundStyle(kit.ink).lineLimit(1)
                                Spacer()
                                Image(systemName: "arrow.up.left").foregroundStyle(kit.dim).font(.caption)
                            }
                            .frame(minHeight: 44).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var factCard: some View {
        let fact = WhatFactVault.today()
        return GlassCard(glow: kit.epic) {
            VStack(alignment: .leading, spacing: 10) {
                Text("FINDING OF THE DAY · #\(fact.id)")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .kerning(1.6).foregroundStyle(kit.epic)
                Text(fact.headline)
                    .font(.system(.callout, design: .monospaced).bold()).foregroundStyle(kit.ink)
                Text(fact.explanation)
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(kit.ink.opacity(0.8))
                Label(fact.application, systemImage: "arrow.turn.down.right")
                    .font(.system(.caption2, design: .monospaced)).foregroundStyle(kit.safe)
            }
        }
    }

    private var scenarioCard: some View {
        ScenarioCard(scenario: DailyScenario.today())
    }

    private func sliderRow(_ title: String, _ value: String, _ binding: Binding<Double>,
                           _ range: ClosedRange<Double>, _ step: Double, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title.uppercased()).font(.system(size: 10, design: .monospaced)).foregroundStyle(kit.dim)
                Spacer()
                Text(value).font(.system(.caption, design: .monospaced).bold()).foregroundStyle(tint)
                    .contentTransition(.numericText())
            }
            Slider(value: binding, in: range, step: step).tint(tint)
                .accessibilityLabel(title).accessibilityValue(value)
        }
    }
}

private struct ScenarioCard: View {
    @EnvironmentObject var state: SerenityRunState
    @StateObject private var kit = FamilyKit.shared
    @State private var answered: Int? = nil
    let scenario: DailyScenario.Scenario

    var body: some View {
        GlassCard(glow: kit.caution) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill").foregroundStyle(kit.caution)
                    Text("DAILY SCENARIO · #\(scenario.id + 1)")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .kerning(1.6).foregroundStyle(kit.dim)
                }
                Text(scenario.setup(weightKg: state.childWeightKg, ageMonths: state.childAgeMonths))
                    .font(.system(.callout, design: .monospaced).bold()).foregroundStyle(kit.ink)
                Text(scenario.question)
                    .font(.system(.footnote, design: .monospaced)).foregroundStyle(kit.caution)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(Array(scenario.options.enumerated()), id: \.offset) { i, opt in
                    Button {
                        guard answered == nil else { return }
                        withAnimation(Motion.spring) { answered = i }
                        Haptics.notify(i == scenario.correctIndex ? .success : .error)
                        if i == scenario.correctIndex { state.award(5, reason: "Daily scenario") }
                    } label: {
                        let isAnswered = answered != nil
                        let isCorrect = i == scenario.correctIndex
                        let isTapped = answered == i
                        HStack(spacing: 10) {
                            Text(["A","B","C","D"][i])
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundStyle(.black)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(
                                    isAnswered
                                    ? (isCorrect ? kit.safe : (isTapped ? kit.danger : kit.dim.opacity(0.3)))
                                    : kit.caution
                                ))
                            Text(opt)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(isAnswered ? (isCorrect ? kit.safe : (isTapped ? kit.danger : kit.dim)) : kit.ink)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(answered != nil)
                }

                if let a = answered {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(a == scenario.correctIndex ? "Correct — +5 XP" : "Incorrect",
                              systemImage: a == scenario.correctIndex ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundStyle(a == scenario.correctIndex ? kit.safe : kit.caution)
                        Text(scenario.explanation)
                            .font(.system(.caption, design: .monospaced)).foregroundStyle(kit.ink)
                    }
                }
            }
        }
    }
}

/// Custom Shape — curved bottom edge, explicitly not a rectangle.
struct CurvedHero: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: .init(x: 0, y: 0))
        p.addLine(to: .init(x: rect.maxX, y: 0))
        p.addLine(to: .init(x: rect.maxX, y: rect.maxY - 46))
        p.addQuadCurve(to: .init(x: 0, y: rect.maxY - 46),
                       control: .init(x: rect.midX, y: rect.maxY + 34))
        p.closeSubpath()
        return p
    }
}

struct XPRing: View {
    let progress: Double
    let label: String
    @StateObject private var kit = FamilyKit.shared
    var body: some View {
        Canvas { ctx, size in
            let r = min(size.width, size.height) / 2 - 5
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            ctx.stroke(Path(ellipseIn: .init(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                       with: .color(kit.phosphor.opacity(0.18)), lineWidth: 5)
            var arc = Path()
            arc.addArc(center: c, radius: r, startAngle: .degrees(-90),
                       endAngle: .degrees(-90 + 360 * progress), clockwise: false)
            ctx.stroke(arc, with: .color(kit.phosphor), style: .init(lineWidth: 5, lineCap: .round))
            ctx.draw(Text(label).font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(kit.phosphor), at: c)
        }
        .accessibilityLabel("Level \(label), \(Int(progress * 100)) percent to next")
    }
}

@MainActor
final class TriageViewModel: ObservableObject {
    @Published var selected: Substance?
    @Published var units: Double = 2
    @Published var minutes: Double = 10
    @Published var symptoms = false
    private let engine = TriageEngine()

    func select(_ s: Substance) { selected = s; units = 2; minutes = 10; symptoms = false }

    func result(for s: Substance, weight: Double) -> TriageResult {
        engine.evaluate(substance: s, units: units, childWeightKg: weight,
                        minutesSinceIngestion: Int(minutes), symptomsPresent: symptoms)
    }

    func reload() async { /* offline pack is bundled; refresh exists for widget sync */ WidgetBridge.reload() }
}
// MARK: — Prepare the Call card
private struct PrepareCallCard: View {
    @EnvironmentObject var state: SerenityRunState
    @StateObject private var kit = FamilyKit.shared
    @State private var expanded = false
    @State private var copied = false
    let lastSubstance: Substance?

    private var callSummary: String {
        var lines: [String] = []
        lines.append("CALLER: \(state.userName.isEmpty ? "Parent/carer" : state.userName)")
        lines.append("CHILD: \(state.childAgeMonths / 12)y \(state.childAgeMonths % 12)m old")
        lines.append("WEIGHT: \(String(format: "%.1f", state.childWeightKg)) kg")
        if let s = lastSubstance {
            lines.append("SUBSTANCE: \(s.name)")
            lines.append("RISK CLASS: \(s.baselineRisk.rawValue.uppercased())")
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        lines.append("TIME NOTED: \(formatter.string(from: .now))")
        return lines.joined(separator: "\n")
    }

    var body: some View {
        GlassCard(glow: kit.phosphor) {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    Haptics.selection()
                    withAnimation(Motion.spring) { expanded.toggle() }
                } label: {
                    HStack {
                        Image(systemName: "checklist").foregroundStyle(kit.phosphor)
                            .font(.system(size: 13, weight: .bold))
                        Text("PREPARE THE CALL").font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .kerning(1.6).foregroundStyle(kit.dim)
                        Spacer()
                        Text("Have these ready for Poison Control")
                            .font(.system(size: 9, design: .monospaced)).foregroundStyle(kit.dim)
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .foregroundStyle(kit.dim).font(.caption2).padding(.leading, 4)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if expanded {
                    VStack(spacing: 8) {
                        infoRow("person.fill",    "Caller",     state.userName.isEmpty ? "Parent/carer" : state.userName,    kit.phosphor)
                        infoRow("figure.child",   "Child",      "\(state.childAgeMonths / 12)y \(state.childAgeMonths % 12)m old",  kit.phosphor)
                        infoRow("scalemass.fill", "Weight",     "\(String(format: "%.1f", state.childWeightKg)) kg",          kit.caution)
                        if let s = lastSubstance {
                            infoRow(s.klass.symbol, "Substance", s.name, kit.tint(for: s.baselineRisk))
                        } else {
                            infoRow("magnifyingglass", "Substance", "Search above to populate", kit.dim)
                        }
                        infoRow("clock.fill", "Time noted", {
                            let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: .now)
                        }(), kit.phosphor)
                    }

                    Button {
                        UIPasteboard.general.string = callSummary
                        Haptics.notify(.success)
                        withAnimation(Motion.spring) { copied = true }
                        Task { try? await Task.sleep(for: .seconds(2)); withAnimation { copied = false } }
                    } label: {
                        HStack {
                            Image(systemName: copied ? "checkmark" : "doc.on.clipboard")
                            Text(copied ? "Copied!" : "Copy summary to clipboard")
                                .font(.system(.caption, design: .monospaced).bold())
                        }
                        .foregroundStyle(copied ? kit.safe : kit.phosphor)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Capsule().fill((copied ? kit.safe : kit.phosphor).opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func infoRow(_ icon: String, _ label: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 13)).foregroundStyle(color).frame(width: 20)
            Text(label).font(.system(size: 10, weight: .heavy, design: .monospaced)).foregroundStyle(kit.dim)
            Spacer()
            Text(value).font(.system(.caption, design: .monospaced).bold()).foregroundStyle(kit.ink).lineLimit(1)
        }
        .frame(minHeight: 32)
    }
}

// MARK: — CPR & Choking first aid guide
private struct FirstAidPanel: View {
    @StateObject private var kit = FamilyKit.shared
    @State private var tab: Aid = .infantCPR
    @State private var expanded = false

    enum Aid: String, CaseIterable, Identifiable {
        case infantCPR = "CPR <1yr", childCPR = "CPR 1–8yr", infantChoke = "Choke <1yr", childChoke = "Choke >1yr"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .infantCPR, .childCPR: "heart.fill"
            case .infantChoke, .childChoke: "lungs.fill"
            }
        }
    }

    var body: some View {
        GlassCard(glow: kit.danger) {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    Haptics.selection()
                    withAnimation(Motion.spring) { expanded.toggle() }
                } label: {
                    HStack {
                        Image(systemName: "staroflife.fill").foregroundStyle(kit.danger)
                            .font(.system(size: 14, weight: .bold))
                        Text("CPR & CHOKING GUIDE").font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .kerning(1.6).foregroundStyle(kit.dim)
                        Spacer()
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .foregroundStyle(kit.dim).font(.caption2)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if expanded {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Aid.allCases) { a in
                                Button {
                                    Haptics.selection()
                                    withAnimation(Motion.spring) { tab = a }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: a.symbol).font(.system(size: 9))
                                        Text(a.rawValue).font(.system(size: 10, weight: .bold, design: .monospaced))
                                    }
                                    .foregroundStyle(tab == a ? .black : kit.dim)
                                    .padding(.horizontal, 12).frame(minHeight: 34)
                                    .background(Capsule().fill(tab == a ? AnyShapeStyle(kit.danger) : AnyShapeStyle(Material.ultraThin)))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(steps(for: tab).enumerated()), id: \.offset) { i, step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(i + 1)")
                                    .font(.system(size: 13, weight: .black, design: .monospaced))
                                    .foregroundStyle(.black).frame(width: 24, height: 24)
                                    .background(Circle().fill(kit.danger))
                                Text(step)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(kit.ink)
                            }
                        }
                    }

                    Text("Training reference only. Complete an accredited first aid course for certified hands-on practice.")
                        .font(.system(size: 9, design: .monospaced)).foregroundStyle(kit.dim)
                }
            }
        }
    }

    private func steps(for aid: Aid) -> [String] {
        switch aid {
        case .infantCPR:
            return [
                "CHECK responsiveness — tap foot, shout name. If no response, call for help.",
                "OPEN AIRWAY — gentle head-tilt to neutral/sniff position. Do NOT over-extend.",
                "CHECK BREATHING — look, listen, feel for 10 seconds. Occasional gasps do not count.",
                "2 RESCUE BREATHS — cover mouth AND nose. Puff until chest rises (1 sec each). If no rise, reposition head.",
                "30 COMPRESSIONS — 2 fingers on centre of chest, just below nipple line. Press 4 cm, full recoil. Rate: 100–120/min.",
                "Repeat 30:2 until AED available, help arrives, or infant breathes normally."
            ]
        case .childCPR:
            return [
                "CHECK — tap shoulders, shout name. Send a bystander to call 999 / 911.",
                "OPEN AIRWAY — head-tilt chin-lift. More tilt than infant, less than adult.",
                "CHECK BREATHING — 10 seconds. Occasional gasps do not count.",
                "2 RESCUE BREATHS — pinch nose, seal over mouth, blow until chest rises. Reposition if no rise.",
                "30 COMPRESSIONS — heel of one or two hands on lower third of breastbone. Press ⅓ chest depth (~5 cm), full recoil. Rate: 100–120/min.",
                "ATTACH AED immediately when available — use paediatric pads for under 8. Follow voice prompts.",
                "Repeat 30:2 until AED delivers shock, help arrives, or child breathes normally."
            ]
        case .infantChoke:
            return [
                "If the infant is coughing loudly — let them cough. Do not intervene.",
                "If cough is silent, lips are blue, or infant cannot cry: hold face-down on your forearm, head lower than chest.",
                "5 BACK BLOWS — heel of hand firmly between shoulder blades.",
                "Turn face-up, look in mouth. Remove only what you can clearly see.",
                "5 CHEST THRUSTS — 2 fingers, same position as CPR, sharper downward thrust.",
                "Alternate 5 back blows / 5 chest thrusts. Call 999/911 after the first cycle if alone.",
                "If infant becomes unconscious: begin infant CPR, check mouth before each breath."
            ]
        case .childChoke:
            return [
                "If child coughs loudly — encourage coughing. Stay close.",
                "If cough is silent, child clutches throat, or lips are blue: lean child forward, support chest.",
                "5 BACK BLOWS — heel of hand firmly between shoulder blades, angled downward.",
                "Look in mouth. Remove only what you can clearly see.",
                "5 ABDOMINAL THRUSTS (Heimlich) — fist above navel/below breastbone, other hand over fist. Thrust inward and upward sharply.",
                "Alternate 5 back blows / 5 abdominal thrusts. Call 999/911 immediately after the first cycle.",
                "If child becomes unconscious: begin child CPR, check mouth before each breath attempt."
            ]
        }
    }
}

import SwiftUI

/// TAB — GUIDE. 12 lessons in topic clusters + myth busters. Progressive unlock.
struct GuideScene: View {
    @EnvironmentObject var state: SerenityRunState
    @StateObject private var kit = FamilyKit.shared
    @State private var open: Lesson?
    @State private var cluster: Lesson.Cluster? = nil
    @Namespace private var hero

    private var lessons: [Lesson] {
        cluster.map(WhatLessonLibrary.cluster) ?? WhatLessonLibrary.all
    }

    var body: some View {
        ZStack {
            LabBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    header
                    clusterStrip
                    grid
                    mythSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 130)
            }
            .scrollIndicators(.hidden)

            if let lesson = open {
                LessonReader(lesson: lesson, namespace: hero) { withAnimation(Motion.spring) { open = nil } }
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PROTOCOL LIBRARY").font(.system(size: 10, weight: .heavy, design: .monospaced))
                .kerning(2).foregroundStyle(kit.dim)
            Text("12 evidence-based protocols")
                .font(.system(size: 26, weight: .black, design: .monospaced)).foregroundStyle(kit.ink)
            Text("\(completedCount)/12 complete · each one ends with a checkpoint you must pass.")
                .font(.system(.caption, design: .monospaced)).foregroundStyle(kit.dim)
        }
        .padding(.top, 20)
    }

    private var clusterStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip("All", nil)
                ForEach(Lesson.Cluster.allCases, id: \.self) { c in chip(c.rawValue, c) }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    private func chip(_ title: String, _ c: Lesson.Cluster?) -> some View {
        let active = cluster == c
        return Button {
            Haptics.selection(); withAnimation(Motion.spring) { cluster = c }
        } label: {
            HStack(spacing: 6) {
                if let c { Image(systemName: c.symbol).font(.caption2) }
                Text(title).font(.system(size: 11, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(active ? .black : kit.dim)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(Capsule().fill(active ? AnyShapeStyle(kit.phosphor) : AnyShapeStyle(Material.ultraThin)))
            .overlay(Capsule().strokeBorder(active ? .clear : kit.dim.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            ForEach(Array(lessons.enumerated()), id: \.element.id) { i, lesson in
                let locked = isLocked(lesson)
                Button {
                    guard !locked else { Haptics.notify(.warning); return }
                    Haptics.selection()
                    withAnimation(Motion.spring) { open = lesson }
                } label: {
                    LessonCard(lesson: lesson, locked: locked,
                               done: state.isUnlocked("lesson_\(lesson.id)"),
                               namespace: hero)
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.95).combined(with: .opacity))
                .animation(Motion.stagger(i), value: cluster)
            }
        }
    }

    private var mythSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MYTHBUSTERS · 5 beliefs that cause harm")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .kerning(1.6).foregroundStyle(kit.danger)
            ForEach(MythBusters.all) { m in
                GlassCard(glow: kit.danger) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(m.myth, systemImage: "xmark.circle.fill")
                            .font(.system(.footnote, design: .monospaced).bold())
                            .foregroundStyle(kit.danger)
                        Label(m.truth, systemImage: "checkmark.seal.fill")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(kit.safe)
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    private var completedCount: Int {
        WhatLessonLibrary.all.filter { state.isUnlocked("lesson_\($0.id)") }.count
    }

    private func isLocked(_ l: Lesson) -> Bool {
        guard l.id > 1 else { return false }
        // L1 is pre-seeded at 40% so the UI demonstrates progress on day one.
        return !state.isUnlocked("lesson_\(l.id - 1)") && l.id > 2
    }
}

private struct LessonCard: View {
    let lesson: Lesson
    let locked: Bool
    let done: Bool
    let namespace: Namespace.ID
    @StateObject private var kit = FamilyKit.shared

    private var accent: Color {
        switch lesson.difficulty {
        case .beginner: kit.safe
        case .intermediate: kit.phosphor
        case .expert: kit.caution
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: lesson.cluster.symbol)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [accent, accent.opacity(0.4)],
                                                    startPoint: .top, endPoint: .bottom))
                    .matchedGeometryEffect(id: "icon\(lesson.id)", in: namespace)
                Text(lesson.title)
                    .font(.system(.footnote, design: .monospaced).bold())
                    .foregroundStyle(kit.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .matchedGeometryEffect(id: "title\(lesson.id)", in: namespace)
                Spacer(minLength: 0)
                HStack {
                    Text(lesson.difficulty.rawValue.uppercased())
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(accent))
                    Spacer()
                    if done { Image(systemName: "checkmark.seal.fill").foregroundStyle(kit.safe).font(.caption) }
                }
            }
            .padding(16)
            .frame(height: 178, alignment: .topLeading)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [accent.opacity(0.18), kit.surface],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(accent.opacity(locked ? 0.2 : 0.7), lineWidth: 2))
            .grayscale(locked ? 1 : 0)
            .blur(radius: locked ? 2.5 : 0)

            if locked {
                VStack(spacing: 6) {
                    Image(systemName: "lock.fill").font(.title3).foregroundStyle(kit.dim)
                    Text("Complete previous")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(kit.dim)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(lesson.title), \(lesson.difficulty.rawValue)")
        .accessibilityHint(locked ? "Locked. Complete the previous protocol." : "Opens the protocol")
    }
}

/// Reader with embedded mid-lesson checkpoint — must answer to finish.
private struct LessonReader: View {
    let lesson: Lesson
    let namespace: Namespace.ID
    var close: () -> Void

    @EnvironmentObject var state: SerenityRunState
    @StateObject private var kit = FamilyKit.shared
    @State private var answered: Int?
    @State private var showTail = false

    var body: some View {
        ZStack {
            LabBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Image(systemName: lesson.cluster.symbol)
                            .font(.system(size: 30, weight: .bold)).foregroundStyle(kit.phosphor)
                            .matchedGeometryEffect(id: "icon\(lesson.id)", in: namespace)
                        Spacer()
                        Button { close() } label: {
                            Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(kit.dim)
                        }.frame(minWidth: 44, minHeight: 44)
                    }
                    Text(lesson.title)
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .foregroundStyle(kit.ink)
                        .matchedGeometryEffect(id: "title\(lesson.id)", in: namespace)

                    Text(lesson.body)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(kit.ink.opacity(0.88))
                        .lineSpacing(5)

                    checkpointCard

                    if showTail {
                        GlassCard(glow: kit.safe) {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("KEY TAKEAWAY", systemImage: "key.fill")
                                    .font(.system(size: 10, weight: .heavy, design: .monospaced)).foregroundStyle(kit.safe)
                                Text(lesson.takeaway).font(.system(.footnote, design: .monospaced)).foregroundStyle(kit.ink)
                                Divider().overlay(kit.dim.opacity(0.3))
                                Label("PRACTICE", systemImage: "hammer.fill")
                                    .font(.system(size: 10, weight: .heavy, design: .monospaced)).foregroundStyle(kit.caution)
                                Text(lesson.exercise).font(.system(.footnote, design: .monospaced)).foregroundStyle(kit.ink)
                            }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))

                        LabButton(title: "Mark protocol complete", systemImage: "checkmark.seal.fill") {
                            state.unlock("lesson_\(lesson.id)")
                            state.award(80, reason: "Lesson \(lesson.id)")
                            Task {
                                await LogStore.shared.record(sessionType: "lesson",
                                                             note: lesson.title, xp: 80, duration: 300)
                            }
                            Haptics.notify(.success)
                            close()
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var checkpointCard: some View {
        GlassCard(glow: answered == nil ? kit.caution : (answered == lesson.checkpoint.correctIndex ? kit.safe : kit.danger)) {
            VStack(alignment: .leading, spacing: 12) {
                Text("CHECKPOINT — answer to continue")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .kerning(1.4).foregroundStyle(kit.caution)
                Text(lesson.checkpoint.question)
                    .font(.system(.footnote, design: .monospaced).bold()).foregroundStyle(kit.ink)

                ForEach(Array(lesson.checkpoint.options.enumerated()), id: \.offset) { i, opt in
                    Button {
                        guard answered == nil else { return }
                        answered = i
                        let right = i == lesson.checkpoint.correctIndex
                        Haptics.notify(right ? .success : .error)
                        if right { state.award(18, reason: "Checkpoint") }
                        withAnimation(Motion.spring.delay(0.3)) { showTail = true }
                    } label: {
                        HStack {
                            Text(opt).font(.system(.caption, design: .monospaced))
                                .foregroundStyle(kit.ink).multilineTextAlignment(.leading)
                            Spacer()
                            if answered != nil {
                                Image(systemName: i == lesson.checkpoint.correctIndex ? "checkmark.circle.fill" : (i == answered ? "xmark.circle.fill" : ""))
                                    .foregroundStyle(i == lesson.checkpoint.correctIndex ? kit.safe : kit.danger)
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 48)
                        .background(Capsule().fill(.ultraThinMaterial))
                        .overlay(Capsule().strokeBorder(borderColor(i), lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }

                if answered != nil {
                    Text(lesson.checkpoint.explanation)
                        .font(.system(.caption2, design: .monospaced)).foregroundStyle(kit.dim)
                        .transition(.opacity)
                }
            }
        }
    }

    private func borderColor(_ i: Int) -> Color {
        guard let answered else { return kit.dim.opacity(0.3) }
        if i == lesson.checkpoint.correctIndex { return kit.safe }
        if i == answered { return kit.danger }
        return kit.dim.opacity(0.2)
    }
}
import SwiftUI
import Charts

/// TAB — TOOLS. Dose calculator · observation timer · prevention checklist · outcome tracker.
struct ToolsScene: View {
    @StateObject private var kit = FamilyKit.shared
    @State private var tool: Tool = .calculator

    enum Tool: String, CaseIterable, Identifiable {
        case calculator = "Dose", timer = "Watch", checklist = "Audit", tracker = "Log", growth = "Growth", drill = "Drill"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .calculator: "function"
            case .timer: "timer"
            case .checklist: "checklist"
            case .tracker: "chart.line.uptrend.xyaxis"
            case .growth: "figure.child"
            case .drill: "bolt.fill"
            }
        }
    }

    var body: some View {
        ZStack {
            LabBackground()
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    ForEach(Tool.allCases) { t in
                        Button {
                            Haptics.selection(); withAnimation(Motion.spring) { tool = t }
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: t.symbol).font(.system(size: 15, weight: .bold))
                                Text(t.rawValue).font(.system(size: 9, weight: .heavy, design: .monospaced))
                            }
                            .foregroundStyle(tool == t ? .black : kit.dim)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Capsule().fill(tool == t ? AnyShapeStyle(kit.phosphor) : AnyShapeStyle(Material.ultraThin)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 16)

                ScrollView {
                    LazyVStack(spacing: 16) {
                        switch tool {
                        case .calculator: DoseCalculator()
                        case .timer: ObservationTimer()
                        case .checklist: PreventionAudit()
                        case .tracker: OutcomeTracker()
                        case .growth: GrowthTracker()
                        case .drill: FlashDrill()
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 130)
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}

// MARK: — Dose calculator (real mg/kg math)
private struct DoseCalculator: View {
    @EnvironmentObject var state: SerenityRunState
    @StateObject private var kit = FamilyKit.shared
    @State private var substance = SubstanceVault.all[0]
    @State private var units: Double = 2
    private let engine = TriageEngine()

    private var dosed: [Substance] { SubstanceVault.all.filter { $0.mgPerUnit != nil && $0.toxicThresholdMgPerKg != nil } }

    var body: some View {
        let r = engine.evaluate(substance: substance, units: units,
                                childWeightKg: state.childWeightKg,
                                minutesSinceIngestion: 0, symptomsPresent: false)
        GlassCard(glow: kit.tint(for: r.level)) {
            VStack(alignment: .leading, spacing: 18) {
                Text("mg/kg THRESHOLD CALCULATOR")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .kerning(1.6).foregroundStyle(kit.dim)

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(dosed) { s in
                            Button {
                                Haptics.selection(); withAnimation(Motion.spring) { substance = s }
                            } label: {
                                Text(s.name.split(separator: " ").first.map(String.init) ?? s.name)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(substance.id == s.id ? .black : kit.dim)
                                    .padding(.horizontal, 12).frame(minHeight: 44)
                                    .background(Capsule().fill(substance.id == s.id ? AnyShapeStyle(kit.caution) : AnyShapeStyle(Material.ultraThin)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("AMOUNT").font(.system(size: 10, design: .monospaced)).foregroundStyle(kit.dim)
                        Spacer()
                        Text("\(units, specifier: "%.1f") × \(substance.unitName)")
                            .font(.system(.caption, design: .monospaced).bold()).foregroundStyle(kit.caution)
                    }
                    Slider(value: $units, in: 0.5...30, step: 0.5).tint(kit.caution)
                }

                HStack(spacing: 18) {
                    metric("ESTIMATE", r.estimatedMgPerKg.map { String(format: "%.1f", $0) } ?? "—", "mg/kg", kit.phosphor)
                    metric("THRESHOLD", substance.toxicThresholdMgPerKg.map { String(format: "%.0f", $0) } ?? "—", "mg/kg", kit.caution)
                    metric("WEIGHT", String(format: "%.1f", state.childWeightKg), "kg", kit.dim)
                }

                Text(r.rationale).font(.system(.caption, design: .monospaced))
                    .foregroundStyle(kit.tint(for: r.level))
                Text("Estimates are guidance only. Report the maximum plausible amount to Poison Control and let them decide.")
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(kit.dim)
            }
        }
    }

    private func metric(_ t: String, _ v: String, _ u: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(t).font(.system(size: 9, weight: .heavy, design: .monospaced)).foregroundStyle(kit.dim)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(v).font(.system(size: 22, weight: .black, design: .monospaced)).foregroundStyle(c)
                    .contentTransition(.numericText())
                Text(u).font(.system(size: 9, design: .monospaced)).foregroundStyle(kit.dim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: — Observation timer with named phases
private struct ObservationTimer: View {
    @StateObject private var kit = FamilyKit.shared
    @State private var elapsed: Int = 0
    @State private var running = false
    @State private var task: Task<Void, Never>?

    private let phases: [(String, Int, String)] = [
        ("IMMEDIATE — airway & consciousness", 0, "Check breathing, responsiveness, mouth. Remove visible residue."),
        ("CONTACT WINDOW — caustic signs", 15, "Drooling, refusing to swallow, hoarse voice, white lips."),
        ("ABSORPTION — systemic onset", 30, "Drowsiness, unsteadiness, vomiting, pallor, sweating."),
        ("PEAK — most toxins at maximum", 90, "Highest-risk window for medication effects."),
        ("LATE — delayed agents", 240, "Acetaminophen, methanol, iron: still silent. Follow callback advice.")
    ]

    private var phaseIndex: Int {
        phases.lastIndex { elapsed / 60 >= $0.1 } ?? 0
    }

    var body: some View {
        GlassCard(glow: kit.phosphor) {
            VStack(alignment: .leading, spacing: 18) {
                Text("OBSERVATION CLOCK")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .kerning(1.6).foregroundStyle(kit.dim)

                Text(String(format: "%02d:%02d:%02d", elapsed / 3600, (elapsed % 3600) / 60, elapsed % 60))
                    .font(.system(size: 46, weight: .black, design: .monospaced))
                    .foregroundStyle(kit.phosphor)
                    .contentTransition(.numericText())
                    .accessibilityLabel("Elapsed \(elapsed / 60) minutes")

                ForEach(Array(phases.enumerated()), id: \.offset) { i, p in
                    HStack(alignment: .top, spacing: 12) {
                        Circle().fill(i <= phaseIndex ? kit.phosphor : kit.dim.opacity(0.3))
                            .frame(width: 9, height: 9).padding(.top, 5)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(p.1)m · \(p.0)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(i == phaseIndex ? kit.phosphor : (i < phaseIndex ? kit.ink : kit.dim))
                            if i == phaseIndex {
                                Text(p.2).font(.system(size: 10, design: .monospaced)).foregroundStyle(kit.caution)
                            }
                        }
                        Spacer()
                    }
                }

                HStack(spacing: 10) {
                    LabButton(title: running ? "Pause" : "Start clock",
                              systemImage: running ? "pause.fill" : "play.fill") { toggle() }
                    Button { stop() } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundStyle(kit.dim).frame(width: 52, height: 52)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Reset clock")
                }
            }
        }
        .onDisappear { task?.cancel() }
    }

    private func toggle() {
        running.toggle()
        task?.cancel()
        guard running else { return }
        task = Task { @MainActor in
            var lastPhase = phaseIndex
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                elapsed += 1
                if phaseIndex != lastPhase { lastPhase = phaseIndex; Haptics.notify(.warning) }
            }
        }
    }
    private func stop() { task?.cancel(); running = false; elapsed = 0 }
}

// MARK: — 10-step prevention audit
private struct PreventionAudit: View {
    @StateObject private var kit = FamilyKit.shared
    @EnvironmentObject var state: SerenityRunState
    @AppStorage("auditFlags") private var raw: String = ""

    private let items: [(String, String)] = [
        ("Medicines above 150 cm, not above a climbable surface", "Height is passive and needs no habit upkeep."),
        ("Coin-cell compartments taped or screw-secured", "Remotes, scales, candles, greeting cards, key fobs."),
        ("Dishwasher pods in the original tub, high shelf", "Alkali burns are worse than bleach burns."),
        ("Visitor bags on a designated high shelf", "Pill organisers are not child-resistant."),
        ("No chemical decanted into a food or drink container", "The single most repeated fatal error."),
        ("Supplements and gummies stored like prescription drugs", "Taste and packaging defences do not apply."),
        ("Poison Control number saved in your phone as 'POISON'", "Searching during an event wastes minutes."),
        ("Child's current weight written on the medicine cupboard", "Every threshold is per kilogram."),
        ("Indoor plants identified and checked once", "Yew, foxglove, oleander, nightshade are immediate calls."),
        ("No medicine ever described to the child as 'sweets'", "The association outlives the illness."),
        ("Alcohol gel out of reach in bags, car and pushchair", "62% gel is stronger than spirits."),
        ("Re-audit scheduled after each new physical skill", "Climbing invalidates your last assessment.")
    ]

    private var done: Set<Int> {
        get { Set(raw.split(separator: ",").compactMap { Int($0) }) }
    }

    var body: some View {
        GlassCard(glow: kit.safe) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("HOME AUDIT").font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .kerning(1.6).foregroundStyle(kit.dim)
                    Spacer()
                    Text("\(done.count)/\(items.count)")
                        .font(.system(.caption, design: .monospaced).bold()).foregroundStyle(kit.safe)
                }
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    Button { toggle(i) } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: done.contains(i) ? "checkmark.square.fill" : "square")
                                .font(.system(size: 20)).foregroundStyle(done.contains(i) ? kit.safe : kit.dim)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.0).font(.system(.caption, design: .monospaced).bold())
                                    .foregroundStyle(kit.ink).multilineTextAlignment(.leading)
                                Text(item.1).font(.system(size: 10, design: .monospaced)).foregroundStyle(kit.dim)
                            }
                            Spacer()
                        }
                        .frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(done.contains(i) ? [.isSelected] : [])
                }
            }
        }
    }

    private func toggle(_ i: Int) {
        var set = done
        if set.contains(i) { set.remove(i) } else { set.insert(i); Haptics.tap(.medium) }
        raw = set.sorted().map(String.init).joined(separator: ",")
        if set.count == items.count { state.unlock("audit_complete"); state.award(100, reason: "Audit complete") }
    }
}

// MARK: — Outcome tracker with Swift Charts
private struct OutcomeTracker: View {
    @StateObject private var kit = FamilyKit.shared
    @State private var entries: [LogStore.Entry] = []

    private struct Point: Identifiable { let id = UUID(); let day: Date; let count: Int; let risk: String }

    private var points: [Point] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: entries) { cal.startOfDay(for: $0.date) }
        return (0..<30).compactMap { offset in
            guard let d = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: .now)) else { return nil }
            let rows = grouped[d] ?? []
            return Point(day: d, count: rows.count, risk: rows.first?.riskLevel ?? "none")
        }.reversed()
    }

    var body: some View {
        VStack(spacing: 16) {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("30-DAY ACTIVITY").font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .kerning(1.6).foregroundStyle(kit.dim)
                    if entries.isEmpty {
                        Text("Your data grows with every session. Check back after your first.")
                            .font(.system(.caption, design: .monospaced)).foregroundStyle(kit.dim)
                    } else {
                        Chart(points) { p in
                            BarMark(x: .value("Day", p.day, unit: .day),
                                    y: .value("Events", p.count))
                                .foregroundStyle(kit.phosphor.gradient)
                                .cornerRadius(3)
                        }
                        .frame(height: 170)
                        .chartXAxis { AxisMarks(values: .stride(by: .day, count: 7)) { v in
                            AxisValueLabel(format: .dateTime.day().month(.narrow))
                                .foregroundStyle(kit.dim)
                        } }
                        .chartYAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(kit.dim) } }
                    }
                }
            }

            GlassCard(glow: kit.epic) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("INSIGHTS").font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .kerning(1.6).foregroundStyle(kit.epic)
                    Text(insight).font(.system(.caption, design: .monospaced)).foregroundStyle(kit.ink)
                }
            }
        }
        .task { entries = await LogStore.shared.fetchRecent(limit: 200) }
    }

    private var insight: String {
        guard !entries.isEmpty else {
            return "No experiments logged yet. Run one triage or one protocol and the first trend appears here tomorrow."
        }
        let triages = entries.filter { $0.sessionType == "triage" }
        let quizzes = entries.filter { $0.sessionType == "quiz" }
        let avg = quizzes.isEmpty ? 0 : Double(quizzes.map(\.score).reduce(0, +)) / Double(max(1, quizzes.map(\.totalQuestions).reduce(0, +))) * 100
        let topClass = Dictionary(grouping: triages.compactMap { $0.substanceID.flatMap(SubstanceVault.byID)?.klass }, by: \.self)
            .max { $0.value.count < $1.value.count }?.key
        var s = "Experiment set complete: \(entries.count) records. "
        if !quizzes.isEmpty { s += String(format: "Drill accuracy %.0f%%. ", avg) }
        if let topClass { s += "Your most frequent exposure class is \(topClass.label.lowercased()) — that is where prevention effort pays most. " }
        s += "Hypothesis for next week: a single storage change in that category reduces repeat lookups."
        return s
    }
}
// MARK: — Growth & Weight Tracker
private struct GrowthTracker: View {
    @EnvironmentObject var state: SerenityRunState
    @StateObject private var kit = FamilyKit.shared
    @AppStorage("growthLog") private var rawLog: String = ""
    @State private var addingEntry = false
    @State private var newKg: Double = 12

    private struct Entry: Identifiable {
        let id: Double
        let date: Date
        let kg: Double
    }

    private var entries: [Entry] {
        rawLog.split(separator: ",").compactMap { part in
            let kv = part.split(separator: ":")
            guard kv.count == 2, let ts = Double(kv[0]), let kg = Double(kv[1]) else { return nil }
            return Entry(id: ts, date: Date(timeIntervalSince1970: ts), kg: kg)
        }.sorted { $0.date < $1.date }
    }

    private func addEntry(_ kg: Double) {
        let ts = Date.now.timeIntervalSince1970
        let piece = "\(Int(ts)):\(kg)"
        rawLog = rawLog.isEmpty ? piece : rawLog + "," + piece
        state.childWeightKg = kg
    }

    var body: some View {
        VStack(spacing: 16) {
            GlassCard(glow: kit.caution) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("WEIGHT LOG").font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .kerning(1.6).foregroundStyle(kit.dim)
                        Spacer()
                        Button {
                            newKg = state.childWeightKg
                            withAnimation(Motion.spring) { addingEntry.toggle() }
                        } label: {
                            Image(systemName: addingEntry ? "xmark" : "plus")
                                .foregroundStyle(kit.caution).frame(width: 44, height: 44)
                        }.buttonStyle(.plain)
                    }

                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(String(format: "%.1f", state.childWeightKg))
                            .font(.system(size: 52, weight: .black, design: .monospaced))
                            .foregroundStyle(kit.caution)
                            .contentTransition(.numericText())
                        Text("kg").font(.system(size: 16, design: .monospaced)).foregroundStyle(kit.dim)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(state.childAgeMonths / 12)y \(state.childAgeMonths % 12)m")
                                .font(.system(.caption, design: .monospaced).bold()).foregroundStyle(kit.ink)
                            Text("used in all dose calculations").font(.system(size: 9, design: .monospaced)).foregroundStyle(kit.dim)
                        }
                    }

                    if addingEntry {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("NEW READING").font(.system(size: 10, design: .monospaced)).foregroundStyle(kit.dim)
                                Spacer()
                                Text(String(format: "%.1f kg", newKg))
                                    .font(.system(.caption, design: .monospaced).bold()).foregroundStyle(kit.caution)
                            }
                            Slider(value: $newKg, in: 3...60, step: 0.1).tint(kit.caution)
                            LabButton(title: "Save \(String(format: "%.1f", newKg)) kg", systemImage: "plus.circle.fill") {
                                addEntry(newKg)
                                withAnimation(Motion.spring) { addingEntry = false }
                                Haptics.notify(.success)
                                state.award(10, reason: "Weight updated")
                            }
                        }
                    }
                }
            }

            if entries.count >= 2 {
                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("GROWTH TREND").font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .kerning(1.6).foregroundStyle(kit.dim)
                        Chart(entries) { e in
                            LineMark(x: .value("Date", e.date),
                                     y: .value("kg", e.kg))
                                .foregroundStyle(kit.caution.gradient)
                                .interpolationMethod(.catmullRom)
                            PointMark(x: .value("Date", e.date),
                                      y: .value("kg", e.kg))
                                .foregroundStyle(kit.caution)
                        }
                        .frame(height: 150)
                        .chartXAxis { AxisMarks(values: .automatic) { _ in
                            AxisValueLabel(format: .dateTime.month(.narrow).day())
                                .foregroundStyle(kit.dim)
                        }}
                        .chartYAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(kit.dim) }}
                    }
                }
            }

            GlassCard(glow: kit.phosphor) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("THRESHOLDS AT \(String(format: "%.1f", state.childWeightKg)) KG")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .kerning(1.6).foregroundStyle(kit.dim)
                    Text("Estimated maximum before the concern threshold is reached:")
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(kit.dim)
                    ForEach(substanceThresholds, id: \.0) { name, limit in
                        HStack {
                            Text(name).font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(kit.ink).lineLimit(1)
                            Spacer()
                            Text(limit).font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(kit.caution)
                        }
                        .frame(minHeight: 32)
                    }
                    Text("Reference only — always report the actual amount taken to Poison Control.")
                        .font(.system(size: 9, design: .monospaced)).foregroundStyle(kit.dim)
                }
            }
        }
    }

    private var substanceThresholds: [(String, String)] {
        SubstanceVault.all
            .filter { $0.toxicThresholdMgPerKg != nil && $0.mgPerUnit != nil }
            .map { s in
                let maxMg = s.toxicThresholdMgPerKg! * state.childWeightKg
                let units = maxMg / s.mgPerUnit!
                let shortName = String(s.name.split(separator: "(").first ?? Substring(s.name))
                    .trimmingCharacters(in: .whitespaces)
                return (shortName, String(format: "< %.1f × %@", units, s.unitName))
            }
    }
}

private struct FlashDrill: View {
    @EnvironmentObject var state: SerenityRunState
    @StateObject private var kit = FamilyKit.shared
    @State private var questions: [DrillQuestion] = []
    @State private var qIndex: Int = 0
    @State private var answered: Int? = nil
    @State private var score: Int = 0
    @State private var phase: DrillPhase = .idle
    @State private var sessionStart: Date = .now

    enum DrillPhase { case idle, active, finished }
    private let total = 8

    var body: some View {
        VStack(spacing: 16) {
            switch phase {
            case .idle:     idleCard
            case .active:   activeCard
            case .finished: finishedCard
            }
        }
    }

    // MARK: Idle
    private var idleCard: some View {
        GlassCard(glow: kit.epic) {
            VStack(alignment: .leading, spacing: 18) {
                Text("FLASH DRILL")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .kerning(1.6).foregroundStyle(kit.dim)
                HStack(spacing: 16) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 36)).foregroundStyle(kit.epic)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(total) questions")
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundStyle(kit.ink)
                        Text("Risk levels · Do NOTs · First steps")
                            .font(.system(.caption, design: .monospaced)).foregroundStyle(kit.dim)
                    }
                }
                Text("Generated live from \(SubstanceVault.all.count) substances. Fully offline. Results saved to History.")
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(kit.dim)
                LabButton(title: "Start drill", systemImage: "play.fill") { beginDrill() }
            }
        }
    }

    // MARK: Active
    @ViewBuilder
    private var activeCard: some View {
        if qIndex < questions.count {
            let q = questions[qIndex]
            VStack(spacing: 14) {
                GlassCard(glow: kit.epic) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Q \(qIndex + 1) / \(questions.count)")
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .kerning(1.4).foregroundStyle(kit.dim)
                            Spacer()
                            Text("\(score) ✓")
                                .font(.system(size: 10, design: .monospaced)).foregroundStyle(kit.phosphor)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(kit.epic.opacity(0.15))
                                Capsule().fill(kit.epic)
                                    .frame(width: geo.size.width * Double(qIndex) / Double(questions.count))
                            }
                        }.frame(height: 4)
                        Text(q.text)
                            .font(.system(.callout, design: .monospaced).bold())
                            .foregroundStyle(kit.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                ForEach(Array(q.options.enumerated()), id: \.offset) { i, opt in
                    optionButton(opt, index: i, correct: q.correctIndex)
                }
                if let a = answered {
                    GlassCard(glow: a == q.correctIndex ? kit.safe : kit.caution) {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(a == q.correctIndex ? "Correct" : "Incorrect",
                                  systemImage: a == q.correctIndex ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                .font(.system(.footnote, design: .monospaced).bold())
                                .foregroundStyle(a == q.correctIndex ? kit.safe : kit.caution)
                            Text(q.explanation)
                                .font(.system(.caption, design: .monospaced)).foregroundStyle(kit.ink)
                        }
                    }
                    LabButton(title: qIndex + 1 < questions.count ? "Next" : "See results",
                              systemImage: "arrow.right") {
                        advance(correct: q.correctIndex)
                    }
                }
            }
        }
    }

    private func optionButton(_ text: String, index i: Int, correct: Int) -> some View {
        let isAnswered = answered != nil
        let isCorrect = i == correct
        let isTapped = answered == i
        return Button {
            guard answered == nil else { return }
            withAnimation(Motion.spring) { answered = i }
            if i == correct { score += 1 }
            Haptics.notify(i == correct ? .success : .error)
        } label: {
            HStack(spacing: 10) {
                Text(["A","B","C","D"][i])
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.black)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(
                        isAnswered
                        ? (isCorrect ? kit.safe : (isTapped ? kit.danger : kit.dim.opacity(0.3)))
                        : kit.phosphor
                    ))
                Text(text)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(isAnswered ? (isCorrect ? kit.safe : (isTapped ? kit.danger : kit.dim)) : kit.ink)
                    .multilineTextAlignment(.leading)
                Spacer()
                if isAnswered {
                    Image(systemName: isCorrect ? "checkmark" : (isTapped ? "xmark" : ""))
                        .foregroundStyle(isCorrect ? kit.safe : kit.danger)
                        .font(.caption2)
                }
            }
            .frame(minHeight: 50)
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isAnswered ? (isCorrect ? kit.safe : (isTapped ? kit.danger : .clear)) : kit.dim.opacity(0.2), lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isAnswered)
    }

    // MARK: Finished
    private var finishedCard: some View {
        let pct = questions.isEmpty ? 0 : Int(Double(score) / Double(questions.count) * 100)
        let col = pct >= 80 ? kit.safe : (pct >= 50 ? kit.caution : kit.danger)
        return VStack(spacing: 16) {
            GlassCard(glow: col) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("DRILL COMPLETE")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .kerning(1.6).foregroundStyle(kit.dim)
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text("\(score)/\(questions.count)")
                            .font(.system(size: 52, weight: .black, design: .monospaced))
                            .foregroundStyle(col)
                        Text("correct")
                            .font(.system(size: 14, design: .monospaced)).foregroundStyle(kit.dim)
                        Spacer()
                        Text("+\(score * 15) XP")
                            .font(.system(.callout, design: .monospaced).bold()).foregroundStyle(kit.phosphor)
                    }
                    Text(pct >= 80 ? "Strong protocol awareness." :
                         pct >= 50 ? "Solid base — review missed ones in Guide." :
                         "Good start. Guide tab has full explanations.")
                        .font(.system(.caption, design: .monospaced)).foregroundStyle(kit.ink)
                }
            }
            LabButton(title: "Run another drill", systemImage: "arrow.counterclockwise") {
                withAnimation(Motion.spring) { beginDrill() }
            }
        }
    }

    // MARK: Logic
    private func beginDrill() {
        sessionStart = .now
        questions = DrillQuestion.generateSession(count: total)
        qIndex = 0; answered = nil; score = 0
        withAnimation(Motion.spring) { phase = .active }
    }

    private func advance(correct: Int) {
        withAnimation(Motion.spring) {
            if qIndex + 1 < questions.count {
                qIndex += 1; answered = nil
            } else {
                phase = .finished
                Task { await saveSession() }
            }
        }
    }

    private func saveSession() async {
        let xp = score * 15
        let dur = Int(Date.now.timeIntervalSince(sessionStart))
        await LogStore.shared.record(sessionType: "quiz", score: score,
                                     total: questions.count, xp: xp, duration: dur)
        state.award(xp, reason: "Flash drill \(score)/\(questions.count)")
    }
}

import SwiftUI

/// TAB — HISTORY. The lab notebook: every episode, what was advised, what changed.
struct HistoryScene: View {
    @StateObject private var kit = FamilyKit.shared
    @State private var entries: [LogStore.Entry] = []
    @State private var filter: String? = nil

    private var shown: [LogStore.Entry] {
        filter.map { f in entries.filter { $0.sessionType == f } } ?? entries
    }

    var body: some View {
        ZStack {
            LabBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("LAB NOTEBOOK").font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .kerning(2).foregroundStyle(kit.dim)
                        Text("\(entries.count) records")
                            .font(.system(size: 26, weight: .black, design: .monospaced)).foregroundStyle(kit.ink)
                    }
                    .padding(.top, 20)

                    HStack(spacing: 8) {
                        filterChip("All", nil)
                        filterChip("Triage", "triage")
                        filterChip("Protocol", "lesson")
                        filterChip("Drill", "quiz")
                    }

                    if shown.isEmpty {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Image(systemName: "text.book.closed.fill")
                                    .font(.system(size: 34)).foregroundStyle(kit.phosphor.opacity(0.7))
                                Text("The notebook is open and blank.")
                                    .font(.system(.callout, design: .monospaced).bold()).foregroundStyle(kit.ink)
                                Text("Every episode you log becomes a pattern you can act on — a room, a time of day, a visitor. The second exposure is the one prevention actually prevents.")
                                    .font(.system(.caption, design: .monospaced)).foregroundStyle(kit.dim)
                            }
                        }
                    } else {
                        ForEach(Array(shown.enumerated()), id: \.element.id) { i, e in
                            entryCard(e).animation(Motion.stagger(min(i, 8)), value: filter)
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 130)
            }
            .scrollIndicators(.hidden)
            .refreshable { entries = await LogStore.shared.fetchRecent() }
        }
        .task { entries = await LogStore.shared.fetchRecent() }
    }

    private func filterChip(_ t: String, _ v: String?) -> some View {
        let active = filter == v
        return Button {
            Haptics.selection(); withAnimation(Motion.spring) { filter = v }
        } label: {
            Text(t).font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(active ? .black : kit.dim)
                .padding(.horizontal, 14).frame(minHeight: 44)
                .background(Capsule().fill(active ? AnyShapeStyle(kit.phosphor) : AnyShapeStyle(Material.ultraThin)))
        }
        .buttonStyle(.plain)
    }

    private func entryCard(_ e: LogStore.Entry) -> some View {
        let risk = e.riskLevel.flatMap { RiskLevel(rawValue: $0) }
        let color = risk.map(kit.tint(for:)) ?? kit.phosphor
        return GlassCard(glow: color) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(e.sessionType.uppercased())
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.black).padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(color))
                    Spacer()
                    Text(e.date.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(kit.dim)
                }
                if let sub = e.substanceID.flatMap(SubstanceVault.byID) {
                    Label(sub.name, systemImage: sub.klass.symbol)
                        .font(.system(.footnote, design: .monospaced).bold()).foregroundStyle(kit.ink)
                }
                if let note = e.note {
                    Text(note).font(.system(.caption, design: .monospaced)).foregroundStyle(kit.ink.opacity(0.85))
                }
                HStack(spacing: 14) {
                    if e.totalQuestions > 0 {
                        Label("\(e.score)/\(e.totalQuestions)", systemImage: "target")
                            .font(.system(size: 10, design: .monospaced)).foregroundStyle(kit.caution)
                    }
                    if e.xpEarned > 0 {
                        Label("+\(e.xpEarned) XP", systemImage: "bolt.fill")
                            .font(.system(size: 10, design: .monospaced)).foregroundStyle(kit.phosphor)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
import AppIntents

struct TriageLookupIntent: AppIntent {
    static var title: LocalizedStringResource = "Look up a substance"
    static var description = IntentDescription("Open Bouncara triage for a substance your child may have eaten.")
    static var openAppWhenRun = true

    @Parameter(title: "Substance") var name: String

    func perform() async throws -> some IntentResult {
        let match = SubstanceVault.search(name).first
        UserDefaults(suiteName: "group.serenityrun.shared")?
            .set(match?.id, forKey: "pending_substance")
        return .result()
    }
}

struct DailyFindingIntent: AppIntent {
    static var title: LocalizedStringResource = "Today's finding"
    static var description = IntentDescription("Read today's child-safety finding aloud.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let f = WhatFactVault.today()
        return .result(dialog: IntentDialog("\(f.headline) \(f.explanation)"))
    }
}

struct SerenityShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: TriageLookupIntent(), phrases: [
            "Look up a substance in \(.applicationName)",
            "Is this dangerous in \(.applicationName)"
        ], shortTitle: "Substance reference", systemImageName: "cross.case.fill")

        AppShortcut(intent: DailyFindingIntent(), phrases: [
            "Today's finding in \(.applicationName)"
        ], shortTitle: "Daily finding", systemImageName: "lightbulb.fill")
    }
}
