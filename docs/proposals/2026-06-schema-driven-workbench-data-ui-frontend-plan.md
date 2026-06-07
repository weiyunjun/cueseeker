# Schema-Driven Workbench Data UI Frontend Plan

Status: Proposed

Human requirement:

- `docs/human/requirements/20260608-Feature-Schema Driven Workbench Data UI.md`

Reference design:

- `docs/human/design/UI Design.md`
- `docs/human/design/assets/SearchUI-1.png`
- `docs/human/design/assets/SearchUI-2.png`

## Purpose

This proposal defines the frontend implementation plan for the independent
Test Search UI screen requested by the human requirement.

The screen is a UI-alignment surface first. It uses fake data, but it must be
structured as the first frontend slice of a future schema-driven workbench data
UI that can later support Search, Library, Shiori, custom columns, custom field
types, editable database fields, and externally driven field mutations.

## Product Scope

Implement an independent top-bar test entry placed to the right of the existing
Test Shiori icon. The entry opens a standalone Test Search UI screen.

The visible main screen has exactly three layout regions:

```text
SchemaWorkbenchPage
|-- SearchCommandBar
|-- FilterControlBar
`-- WorkbenchDataTable
```

Menus, dropdowns, and the filter builder are overlays. They must not become a
fourth main layout region and must not push the table down.

```text
OverlayLayer
|-- ColumnVisibilityPopover
|-- FilterSetPopover
|-- FilterBuilderPopover
`-- FieldOrOperatorDropdownPopover
```

## Non-goals

- Do not implement real database search, filtering, sorting, persistence, or
  query compilation.
- Do not connect the screen to `SearchStore`, `LibraryStore`, `ShioriStore`, or
  `CueSeekerCore` data.
- Do not implement editable database fields yet.
- Do not implement external mutation APIs yet.
- Do not show row hover Play / Copy actions in this phase.
- Do not replace the existing Test Search or Test Shiori pages.

## Frontend Principles

1. **Three-region main layout**
   The main page is search controls, filter controls, and a table. All other UI
   is overlay state.

2. **Schema-driven presentation**
   The table is rendered from column schema plus row values. Search is only the
   first example, not the table's semantic owner.

3. **Data-type-driven cells**
   Cells are not named after Search meanings such as "subtitle cell" or
   "language cell". A column's data type selects the renderer.

4. **Reusable workbench controls**
   Buttons, chips, popovers, dropdown rows, badges, inputs, and table visuals
   should be reusable by future Library and Shiori screens.

5. **Overlay independence**
   Opening menus or the filter builder must not invalidate the table's layout
   position or change the table's top coordinate.

6. **Small implementation slices**
   Each implementation step should be small enough to commit and visually check
   independently.

## Component Anatomy

### Top-Bar Entry

`TestSearchUIEntryButton`

Responsibilities:

- Add an independent icon-only entry to the main top bar, to the right of the
  existing Test Shiori icon.
- Use the same hover, selected, tooltip, and accessibility treatment as the
  current top-bar test buttons.
- Activate a distinct test page, separate from the existing Test Search page.

The entry should update `WorkbenchTestPage` with a new case rather than
overloading the existing `.search` test page.

### Page Canvas

`SchemaWorkbenchPage`

Responsibilities:

- Own the fake UI state for the alignment screen.
- Arrange the three main regions vertically.
- Own the overlay layer and the currently open popover identity.
- Use a quiet workbench background close to the reference image.
- Avoid card-style page framing; the screen should feel like a dense data
  workspace.

Suggested state:

```text
searchDraft
activeFilterSetID
isFilterBuilderOpen
openPopover
allColumns
visibleColumnIDs
filterDraftRows
mockRows
```

### Search Command Bar

`SearchCommandBar`

Visible structure:

```text
[ WorkbenchSearchField                                      ] [ ViewMenuButton ]
```

Components:

- `WorkbenchSearchField`
- `ViewMenuButton`

`WorkbenchSearchField`:

- Large horizontal field occupying most of the row.
- Leading magnifying glass icon.
- Placeholder: `Search cues by name, lyrics, or keywords...`
- Rounded rectangle, subtle border, calm fill.
- Focus state may use a stronger border, but should remain visually restrained.
- Edits fake draft state only in this phase.

`ViewMenuButton`:

- Icon + `View` + chevron.
- Same height class as the search field.
- Opens `ColumnVisibilityPopover`.

### Filter Control Bar

`FilterControlBar`

Visible states:

```text
Named filter set:
[ Filter Sets v ] [ bangdream  2 Filters ] [ Reset ]

No filters:
[ Filter Sets v ] [ + New Filter Set ]

Draft filters:
[ Filter Sets v ] [ 3 Filters ] [ Reset ]
```

Components:

- `FilterSetsButton`
- `ActiveFilterSetChip`
- `FilterCountChip`
- `NewFilterSetButton`
- `ResetButton`

`FilterSetsButton`:

- Filter icon + `Filter Sets` + chevron.
- Opens `FilterSetPopover`.

`ActiveFilterSetChip`:

- Light blue active surface.
- Filter icon and active preset name.
- Shows filter count.
- Opens `FilterBuilderPopover` if editing is requested.

`FilterCountChip`:

- Light blue active surface.
- Shows current draft count such as `3 Filters`.
- Opens `FilterBuilderPopover`.

`NewFilterSetButton`:

- Plus icon + `New Filter Set`.
- Opens `FilterBuilderPopover`.

`ResetButton`:

- X icon + `Reset`.
- Clears fake filter state.

### Column Visibility Popover

`ColumnVisibilityPopover`

Responsibilities:

- Anchor to `ViewMenuButton`.
- Render a white rounded popover with soft shadow and subtle border.
- List all columns with checkmark state.
- Toggle column visibility when an item is clicked.
- Hide the corresponding table header and body cells immediately.

Initial items:

```text
#
Name
Cues
Language
Speaker
```

Column visibility should distinguish:

```text
allColumns       // schema fields that exist
visibleColumnIDs // view state
```

The filter builder field list should use `allColumns`, not only visible
columns, because hidden fields still exist in the schema.

### Filter Set Popover

`FilterSetPopover`

Responsibilities:

- Anchor to `FilterSetsButton`.
- Render a single-select list.
- Show a left checkmark for the active filter set.
- Use hover row background matching the reference.

Initial fake options:

```text
bangdream
Ave Mujica
Chinese Only
Speaker Focus
```

Choosing an option updates fake filter state and the active chip.

### Filter Builder Popover

`FilterBuilderPopover`

Responsibilities:

- Open as an overlay, not as an inline panel.
- Cover the table area as needed without moving the table.
- Default to hidden.
- Provide a visual condition editor matching the reference state.

Visible structure:

```text
New Filter Set
Where [Field] [Operator] [Value] [Delete]
and   [Field] [Operator] [Value] [Delete]
or    [Field] [Operator] [Value] [Delete]

+ New Filter
[ Save Filter Set ]
```

Components:

- `FilterRuleRow`
- `FilterJoinOperatorSelect`
- `FilterFieldSelect`
- `FilterOperatorSelect`
- `FilterValueInput`
- `DeleteRuleButton`
- `AddFilterButton`
- `SaveFilterSetButton`

Rules:

- Join operator can be `and` or `or`.
- Field options come from every table header in `allColumns`.
- Operators are selected according to the field data type.
- Value input appearance is selected according to the field data type.
- The current phase stores only fake draft state.

### Workbench Data Table

`WorkbenchDataTable`

Responsibilities:

- Render from schema and fake rows.
- Keep the header frozen.
- Virtualize or reuse visible rows where practical.
- Support visible-column updates from the View menu.
- Keep table layout stable while overlays open.

Visible structure:

```text
TableContainer
|-- FrozenHeaderRow
`-- VirtualizedBodyRows
```

Initial columns:

```text
#        rowNumber
Name     text
Cues     text
Language multiSelect
Speaker  text
```

Column behavior:

- `#` is a row-number renderer.
- `Name`, `Cues`, and `Speaker` use text rendering.
- `Cues` is not a separate semantic cell type. It is text that may wrap
  naturally depending on content and column width.
- `Language` uses the same multi-select renderer that future tag columns can
  reuse.

Table visual traits:

- Rounded outer border.
- Subtle row separators.
- Fixed header.
- Quiet hover treatment, if any.
- Stable row minimum height.
- Text should remain selectable only if the implementation slice explicitly
  includes selection support; otherwise keep the visual layer ready for a later
  selection slice.

### Cell Renderer Model

Cell rendering should be driven by data type, not feature-specific semantics.

Initial renderer set:

```text
WorkbenchCellRenderer
|-- RowNumberRenderer
|-- TextRenderer
|-- SelectRenderer
|-- MultiSelectRenderer
|-- NumberRenderer
|-- BooleanRenderer
`-- EmptyRenderer
```

Only the renderer types needed for the reference UI must be implemented in the
first visual pass. The remaining names are allowed as planning vocabulary, but
unused implementation scaffolding should be avoided.

## Data-Type Planning

The future model is similar to Notion-style properties: a column has a data
type, and the type determines both display and editing affordances.

Initial planning types:

```text
rowNumber
text
select
multiSelect
number
boolean
date
```

Current implementation only needs:

```text
rowNumber
text
multiSelect
```

Future data-type work should be introduced only when a committed requirement
covers it.

## Interaction Scope

Implemented in this phase:

- Independent top-bar Test Search UI entry.
- Search field draft editing.
- View menu open / close.
- View menu column toggling that hides columns.
- Filter Sets menu open / close.
- Fake filter set selection.
- Reset fake filters.
- Filter Builder popover open / close.
- Join operator selection (`and` / `or`).
- Field selection from all table headers.
- Basic operator/value fake UI state.
- Fake rows rendered in the table.

Not implemented in this phase:

- Real search.
- Real filtering.
- Real persistence.
- Real schema editing.
- Real field editing.
- External mutation APIs.
- Hover Play / Copy row actions.

## Implementation Sequence

### Step 1 - Proposal And Record

Add this frontend implementation proposal and a matching engineering record.

Verification:

- Documentation files exist.
- They cite the committed human requirement.
- No source code is modified.

### Step 2 - Independent Entry And Blank Page

Add a new `WorkbenchTestPage` case and a top-bar icon to the right of Test
Shiori. Route it to a blank `SchemaWorkbenchPage`.

Verification:

- `swift build --target CueSeekerApp`
- Existing Test Library/Search/Shiori entries still work.
- New entry can be selected independently.

### Step 3 - Three-Region Layout Skeleton

Add `SearchCommandBar`, `FilterControlBar`, and `WorkbenchDataTable` placeholders.

Verification:

- The page visibly has exactly three main regions.
- No overlay opens yet.
- Table placeholder position is stable.

### Step 4 - Shared Workbench Controls

Add reusable visual controls for fields, buttons, chips, badges, popover rows,
and small icon buttons.

Verification:

- Controls match reference density closely enough for first-pass alignment.
- Controls are not Search-specific in naming or API.

### Step 5 - Overlay Popovers

Add popover positioning and open-state coordination for View, Filter Sets, and
Filter Builder.

Verification:

- Opening overlays does not move the table.
- Only one popover is active at a time unless a nested dropdown is required.

### Step 6 - Schema-Driven Table First Pass

Render the fake Search UI rows from column schema and row values.

Verification:

- Five initial columns match the reference.
- Language renders through a reusable multi-select renderer.
- Cues renders as text with natural wrapping.

### Step 7 - Fake Interactions

Wire fake state for column visibility, filter set selection, reset, filter
builder fields, operators, and values.

Verification:

- View menu hiding a column removes that header and all body cells.
- Filter Builder field dropdown contains all headers.
- Reset restores the no-filter state.

### Step 8 - Visual Alignment Iterations

Iterate on spacing, sizing, typography, colors, radii, shadows, table density,
and popover placement against the two reference images.

Verification:

- Capture app screenshots for the main table state and the reference popover
  states.
- Compare visible differences and adjust in small commits.

## Documentation Rules

Every implementation step outside `docs/human/` must:

- Be covered by the committed human requirement:
  `docs/human/requirements/20260608-Feature-Schema Driven Workbench Data UI.md`
- Create or update a record under `docs/engineering/records/`.
- Include the relevant `docs/human/` path in the commit message.

## Open Questions

- Which exact SF Symbol should represent the new Test Search UI entry?
- Should the column visibility menu prevent hiding all columns, or allow an
  empty table state for alignment testing?
- Should popovers close on outside click immediately, or stay open while nested
  dropdowns are active?
- Should first-pass screenshots target the app's current default window size or
  the reference image's effective viewport?
