import SwiftUI

/// App de prueba con UI interactiva: cada elemento cambia de estado visible
/// para que las capturas tomadas tras cada accion demuestren la interaccion.
struct ContentView: View {
    @State private var taps = 0
    @State private var nombre = ""
    @State private var activo = false
    @State private var volumen = 0.5

    var body: some View {
        VStack(spacing: 22) {
            Text("Contador: \(taps)")
                .font(.largeTitle)
                .bold()
                .accessibilityIdentifier("contador")

            Button("Sumar uno") { taps += 1 }
                .buttonStyle(.borderedProminent)

            TextField("Escribe tu nombre", text: $nombre)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 30)
                // Etiqueta e identificador explicitos: el prompt de un TextField va a
                // AXValue, no a AXLabel, y sin AXLabel idb no puede enfocarlo ni fijarle
                // valor por accesibilidad (el tipeo HID no llega si no hay foco).
                .accessibilityLabel("campo-nombre")
                .accessibilityIdentifier("campo-nombre")

            Text("Hola, \(nombre.isEmpty ? "desconocido" : nombre)")
                .font(.title3)

            Toggle("Activo", isOn: $activo)
                .padding(.horizontal, 60)

            Slider(value: $volumen)
                .padding(.horizontal, 30)

            Text(activo ? "Estado: ACTIVO" : "Estado: inactivo")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
