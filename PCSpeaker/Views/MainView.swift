import SwiftUI

/// Main Dashboard View matching App Store PC Speaker layout
public struct MainView: View {
    @StateObject private var service = AudioReceiverService.shared
    
    @State private var showQRScanner: Bool = false
    @State private var showManualIP: Bool = false
    @State private var showHistory: Bool = false
    @State private var showHelp: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(red: 0.97, green: 0.98, blue: 0.99)
                    .edgesIgnoringSafeArea(.all)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Top Header: Logo + App Name + Help Button
                        HStack(alignment: .center, spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(AppTheme.primaryLight)
                                    .frame(width: 48, height: 48)
                                
                                Image(systemName: "speaker.wave.3.fill")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(AppTheme.primary)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("PC Speaker")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Text("Play PC audio on your iPhone")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button {
                                showHelp = true
                            } label: {
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 22))
                                    .foregroundColor(.secondary)
                                    .padding(8)
                            }
                        }
                        .padding(.top, 8)
                        
                        // Status & Diagnostics Dashboard Card
                        StatusHeaderCard(service: service)
                        
                        // Action Buttons: Auto Connect, QR Scan, Manual IP, History, Disconnect
                        ActionButtonsView(
                            service: service,
                            showQRScanner: $showQRScanner,
                            showManualIP: $showManualIP,
                            showHistory: $showHistory
                        )
                        
                        // Collapsible Diagnostics & Fine-Tuning Card
                        DetailsAccordionView(service: service)
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showQRScanner) {
            QRScannerView { scannedUrl in
                service.connect(url: scannedUrl, pcName: "PC Sender")
            }
        }
        .sheet(isPresented: $showManualIP) {
            ManualIPSheet { ip, pcName in
                service.connect(url: ip, pcName: pcName)
            }
        }
        .sheet(isPresented: $showHistory) {
            HistorySheet { wsUrl, pcName in
                service.connect(url: wsUrl, pcName: pcName)
            }
        }
        .sheet(isPresented: $showHelp) {
            HelpGuideSheet()
        }
    }
}
