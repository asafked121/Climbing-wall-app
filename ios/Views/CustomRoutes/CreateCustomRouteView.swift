import SwiftUI

struct CreateCustomRouteView: View {
    @StateObject private var viewModel = CreateCustomRouteViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showingImagePicker = false
    @State private var inputImage: UIImage?
    
    @State private var name = ""
    @State private var intendedGrade = "V0"
    let grades = ["V0", "V1", "V2", "V3", "V4", "V5", "V6", "V7", "V8", "V9", "V10"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                if viewModel.detectedHolds.isEmpty {
                    // Step 1: Upload
                    VStack {
                        if let image = inputImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 300)
                                .cornerRadius(12)
                            
                            Button(action: {
                                viewModel.detectHolds(image: image)
                            }) {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Detect Holds (OpenCV)")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .disabled(viewModel.isLoading)
                        } else {
                            Button(action: {
                                showingImagePicker = true
                            }) {
                                VStack(spacing: 12) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 40))
                                    Text("Tap to select wall photo")
                                }
                                .frame(maxWidth: .infinity, minHeight: 200)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5]))
                                )
                            }
                        }
                    }
                    .padding()
                } else {
                    // Step 2: Pick Holds & Details
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Tap detected holds to include them")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        GeometryReader { geometry in
                            if let image = inputImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .overlay(
                                        Canvas { context, size in
                                            let scaleX = size.width / image.size.width
                                            let scaleY = size.height / image.size.height
                                            
                                            for hold in viewModel.detectedHolds {
                                                let cx = CGFloat(hold.x) * scaleX
                                                let cy = CGFloat(hold.y) * scaleY
                                                let r = max(CGFloat(hold.radius) * max(scaleX, scaleY), 10)
                                                
                                                let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                                                let path = Path(ellipseIn: rect)
                                                
                                                if viewModel.selectedHoldIds.contains(hold.id) {
                                                    context.fill(path, with: .color(Color.green.opacity(0.4)))
                                                    context.stroke(path, with: .color(Color.green), lineWidth: 3)
                                                } else {
                                                    context.stroke(path, with: .color(Color.white.opacity(0.6)), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                                                }
                                            }
                                        }
                                        .gesture(
                                            DragGesture(minimumDistance: 0).onEnded { value in
                                                let clickX = value.location.x
                                                let clickY = value.location.y
                                                
                                                let imageWidth = image.size.width
                                                let imageHeight = image.size.height
                                                
                                                // Assuming image is aspect fit within geometry
                                                // For exact mapping, we need image's drawn rect
                                                // This is a simplified hit test assuming GeometryReader bounds match image bounds
                                                
                                                let scaleX = geometry.size.width / imageWidth
                                                let scaleY = geometry.size.height / imageHeight
                                                
                                                for hold in viewModel.detectedHolds.reversed() {
                                                    let cx = CGFloat(hold.x) * scaleX
                                                    let cy = CGFloat(hold.y) * scaleY
                                                    let r = max(CGFloat(hold.radius) * max(scaleX, scaleY), 15)
                                                    
                                                    let dist = sqrt(pow(clickX - cx, 2) + pow(clickY - cy, 2))
                                                    if dist <= r {
                                                        if viewModel.selectedHoldIds.contains(hold.id) {
                                                            viewModel.selectedHoldIds.remove(hold.id)
                                                        } else {
                                                            viewModel.selectedHoldIds.insert(hold.id)
                                                        }
                                                        break
                                                    }
                                                }
                                            }
                                        )
                                    )
                            }
                        }
                        .aspectRatio(inputImage.map { $0.size.width / $0.size.height } ?? 1, contentMode: .fit)
                        .cornerRadius(12)
                        
                        TextField("Route Name", text: $name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Picker("Intended Grade", selection: $intendedGrade) {
                            ForEach(grades, id: \.self) {
                                Text($0)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding(.vertical, 8)
                        
                        Button(action: {
                            viewModel.createRoute(name: name, intendedGrade: intendedGrade) { success in
                                if success {
                                    presentationMode.wrappedValue.dismiss()
                                }
                            }
                        }) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Post Route")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(name.isEmpty || viewModel.isLoading)
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("New Custom Route")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $inputImage)
        }
    }
}

// Minimal ImagePicker for SwiftUI
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            picker.dismiss(animated: true)
        }
    }
}
