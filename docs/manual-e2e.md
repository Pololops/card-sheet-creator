# Manual end-to-end checklist

Run before each release, on the Canon G5000 series and at least one other printer when possible.

## Exact size

1. **Calibration** menu → *Imprimer la page de calibration…*
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

## Release

14. Download the zip from the README link on another Mac (macOS 26), allow it in Privacy & Security,
    launch, print a sheet.
