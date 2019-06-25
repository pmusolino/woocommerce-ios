import UIKit
import StripeTerminal

final class TestReaderViewController: UIViewController, DiscoveryDelegate, TerminalDelegate {

    var discoverCancelable: Cancelable?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        connectReaderAction()
    }

    // ...

    // Action for a "Connect Reader" button
    func connectReaderAction() {
        let config = DiscoveryConfiguration(deviceType: .chipper2X,
                                            discoveryMethod: .bluetoothProximity,
                                            simulated: true)
        self.discoverCancelable = Terminal.shared.discoverReaders(config, delegate: self, completion: { error in
            if let error = error {
                print("discoverReaders failed: \(error)")
            }
            else {
                print("discoverReaders succeeded")
            }
        })
    }

    // ...

    // MARK: DiscoveryDelegate

    func terminal(_ terminal: Terminal, didUpdateDiscoveredReaders readers: [Reader]) {
        // Just select the first reader in this example.
        guard let selectedReader = readers.first else { return }
        // Only connect if we aren't currently connected.
        guard terminal.connectionStatus == .notConnected else { return }

        // In your app, display the discovered reader(s) to the user.
        // Call `connectReader` with the selected reader.
        Terminal.shared.connectReader(selectedReader, completion: { reader, error in
            if let reader = reader {
                print("Successfully connected to reader: \(reader)")
            }
            else if let error = error {
                print("connectReader failed: \(error)")
            }
        })
    }

    func terminal(_ terminal: Terminal, didReportUnexpectedReaderDisconnect reader: Reader) {
        print("==== did report unexpected disconnect")
    }

}
