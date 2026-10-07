//
//  HSBQRCodeScannerViewController.swift
//  HSBWatchCompanion
//
//  专为 Apple TV 配对打造的原生二维码扫描控制器。
//  集成 AVCaptureSession 高性能扫码、动态取景框、手电筒照明与全流程安全握手反馈。
//

import UIKit
import AVFoundation

@objc public protocol HSBQRCodeScannerDelegate: AnyObject {
    func qrCodeScanner(_ scanner: HSBQRCodeScannerViewController, didScanPairingURL url: URL)
    func qrCodeScannerDidCancel(_ scanner: HSBQRCodeScannerViewController)
}

@objc public final class HSBQRCodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    @objc public weak var delegate: HSBQRCodeScannerDelegate?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isProcessingCode = false
    
    // UI 元素
    private let scanAreaView = UIView()
    private let maskLayer = CAShapeLayer()
    private let lineView = UIView()
    private let promptLabel = UILabel()
    private let tipCardView = UIView()
    private let torchButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private var scanLineTimer: CADisplayLink?
    private var scanLineDirection: CGFloat = 1.0
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        setupCamera()
        setupOverlayUI()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isProcessingCode = false
        startSession()
        startScanAnimation()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
        stopScanAnimation()
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        updateMaskOverlay()
    }
    
    // MARK: - Camera Setup
    
    private func setupCamera() {
        guard let captureDevice = AVCaptureDevice.default(for: .video) else {
            showCameraError(message: "当前设备未检测到可用摄像头。")
            return
        }
        
        let session = AVCaptureSession()
        session.sessionPreset = .high
        
        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                showCameraError(message: "无法初始化摄像头输入流。")
                return
            }
        } catch {
            showCameraError(message: "摄像头访问受限，请在系统设置中允许使用相机。")
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            showCameraError(message: "无法配置二维码识别输出。")
            return
        }
        
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        
        self.captureSession = session
        self.previewLayer = preview
    }
    
    private func startSession() {
        guard let session = captureSession, !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    private func stopSession() {
        guard let session = captureSession, session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            session.stopRunning()
        }
    }
    
    // MARK: - UI Configuration
    
    private func setupOverlayUI() {
        // 1. 取景框
        scanAreaView.translatesAutoresizingMaskIntoConstraints = false
        scanAreaView.layer.borderColor = UIColor(red: 0.98, green: 0.42, blue: 0.22, alpha: 1.0).cgColor // 糖葫芦品牌橙色
        scanAreaView.layer.borderWidth = 2.5
        scanAreaView.layer.cornerRadius = 20
        scanAreaView.clipsToBounds = true
        view.addSubview(scanAreaView)
        
        // 2. 扫描动画线条
        lineView.translatesAutoresizingMaskIntoConstraints = false
        lineView.backgroundColor = UIColor(red: 0.98, green: 0.42, blue: 0.22, alpha: 0.85)
        lineView.layer.shadowColor = UIColor(red: 0.98, green: 0.42, blue: 0.22, alpha: 1.0).cgColor
        lineView.layer.shadowRadius = 8
        lineView.layer.shadowOpacity = 0.9
        scanAreaView.addSubview(lineView)
        
        // 3. 顶部关闭按钮
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = UIColor.white.withAlphaComponent(0.8)
        closeButton.contentVerticalAlignment = .fill
        closeButton.contentHorizontalAlignment = .fill
        closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        view.addSubview(closeButton)
        
        // 4. 手电筒按钮
        torchButton.translatesAutoresizingMaskIntoConstraints = false
        torchButton.setImage(UIImage(systemName: "bolt.circle.fill"), for: .normal)
        torchButton.tintColor = UIColor.white.withAlphaComponent(0.8)
        torchButton.contentVerticalAlignment = .fill
        torchButton.contentHorizontalAlignment = .fill
        torchButton.addTarget(self, action: #selector(toggleTorch), for: .touchUpInside)
        view.addSubview(torchButton)
        
        // 5. 提示说明卡片
        tipCardView.translatesAutoresizingMaskIntoConstraints = false
        tipCardView.backgroundColor = UIColor(white: 0.12, alpha: 0.75)
        tipCardView.layer.cornerRadius = 16
        tipCardView.layer.borderWidth = 1
        tipCardView.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        view.addSubview(tipCardView)
        
        promptLabel.translatesAutoresizingMaskIntoConstraints = false
        promptLabel.text = "对准 Apple TV 屏幕上的【遥控配对】二维码\n即可在 0.5 秒内自动建立双向安全加密连接"
        promptLabel.font = .systemFont(ofSize: 15, weight: .medium)
        promptLabel.textColor = .white
        promptLabel.textAlignment = .center
        promptLabel.numberOfLines = 0
        tipCardView.addSubview(promptLabel)
        
        NSLayoutConstraint.activate([
            scanAreaView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanAreaView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50),
            scanAreaView.widthAnchor.constraint(equalToConstant: 260),
            scanAreaView.heightAnchor.constraint(equalToConstant: 260),
            
            lineView.leadingAnchor.constraint(equalTo: scanAreaView.leadingAnchor),
            lineView.trailingAnchor.constraint(equalTo: scanAreaView.trailingAnchor),
            lineView.topAnchor.constraint(equalTo: scanAreaView.topAnchor),
            lineView.heightAnchor.constraint(equalToConstant: 2.5),
            
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            closeButton.widthAnchor.constraint(equalToConstant: 36),
            closeButton.heightAnchor.constraint(equalToConstant: 36),
            
            torchButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            torchButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            torchButton.widthAnchor.constraint(equalToConstant: 36),
            torchButton.heightAnchor.constraint(equalToConstant: 36),
            
            tipCardView.topAnchor.constraint(equalTo: scanAreaView.bottomAnchor, constant: 36),
            tipCardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            tipCardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            promptLabel.topAnchor.constraint(equalTo: tipCardView.topAnchor, constant: 14),
            promptLabel.bottomAnchor.constraint(equalTo: tipCardView.bottomAnchor, constant: -14),
            promptLabel.leadingAnchor.constraint(equalTo: tipCardView.leadingAnchor, constant: 16),
            promptLabel.trailingAnchor.constraint(equalTo: tipCardView.trailingAnchor, constant: -16)
        ])
    }
    
    private func updateMaskOverlay() {
        let path = UIBezierPath(rect: view.bounds)
        let scanRect = scanAreaView.frame
        let scanPath = UIBezierPath(roundedRect: scanRect, cornerRadius: 20)
        path.append(scanPath)
        path.usesEvenOddFillRule = true
        
        maskLayer.path = path.cgPath
        maskLayer.fillRule = .evenOdd
        maskLayer.fillColor = UIColor.black.withAlphaComponent(0.6).cgColor
        
        if maskLayer.superlayer == nil {
            view.layer.insertSublayer(maskLayer, above: previewLayer)
        }
    }
    
    // MARK: - Animation
    
    private func startScanAnimation() {
        scanLineTimer?.invalidate()
        let displayLink = CADisplayLink(target: self, selector: #selector(updateScanLine))
        displayLink.add(to: .main, forMode: .common)
        self.scanLineTimer = displayLink
    }
    
    private func stopScanAnimation() {
        scanLineTimer?.invalidate()
        scanLineTimer = nil
    }
    
    @objc private func updateScanLine() {
        let maxTravel = scanAreaView.bounds.height - 3
        var currentY = lineView.frame.origin.y
        currentY += scanLineDirection * 2.0
        
        if currentY >= maxTravel {
            currentY = maxTravel
            scanLineDirection = -1.0
        } else if currentY <= 0 {
            currentY = 0
            scanLineDirection = 1.0
        }
        
        lineView.frame.origin.y = currentY
    }
    
    // MARK: - Actions
    
    @objc private func handleClose() {
        delegate?.qrCodeScannerDidCancel(self)
        dismiss(animated: true)
    }
    
    @objc private func toggleTorch() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = (device.torchMode == .on) ? .off : .on
            device.unlockForConfiguration()
            let isOn = device.torchMode == .on
            torchButton.tintColor = isOn ? .systemYellow : UIColor.white.withAlphaComponent(0.8)
        } catch {
            print("Torch error: \(error)")
        }
    }
    
    // MARK: - AVCaptureMetadataOutputObjectsDelegate
    
    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !isProcessingCode,
              let metadataObj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              metadataObj.type == .qr,
              let stringValue = metadataObj.stringValue else {
            return
        }
        
        guard let url = URL(string: stringValue),
              url.scheme?.lowercased() == "hsbremote",
              url.host?.lowercased() == "pair" else {
            // 非合法糖葫芦配对码，震动提示一次但保持继续扫描
            return
        }
        
        isProcessingCode = true
        stopSession()
        stopScanAnimation()
        
        // 成功音效/振动
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
        
        promptLabel.text = "✅ 识别成功！正在安全建立连接..."
        promptLabel.textColor = .systemGreen
        
        delegate?.qrCodeScanner(self, didScanPairingURL: url)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self = self else { return }
            self.dismiss(animated: true)
        }
    }
    
    private func showCameraError(message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let alert = UIAlertController(title: "手动配对 / 相机未就绪",
                                          message: "\(message)\n您可以直接粘贴配对链接或输入配对码完成连接：",
                                          preferredStyle: .alert)
            alert.addTextField { textField in
                textField.placeholder = "粘贴 hsbremote://pair?... 链接"
                textField.clearButtonMode = .whileEditing
                if let pasteboard = UIPasteboard.general.string, pasteboard.contains("hsbremote://pair") {
                    textField.text = pasteboard
                }
            }
            alert.addAction(UIAlertAction(title: "确认连接", style: .default, handler: { [weak self, weak alert] _ in
                guard let self = self,
                      let text = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                      let url = URL(string: text),
                      url.scheme?.lowercased() == "hsbremote",
                      url.host?.lowercased() == "pair" else {
                    self?.dismiss(animated: true)
                    return
                }
                self.delegate?.qrCodeScanner(self, didScanPairingURL: url)
                self.dismiss(animated: true)
            }))
            alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: { [weak self] _ in
                self?.dismiss(animated: true)
            }))
            self.present(alert, animated: true)
        }
    }
}
