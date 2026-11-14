import SwiftUI
import UIKit

enum HostingConfigurationCell {
    @Observable
    final class Model {}

    struct Reader: View {
        @Environment(Model.self)
        private var model

        var body: some View {
            Text(verbatim: "\(model)").reportsRendered()
        }
    }

    @MainActor
    final class DataSource: NSObject, UICollectionViewDataSource {
        private let registration = UICollectionView.CellRegistration<UICollectionViewListCell, Int> { cell, _, _ in
            cell.contentConfiguration = UIHostingConfiguration { Reader() }
        }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            1
        }

        func collectionView(
            _ collectionView: UICollectionView,
            cellForItemAt indexPath: IndexPath,
        ) -> UICollectionViewCell {
            collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: indexPath.item)
        }
    }

    struct List: UIViewRepresentable {
        func makeCoordinator() -> DataSource {
            DataSource()
        }

        func makeUIView(context: Context) -> UICollectionView {
            let configuration = UICollectionLayoutListConfiguration(appearance: .plain)
            let view = UICollectionView(
                frame: .zero,
                collectionViewLayout: UICollectionViewCompositionalLayout.list(using: configuration),
            )
            view.dataSource = context.coordinator
            return view
        }

        func updateUIView(_ uiView: UICollectionView, context: Context) {}
    }

    struct Root: View {
        var body: some View {
            List().environment(Model())
        }
    }
}
