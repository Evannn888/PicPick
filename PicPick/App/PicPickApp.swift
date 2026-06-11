import SwiftUI

/// Entry point for the PicPick app.
///
/// Sets up environment injection of ViewModels and favorites on launch.
@main
struct PicPickApp: App {

    @State private var gridViewModel = PhotoGridViewModel()
    @State private var favoritesViewModel = FavoritesViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(gridViewModel)
                .task {
                    gridViewModel.setFavoriteIdentifiers(favoritesViewModel.favoriteIdentifiers)
                }
                .preferredColorScheme(.dark)
        }
    }
}
