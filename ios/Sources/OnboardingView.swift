import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 첫 실행: Mac 일기장이 쓰는 iCloud Drive 폴더를 연결한다.
struct OnboardingView: View {
    @EnvironmentObject private var store: MobileStore
    @State private var showPicker = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: "leaf.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.accent)

            Text("Simple Diary")
                .font(.largeTitle.bold())

            Text("Mac의 Simple Diary와 같은 iCloud 폴더를 연결하면\n일기가 그대로 동기화됩니다.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                Label("아래 버튼을 누르면 파일 선택기가 열려요", systemImage: "1.circle")
                Label("iCloud Drive → Simple Diary 폴더를 선택하세요", systemImage: "2.circle")
                Label("폴더가 없다면 Mac에서 일기장을 먼저 실행", systemImage: "exclamationmark.circle")
            }
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
            .padding(.top, 8)

            if let error = store.setupError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                showPicker = true
            } label: {
                Text("iCloud 폴더 연결하기")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 10)

            Spacer()
        }
        .padding(28)
        .sheet(isPresented: $showPicker) {
            FolderPicker { url in
                store.adoptFolder(url)
            }
        }
    }
}

/// 폴더 선택용 UIDocumentPicker 래퍼
struct FolderPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                onPick(url)
            }
        }
    }
}
