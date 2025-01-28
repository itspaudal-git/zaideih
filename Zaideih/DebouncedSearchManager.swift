//
//  DebouncedSearchManager.swift
//  Zaideih
//

import Combine
import Foundation

class DebouncedSearchManager: ObservableObject {
    @Published var debouncedSearchQuery: String = ""
    private var searchDebounceDelay: TimeInterval = 0.3
    private var cancellables = Set<AnyCancellable>()

    // Public function to debounce the search query
    func debounceSearch(_ query: String) {
        // Cancel any existing publisher when search query changes
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        // Delay execution of search to avoid searching on every keystroke
        Just(query)
            .delay(for: .seconds(searchDebounceDelay), scheduler: RunLoop.main)
            .sink { [weak self] newQuery in
                self?.debouncedSearchQuery = newQuery
            }
            .store(in: &cancellables)
    }
}
