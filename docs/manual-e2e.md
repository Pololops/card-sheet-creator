# Manual end-to-end checklist

Run before each release, on the Canon G5000 series and at least one other printer when possible.

## Exact size

1. **Imprimante** menu → *Imprimer la page de calibration…*
2. Measure the card outline: 54 × 85.6 mm ± 0.5 mm. Measure both rulers: 100 mm ± 0.5 mm.
3. At the middle of each edge, note the first printed mark (1 to 5 mm): it is the printer's real margin.
   If no mark prints on an edge, the unprintable border exceeds 5 mm — write a new ADR.

## Library

4. First launch: the sidebar shows the *Carte standard* template and an empty *Planches* section.
5. Change width, height and gutter with the − / + buttons and by typing; the grid and "3 × 3 = 9" follow.
   Type an impossible width (250): the field refuses it with a message.
6. ⌘Z undoes the last change; quit and relaunch: everything is as left.

## Sheets

7. Drag 10 images from a Finder folder onto the template: the page announces 2 sheets; on drop,
   "Dossier 1/2" and "Dossier 2/2" appear, the first one selected.
8. Pick one image with ⇧⌘N: one sheet, the image on every slot.
9. Drag the image inside a slot: only the overflowing axis moves, never uncovering the slot; the
   clones are outlined; near the centre it snaps and the magenta guides appear. On release every clone
   takes the framing. Arrow keys move it by 0.5 mm, ⇧ + arrow by 5 mm. Selecting a slot, even in a
   720 pt tall window, changes neither the window size nor the sidebar; the inspector scrolls. Escape, a
   click beside the page or a click on an empty slot deselects. On a sheet of 3 distinct landscape
   photos, every card selects, drags and recentres on its own, even when clicked near its edge; a quick
   flick-drag leaves no outline behind. The pointer turns into an open hand over an image that can move,
   never over an image with the slot's exact ratio nor over an empty slot.
10. Mix in an unreadable file (a .txt renamed .png): the banner reports it, *Détails* names it.

## Resize

11. On a 9-image sheet, *Modifier les dimensions…* → 66 × 90 mm: the bar warns that 3 images will move.
    *Annuler* restores the sheet; *Valider* creates "… (suite)" and offers a blank template.

## Print

12. Select two sheets, ⌘P: both previews show; choose the printer, Brouillon then Optimale; print.
    Measure a card on paper: 54 × 85.6 mm ± 0.5 mm. No outline, guide or mark is printed.
13. *Enregistrer en PDF…*: the PDF opens in Preview at A4, cards at exact size.

### Driver options (Canon G5000 series)

14. ⌘P → *Options de l'imprimante…*: the native panel opens with *Appliquer* as its button, copies
    visible, no page range, paper size, orientation or scale. Tick *Ajuster à la page*, 2 pages per
    sheet, 3 copies, then *Appliquer*: both orange warnings show, and the line "Réglages avancés de la
    dernière impression actifs · 3 copies" with *Réinitialiser*. The quality picker reads
    "Réglée par le pilote". Close and reopen ⌘P: the warnings are gone.
15. Print with those settings: 3 copies, one sheet per page, card 54 × 85.6 mm ± 0.5 mm.
16. Quit and relaunch, ⌘P: the line is active without "3 copies"; the panel opens at 1 copy.
17. Choose another printer in the panel: the dialog's picker follows. *Réinitialiser* then clears only
    the selected printer's advanced settings; the quality picker comes back.
18. Quit, change the stored `fingerprint` in `settings.json`, relaunch, ⌘P: "Réglages avancés
    réinitialisés : le pilote a changé", quality picker back, basic settings kept.
19. With advanced settings active, print the calibration page: the measurements of steps 1–3 hold.

### Colour calibration (Canon G5000, AirPrint)

20. Reset any stored correction (*Réinitialiser* in ⌘P), then ⌘P: the *Nouvelle imprimante* card tops the
    dialog and the button reads *Imprimer sans régler* (Enter still prints). With VoiceOver on, the card
    is read first, and again when you switch to another uncalibrated printer. With Reduce Motion on, the
    card fades in and its icon does not bounce. In light and dark mode the text on the card is readable.
21. *Régler les couleurs…* on the card: the dialog closes and *Réglage des couleurs* opens on the same
    printer. Printing is disabled in the toolbar and in the menu while the window is open;
    *Imprimante → Régler les couleurs…* only brings the window forward.
22. *Préparer*: *Continuer* stays disabled until the four boxes are ticked. *Ouvrir les réglages
    Moniteurs* opens System Settings on Displays. Hold a sheet against the white rectangle and tune the
    brightness until they look alike. The printer menu, *Options de l'imprimante…* and the
    auto-enhancement tip are there.
23. *Imprimer*: *Imprimer la mire couleur* prints one A4 page; every patch and letter stays inside the
    5 mm safety margin. Switch the printer off and retry: *La mire n'est pas sortie* and *Réessayer
    l'impression* appear; switch it back on and retry. The ring counts 60 s while a bordered *Comparer sans
    attendre* skips the wait; once VoiceOver announces *L'encre est sèche, tu peux comparer.*, it becomes
    the prominent *Comparer* (Enter). *Vérifier sans attendre* does the same on the verification page.
24. *Comparer*: four rounds (*Luminosité*, *Contraste*, *Dominante*, *Intensité des couleurs*), letters A–G
    and A–I. Judge each reference against the paper, daylight on the sheet. *Retour* reopens the previous
    round; *Je n'arrive pas à choisir* picks the printed centre. The reference frame is the same neutral
    grey in light and dark mode. Each tile is read *Pastille X*, the centre one with *Réglage actuel*.
25. *Vérifier*: *Imprimer la vérification* prints one page of references already corrected; once dry,
    each one looks like its screen reference. *Affiner* starts the four rounds again, around the saved
    result; *Tout correspond* (or *Passer cette étape*) goes on.
26. *C'est réglé*: the sentence names what the printer does wrong in plain words, and the gauges match it.
    *Terminer et imprimer* closes the window and reopens ⌘P with the same sheets and the same printer;
    the *Couleurs* row reads *Correction · réglée le …* and *Appliquer la correction* is ticked.
27. Print a sheet with the correction on and measure a card: 54 × 85.6 mm ± 0.5 mm. The card's white
    areas and the page margins are paper-white, even under a strong warm or cool correction. Compare
    the print with the screen: closer than the same sheet printed with *Appliquer la correction* off.
28. *Enregistrer en PDF…* with the correction on, then off: the two PDFs are identical. Imported PDF
    artwork stays sharp on the corrected print.
29. In ⌘P, untick *Appliquer la correction*: *Cette impression part sans correction.* appears. Change
    the quality, then the printer's options: *Les options de l'imprimante ont changé depuis le réglage
    des couleurs* appears and the correction is kept. *Régler à nouveau…* starts from the stored
    correction.
30. *Réinitialiser*: the row reads *Non réglées* and the card is back.
31. Black-and-white queue (or a laser printer set to monochrome): *Préparer* shows the black-and-white
    hint, the chart has two rounds, and *C'est réglé* shows two gauges.
32. Pause the printer, or remove it in System Settings, while in *Imprimer* and *Vérifier*: the error
    names the printer, the picks are kept, and retrying works once it is back. With no printer
    configured, *Imprimante → Régler les couleurs…* opens the window and *Continuer* cannot be reached.
33. Quit and relaunch: the correction is still there. Retune the step sizes in `CorrectionCurve` if the
    corrected print still drifts, then freeze them in ADR 0012.

## Trackpad and gestures

34. Sidebar, on a template row then on a sheet row, swipe two fingers to the left: a red trash grows under the
    row's trailing side, and the row stays visible. A trash click or a full swipe opens *Supprimer « … » ?*;
    the context menu's *Supprimer* and the Delete key open the same dialog, with the count for several
    rows (*Supprimer 2 éléments ?*). Return does not delete and Esc cancels; *Annuler* snaps the row back and
    leaves the selection alone; *Supprimer* removes it and ⌘Z brings it back. The empty-sheets card does not
    swipe, and VoiceOver lists *Supprimer* among the row's actions.

35. On a sheet, pinch two fingers on the trackpad: the whole canvas zooms (gutters, hatched band, grey
    background and the page), the percentage in the zoom control follows, and the zoom stops at 25 % and
    400 % with a tap of the trackpad. Do the same on a template, then check that *Ajuster* and
    *Taille réelle* still work after a pinch.

36. On a template, pinch two fingers starting on a slot: every slot resizes together with the ratio kept,
    the dimension tags and the capacity ("3 × 3 = 9 cartes") follow the fingers, and the inspector fields
    show the new size without saving it yet. Release: one ⌘Z brings the old size back. Start a pinch in the
    gutter, in the hatched band and on the grey canvas: each one zooms the view instead. Press ⌘Z during a
    pinch: nothing is left half-applied. The padlock keeps the state it had, and the pinch stops at 10 mm
    and at the largest slot that fits the page, with a tap of the trackpad.

37. In a template's inspector, hold *−* on *Largeur*: the value keeps decreasing while the slots on the
    canvas follow, and stops at the minimum. Release: the template is saved once and one ⌘Z brings back the
    size from before the press. Do the same with *+*, on *Hauteur* and on *Gouttière*, then with the padlock
    open. A plain click still steps once. In a sheet's *Redimensionner* bar, hold *−* or *+*: it repeats too.

38. On a sheet, select a slot, then scroll with two fingers over it: the image follows the scrolling
    (with natural scrolling, it follows your fingers) and stops at its edges, the transparent overflow and
    the *Centrée* tag appear while you move, and the trackpad taps when the image reaches the centre. Lift
    your fingers: one ⌘Z brings the framing back, and the glide that follows does not scroll the page. Scroll
    over an unselected slot, between slots, on the grey canvas, over the zoom control and over a slot whose
    image has exactly the slot's ratio: the page scrolls instead. With the print sheet open, scrolling
    over the app's window changes nothing under it. A mouse wheel still scrolls the page, and click, drag,
    arrow keys and the context menu on a slot still work.

## Release

39. Download the zip from the README link on another Mac (macOS 26), allow it in Privacy & Security,
    launch, print a sheet.
