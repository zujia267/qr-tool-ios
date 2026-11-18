import SwiftUI
import Photos

struct ContentView: View {
    @State private var pastedText = ""
    @State private var results: [DocumentResult] = []
    @State private var collages: [UUID: UIImage] = [:]
    @State private var showPicker = false
    @State private var showSettings = false
    @State private var keySet = KeychainHelper.loadKey() != nil
    @State private var alertMessage: String?
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill((keySet ? Color.green : Color.red).opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: keySet ? "key.fill" : "key.slash")
                                .foregroundColor(keySet ? .green : .red)
                        }
                        Text(keySet ? "密钥已保存" : "未设置密钥，先去设置里输入密钥")
                            .font(.headline)
                        Spacer()
                        Button("设置") { showSettings = true }
                    }
                    .padding(.vertical, 4)
                }
                Section("粘贴密文（每行一条）") {
                    TextEditor(text: $pastedText)
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                        .background(Color.white)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                } footer: {
                    Text("解密全部在手机本地完成，不联网。")
                }
                Section {
                    Button("选择文件（可多选 .txt）") { showPicker = true }
                    Button(isWorking ? "正在处理…" : "解密并生成二维码") { processPasted() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .disabled(!keySet || isWorking)
                    if !results.isEmpty {
                        Button("清空结果", role: .destructive) {
                            results = []
                            collages = [:]
                        }
                    }
                }
                if !results.isEmpty {
                    Section("结果（每个文档一张合集图）") {
                        ForEach(results) { result in
                            NavigationLink(destination: DetailView(result: result, collage: collages[result.id])) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.blue.opacity(0.12))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: "qrcode")
                                            .foregroundColor(.blue)
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(result.name).font(.headline)
                                        Text("\(result.urls.count) 条链接" + (result.failedLines > 0 ? "，\(result.failedLines) 行解密失败" : ""))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("扫码助手")
            .sheet(isPresented: $showPicker) {
                DocumentPicker { urls in processFiles(urls) }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(keySet: $keySet)
            }
            .alert("提示", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
                Button("好", role: .cancel) { alertMessage = nil }
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    private func processPasted() {
        guard let key = KeychainHelper.loadKey() else { alertMessage = "请先设置密钥"; return }
        let text = pastedText
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertMessage = "请先粘贴密文，或选择文件"
            return
        }
        isWorking = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Processor.process(name: "粘贴内容", text: text, key: key)
            let image = QRCodeTools.collageImage(urls: result.urls)
            DispatchQueue.main.async {
                self.results.append(result)
                if let image = image { self.collages[result.id] = image }
                self.isWorking = false
            }
        }
    }

    private func processFiles(_ urls: [URL]) {
        guard let key = KeychainHelper.loadKey() else { alertMessage = "请先设置密钥"; return }
        isWorking = true
        DispatchQueue.global(qos: .userInitiated).async {
            var newResults: [DocumentResult] = []
            var newCollages: [UUID: UIImage] = [:]
            for url in urls {
                let name = url.deletingPathExtension().lastPathComponent
                guard let text = TextFileReader.read(url: url) else { continue }
                let result = Processor.process(name: name, text: text, key: key)
                newResults.append(result)
                if let image = QRCodeTools.collageImage(urls: result.urls) {
                    newCollages[result.id] = image
                }
            }
            DispatchQueue.main.async {
                self.results.append(contentsOf: newResults)
                for (id, image) in newCollages { self.collages[id] = image }
                self.isWorking = false
            }
        }
    }
}

struct DetailView: View {
    let result: DocumentResult
    let collage: UIImage?
    @State private var showShare = false
    @State private var statusMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let image = collage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 2)
                        .padding(.horizontal)
                } else {
                    Text("没有可生成的二维码").foregroundColor(.secondary)
                }
                Text("\(result.name)：\(result.urls.count) 条链接，共 \(result.totalLines) 行" + (result.failedLines > 0 ? "，\(result.failedLines) 行解密失败" : ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                HStack(spacing: 12) {
                    Button("保存到相册") { saveToPhotos() }
                        .disabled(collage == nil)
                    Button("分享") { showShare = true }
                        .disabled(collage == nil)
                    Button("复制链接") {
                        UIPasteboard.general.string = result.urls.joined(separator: "\n")
                        statusMessage = "链接已复制"
                    }
                }
                .buttonStyle(.borderedProminent)
                if let msg = statusMessage {
                    Text(msg).font(.subheadline).foregroundColor(.green)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(result.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShare) {
            if let image = collage { ShareSheet(items: [image]) }
        }
    }

    private func saveToPhotos() {
        guard let image = collage else { return }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { statusMessage = "没有相册权限，请在设置里允许" }
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, _ in
                DispatchQueue.main.async { statusMessage = success ? "已保存到相册" : "保存失败" }
            }
        }
    }
}

struct SettingsView: View {
    @Binding var keySet: Bool
    @State private var keyInput = ""
    @State private var message: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("AES 密钥（16 位）")) {
                    SecureField("输入密钥", text: $keyInput)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    Button("保存密钥") {
                        let trimmed = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmed.utf8.count == 16 else {
                            message = "密钥必须是 16 位字符"
                            return
                        }
                        if KeychainHelper.saveKey(trimmed) {
                            keySet = true
                            message = "已保存到本机钥匙串"
                            keyInput = ""
                        } else {
                            message = "保存失败，请重试"
                        }
                    }
                    Button("清除已保存的密钥", role: .destructive) {
                        KeychainHelper.deleteKey()
                        keySet = false
                        message = "已清除"
                    }
                }
                Section {
                    Text("密钥只保存在本机钥匙串里，不会上传到任何服务器。解密全部在手机本地完成。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    if let msg = message {
                        Text(msg).font(.footnote).foregroundColor(.green)
                    }
                }
                Section {
                    Text("扫码助手 v1.0.0")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
