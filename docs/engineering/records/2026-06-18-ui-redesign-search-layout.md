# Engineering Record: UI Redesign - Search And Table Layout

## 1. Covering Human-Owned Requirement

- `docs/human/requirements/20260615-Feature-UI Redesign.md`

## 2. Scope

This record covers the layout-only adjustment made before Section 2.23 Count
Summary implementation.

The work is limited to the Search 2 redesign shell:

- Move Search, Filter Sets, and the active/new filter control into one Search
  Filter Bar row.
- Move the View control into a separate Table Utility Bar above the data table.
- Keep the Table Utility Bar at the documented 40 px height.
- Keep the Table Utility Bar as layout only until Count Summary is implemented;
  do not draw an extra full-width background or border around the empty area.
- Preserve the existing legacy non-redesign layout.
- Do not implement Count Summary, CSV export, or Anki export behavior in this
  change.

## 3. Implementation Summary

- Added explicit redesign token constants for `--height-table-utility-bar` and
  `--spacing-3`.
- Reworked the redesign branch of `SchemaWorkbenchSearchShell` so the Search
  Filter Bar contains the search box, Filter Sets trigger, and active/new filter
  trigger on one baseline.
- Added a redesign Table Utility Bar layout row with the View trigger aligned
  to the right, without an additional full-width container frame.
- Kept the previous two-row command/filter layout for non-redesign shell usage.
- Follow-up correction: removed the temporary full-width rounded border/background
  from the Table Utility Bar because the left side has no Count Summary content
  yet and the requirement currently authorizes layout height, not an extra
  visual container.
- Follow-up correction: removed the Table Utility Bar's extra horizontal
  padding so the View trigger's right edge aligns with the data table's right
  edge through the shared shell padding.

## 4. Virtualization Constraints Preserved

- `SubtitleTableView` and its AppKit virtualized row rendering path were not
  changed.
- No row materialization, measurement pass, or data scan was added.
- Table scrolling, hydration, and visible-row callbacks remain owned by the
  existing virtual table implementation.

## 5. Verification

Commands run from `apps/macos-native/`:

```text
swift build
swift test --quiet
```

Result:

- `swift build` passed.
- `swift test --quiet` passed with 299 tests.
- The test command printed existing playback history disk I/O and EBML parsing
  warnings, but the test run completed successfully.

## 6. Outcome

The Search 2 redesign shell now has a separate Search Filter Bar and Table
Utility Bar layout structure, ready for a later Count Summary implementation
without showing an empty full-width utility frame. The View trigger is aligned
to the right edge of the data table.
