import SwiftUI
import PhotosUI
import Speech

struct ChatView: View {
    @EnvironmentObject var chat: ChatStore
    @State private var photo: PhotosPickerItem?
    @State private var showSettings = false
    @State private var listening = false
    @State private var recognizer = SpeechRecognizer()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red:0.055,green:0.065,blue:0.09).ignoresSafeArea()
                VStack(spacing:0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing:14) {
                                ForEach(chat.messages) { msg in
                                    HStack {
                                        if msg.role == "assistant" {
                                            Image(systemName:"sparkles").foregroundStyle(.cyan).padding(.top,4)
                                            bubble(msg.text, assistant:true)
                                            Spacer(minLength:28)
                                        } else {
                                            Spacer(minLength:28)
                                            bubble(msg.text, assistant:false)
                                        }
                                    }.id(msg.id)
                                }
                                if chat.isBusy { HStack { ProgressView().tint(.cyan); Text("Qwentex is thinking…").foregroundStyle(.secondary); Spacer() }.padding() }
                            }.padding()
                        }.onChange(of:chat.messages.count) { _,_ in
                            if let id=chat.messages.last?.id { withAnimation { proxy.scrollTo(id,anchor:.bottom) } }
                        }
                    }
                    composer
                }
            }
            .navigationTitle("Qwentex")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.topBarLeading) { Image(systemName:"sparkles").foregroundStyle(.cyan) }
                ToolbarItem(placement:.topBarTrailing) { Button { showSettings=true } label:{Image(systemName:"slider.horizontal.3")} }
            }
            .sheet(isPresented:$showSettings) { settings }
        }
        .onChange(of:photo) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type:Data.self) {
                    chat.send(imageData:data)
                }
                photo=nil
            }
        }
    }

    func bubble(_ text:String,assistant:Bool)->some View {
        Text(text).textSelection(.enabled).padding(14)
            .background(assistant ? Color.white.opacity(0.07) : Color.cyan.opacity(0.20))
            .clipShape(RoundedRectangle(cornerRadius:18))
            .foregroundStyle(.white)
    }

    var composer: some View {
        HStack(alignment:.bottom,spacing:10) {
            PhotosPicker(selection:$photo,matching:.images) {
                Image(systemName:"photo").font(.system(size:20)).foregroundStyle(.cyan).frame(width:40,height:44)
            }
            Button {
                if listening { recognizer.stop(); listening=false }
                else {
                    recognizer.start { result in chat.draft = result }
                    listening=true
                }
            } label: {
                Image(systemName:listening ? "stop.circle.fill":"mic.fill").font(.system(size:19))
                    .foregroundStyle(listening ? .red : .cyan).frame(width:34,height:44)
            }
            TextField("Message Qwentex…",text:$chat.draft,axis:.vertical)
                .lineLimit(1...5).padding(12).background(Color.white.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius:16))
            Button { chat.send() } label {
                Image(systemName:"arrow.up").font(.bold).foregroundStyle(.black).frame(width:42,height:42)
                    .background(Color.cyan).clipShape(Circle())
            }.disabled(chat.draft.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || chat.isBusy)
        }.padding(.horizontal,12).padding(.vertical,10).background(.ultraThinMaterial)
    }

    var settings: some View {
        NavigationStack {
            Form {
                Section("Ollama / OpenAI-compatible API") {
                    TextField("Base URL",text:$chat.endpoint).textInputAutocapitalization(.never).keyboardType(.URL)
                    TextField("Model",text:$chat.model).textInputAutocapitalization(.never)
                    SecureField("API key",text:$chat.apiKey)
                    Text("Example: http://192.168.1.10:11434/v1 — use your PC's LAN IP, not localhost.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Button("Save settings") { chat.saveSettings(); showSettings=false }
            }.navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.topBarTrailing){Button("Close"){showSettings=false}} }
        }
    }
}

final class SpeechRecognizer: ObservableObject {
    private let engine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func start(onText:@escaping(String)->Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else { return }
            AVAudioApplication.requestRecordPermission { granted in
                guard granted else { return }
                DispatchQueue.main.async {
                    do {
                        self.request = SFSpeechAudioBufferRecognitionRequest()
                        guard let request=self.request else{return}
                        request.shouldReportPartialResults=true
                        let input=self.engine.inputNode
                        input.installTap(onBus:0,bufferSize:1024,format:input.outputFormat(forBus:0)){buffer,_ in request.append(buffer)}
                        self.engine.prepare()
                        try self.engine.start()
                        self.task=self.recognizer?.recognitionTask(with:request){result,error in
                            if let result { DispatchQueue.main.async { onText(result.bestTranscription.formattedString) } }
                        }
                    } catch { self.stop() }
                }
            }
        }
    }
    func stop() {
        engine.stop(); engine.inputNode.removeTap(onBus:0); request?.endAudio(); task?.cancel()
        request=nil;task=nil
    }
}
