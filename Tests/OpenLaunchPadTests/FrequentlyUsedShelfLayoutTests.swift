import CoreGraphics
import Testing
@testable import OpenLaunchPad

struct FrequentlyUsedShelfLayoutTests {
    @Test
    func shelfIsAbout68PointsTallBesideEightyPointIcons() {
        let shelf = FrequentlyUsedShelfLayout(gridIconSize: 80, width: 1_400)

        #expect(shelf.iconSize == 48)
        #expect(shelf.height == 68)
        #expect(shelf.reservedHeight == 80)
        #expect(shelf.capacity == 9)
    }

    @Test
    func iconsAreWholePointsAtSixTenthsOfTheGrid() {
        #expect(FrequentlyUsedShelfLayout(gridIconSize: 75, width: 1_400).iconSize == 45)
        #expect(FrequentlyUsedShelfLayout(gridIconSize: 57, width: 1_400).iconSize == 34)
        #expect(FrequentlyUsedShelfLayout(gridIconSize: 144, width: 2_560).iconSize == 86)
    }

    @Test
    func narrowWidthShowsAsManyIconsAsFit() {
        let shelf = FrequentlyUsedShelfLayout(gridIconSize: 160, width: 800)
        func width(showing count: Int) -> CGFloat {
            2 * FrequentlyUsedShelfLayout.horizontalPadding + CGFloat(count) * shelf.iconSize
                + CGFloat(count - 1) * FrequentlyUsedShelfLayout.spacing
        }

        #expect(shelf.iconSize == 96)
        #expect(shelf.capacity == 7)
        #expect(width(showing: shelf.capacity) <= 800)
        #expect(width(showing: shelf.capacity + 1) > 800)
    }
}
