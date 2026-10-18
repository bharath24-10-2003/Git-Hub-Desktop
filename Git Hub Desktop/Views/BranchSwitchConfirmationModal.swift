import SwiftUI

struct BranchSwitchConfirmationModal: View {
    let branch: String
    let repo: Repo
    let viewModel: MainViewModel
    let coordinator: AppCoordinator

    @State private var error: String?
    @State private var isWorking = false
    @AppStorage("applyStashAfterBranchSwitch") private var applyStashAfterSwitch = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ModalDescription(
                title: "You have uncommitted changes",
                description: "Choose how to handle your changes before switching to \(branch)."
            )

            if let error {
                ErrorBannerView(message: error) {
                    self.error = nil
                }
                .padding(.top)
            }

            Toggle("Apply stashed changes after switching", isOn: $applyStashAfterSwitch)
                .toggleStyle(.checkbox)
                .padding(.top, 16)

            Divider()
                .padding(.horizontal, -16)
                .padding(.vertical)

            HStack {
                BaseButton(title: "Cancel", keyboardShortcut: .cancelAction) {
                    coordinator.dismissSheet()
                }
                .disabled(isWorking)

                Spacer()

                BaseButton(title: "Discard and Switch", textTint: .red) {
                    switchBranch(stashingChanges: false)
                }
                .disabled(isWorking)

                ProminentBaseButton(title: "Stash and Switch") {
                    switchBranch(stashingChanges: true)
                }
                .disabled(isWorking)
            }
        }
        .frame(width: 560)
        .padding()
    }

    private func switchBranch(stashingChanges: Bool) {
        error = nil
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await viewModel.finishBranchSwitch(
                    stashingChanges: stashingChanges,
                    applyStashAfterSwitch: applyStashAfterSwitch,
                    branch: branch,
                    at: repo
                )
                coordinator.dismissSheet()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
