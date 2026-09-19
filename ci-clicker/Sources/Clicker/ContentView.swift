import SwiftUI

/// Clicker minimo: se toca el boton para sumar puntos y el toggle "Auto"
/// hace que el juego se juegue solo (10 puntos/segundo) hasta apagarlo.
/// Todos los elementos tienen etiqueta de accesibilidad para poder conducirlo
/// desde CI con idb.
struct ContentView: View {
    @State private var puntos = 0
    @State private var auto = false
    @State private var pulso = false

    var body: some View {
        VStack(spacing: 18) {
            Text("Puntos: \(puntos)")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .monospacedDigit()
                .accessibilityIdentifier("puntos")

            Button {
                sumar(1)
            } label: {
                ZStack {
                    Circle()
                        .fill(.tint.opacity(0.22))
                        .frame(width: 190, height: 190)
                        .scaleEffect(pulso ? 1.12 : 1.0)
                    Text("TAP")
                        .font(.system(size: 62, weight: .black, design: .rounded))
                }
            }
            .accessibilityLabel("TAP")

            Toggle("Auto (juega solo)", isOn: $auto)
                .padding(.horizontal, 40)
                .accessibilityLabel("auto-toggle")

            Text(auto ? "Auto: encendido" : "Auto: apagado")
                .font(.headline)
                .foregroundStyle(auto ? .green : .secondary)
        }
        .padding()
        // Se re-lanza al cambiar 'auto'; al apagarlo la tarea se cancela.
        .task(id: auto) {
            guard auto else { return }
            while auto {
                try? await Task.sleep(for: .milliseconds(100))
                if Task.isCancelled { return }
                sumar(1)
            }
        }
    }

    private func sumar(_ n: Int) {
        puntos += n
        withAnimation(.easeOut(duration: 0.09)) { pulso.toggle() }
    }
}
