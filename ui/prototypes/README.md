# UI Prototypes

Status: Active

This directory stores local HTML prototypes used as the visual collaboration
baseline for CueSeeker interface changes.

Rules:

- Each actively edited prototype should live in a versioned directory with
  `index.html`, `styles.css`, and `script.js`.
- Do not make iterative design changes in generated standalone HTML exports.
  If a single-file HTML is needed for another AI or tool, generate it from the
  source directory after the source has been updated.
- Generated standalone exports are share artifacts, not the source of truth.
- Prototypes should include basic interaction states such as expanded and
  collapsed panels, popover or menu examples, selected states, hover feedback,
  and button feedback when relevant.
- Prototypes do not need to implement real product behavior such as media
  playback, indexing, database access, or file-system access.
- Complex screens may be split into multiple focused prototype source
  directories when one source directory would make review or AI-assisted
  editing difficult.
