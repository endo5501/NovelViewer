# Spec Delta

## RENAMED Requirements

- FROM: `### Requirement: Drawers open only from the app bar`
- TO: `### Requirement: Drawers do not open from an edge drag`

## MODIFIED Requirements

### Requirement: Drawers do not open from an edge drag
The application SHALL disable the scaffold's edge-drag gestures for both drawers, in both layouts. The vertical text viewer already interprets a horizontal drag as a page turn, so an edge drag that opened a drawer would take page turning away at exactly the edges of the screen.

The pointer-driven ways to open a drawer SHALL be the app bar's buttons, for either drawer, and a double tap in the middle of the vertical viewer, for the file browser drawer alone. No other pointer gesture SHALL open either drawer.

Because the file browser drawer now exists at every display width, the app bar SHALL offer its button at every display width.

#### Scenario: An edge drag does not open a drawer
- **WHEN** the reader drags horizontally from the left or right edge of the screen, in either layout
- **THEN** no drawer opens, and the gesture is left to the viewer beneath

#### Scenario: The app bar opens the drawer
- **WHEN** the reader taps the app bar's drawer button, in either layout
- **THEN** the drawer opens

## ADDED Requirements

### Requirement: A double tap in the middle of the vertical viewer opens the file browser drawer
In vertical display mode, two touch taps in quick succession in the middle of the page area SHALL open the file browser drawer, so that a reader on a tablet can go and choose what to read next without reaching for the app bar's corner or a keyboard.

The middle of the page area SHALL be the middle third of its width, over its full height. The left and right thirds SHALL NOT respond to a double tap, so they remain free for a later tap-to-turn gesture.

The trigger SHALL apply only to pointers that have no secondary button — touch and stylus. A mouse already reaches the drawer from the app bar and the keyboard, and a click on the text already means "clear the selection". The distinction SHALL be made from the pointer's device kind rather than from the running platform, so that a tablet with a trackpad keeps the pointer behaviour.

A tap SHALL count towards the double tap only when it opens and clears nothing: it lands where no selection is active and on no marked word. A tap that opens the selection context menu, opens a summary popup, or clears an existing selection SHALL keep that meaning and SHALL NOT start or complete a double tap. The two taps SHALL both land in the middle third, close to each other, and the second SHALL follow the first within the platform's usual double-tap interval. A drag between them — a page swipe or a selection drag — SHALL discard the first tap.

The single tap SHALL keep its existing meanings and respond as quickly as it does today: the viewer SHALL NOT wait to see whether a second tap follows before acting on the first.

Horizontal display mode SHALL NOT respond to this trigger, because there a double tap already selects a word.

A double tap SHALL open the drawer and never close it. While the drawer is open its scrim covers the viewer, so the viewer cannot receive the taps.

#### Scenario: A finger double tap in the middle opens the drawer
- **WHEN** the reader taps twice in quick succession with a finger in the middle third of the page area in vertical mode, with no selection active and not on a marked word
- **THEN** the file browser drawer opens

#### Scenario: A stylus double tap in the middle opens the drawer
- **WHEN** a stylus taps twice in quick succession in the middle third of the page area in vertical mode, with no selection active and not on a marked word
- **THEN** the file browser drawer opens

#### Scenario: A double tap near the side opens nothing
- **WHEN** the reader taps twice in quick succession with a finger in the left third or the right third of the page area in vertical mode
- **THEN** no drawer opens

#### Scenario: A mouse double click opens nothing
- **WHEN** the reader clicks twice in quick succession with a mouse in the middle third of the page area in vertical mode
- **THEN** no drawer opens

#### Scenario: Two taps too far apart in time open nothing
- **WHEN** the reader taps with a finger in the middle third, and taps there again after the double-tap interval has passed
- **THEN** no drawer opens

#### Scenario: Two taps too far apart in space open nothing
- **WHEN** the reader taps twice in quick succession with a finger in the middle third, the second tap well away from the first
- **THEN** no drawer opens

#### Scenario: A swipe between the taps discards the first
- **WHEN** the reader taps with a finger in the middle third, swipes to turn the page, and taps in the middle third again within the double-tap interval of the first tap
- **THEN** no drawer opens

#### Scenario: A tap that clears a selection does not start a double tap
- **WHEN** a selection is active and the reader taps twice in quick succession with a finger in the middle third, outside the selection and not on a marked word
- **THEN** the first tap clears the selection and no drawer opens

#### Scenario: A tap that opens a summary popup does not start a double tap
- **WHEN** the reader taps with a finger on a marked word in the middle third and then taps unmarked text next to it within the double-tap interval
- **THEN** the first tap opens the summary popup and no drawer opens

#### Scenario: A tap inside the selection still opens the menu
- **WHEN** a selection is active and the reader taps with a finger inside it, in the middle third
- **THEN** the selection context menu opens at once, and no drawer opens

#### Scenario: The first tap keeps its immediate meaning
- **WHEN** the reader taps once with a finger on a marked word in vertical mode
- **THEN** the summary popup opens without waiting for the double-tap interval to pass

#### Scenario: Horizontal mode is not affected
- **WHEN** the reader taps twice in quick succession with a finger in the middle of the text in horizontal display mode
- **THEN** no drawer opens, and the double tap keeps its existing meaning in the text
