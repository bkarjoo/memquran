import Foundation
import SwiftUI

/// Universal manager for determining single-page vs 2-page display mode
/// Single source of truth for page mode logic across the entire app
class PageModeManager {
    static let shared = PageModeManager()

    private init() {}

    /// Determines if two pages should be displayed based on current page and window width
    /// - Parameters:
    ///   - currentPage: The current page number
    ///   - windowWidth: The available window width
    ///   - calculatePageWidth: Function to calculate minimum width needed for a page
    /// - Returns: true if 2-page mode should be used, false for single-page mode
    func shouldShowTwoPages(
        currentPage: Int,
        windowWidth: CGFloat,
        calculatePageWidth: (Int) -> CGFloat
    ) -> Bool {
        guard windowWidth > 0 else { return false }

        // Normalize to odd page number for 2-page mode calculation
        let oddPage = currentPage % 2 == 0 ? currentPage - 1 : currentPage
        let evenPage = oddPage + 1

        // Can't show 2 pages if we're past the last page
        guard oddPage >= 1 && evenPage <= 604 else { return false }

        let oddPageWidth = calculatePageWidth(oddPage)
        let evenPageWidth = calculatePageWidth(evenPage)
        let maxPageWidth = max(oddPageWidth, evenPageWidth)
        return windowWidth >= 2 * maxPageWidth
    }
}
