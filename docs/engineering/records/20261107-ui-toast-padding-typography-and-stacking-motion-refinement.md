# Toast Padding, Typography, And Stacking Motion Refinement

## Summary

- Requirement: `docs/human/requirements/20261107-UI-Toast Padding Typography And Stacking Motion Refinement.md`
- Refined `C-09.1 Toast` and `L-01.4 Toast Layout` in `Toast.swift`, `WorkbenchControlMetrics.swift`, and `WorkbenchRedesignTokens.swift`:
  - Increased Toast vertical padding (`Padding (Block)`) from `--spacing-2` (`8px`) to `--spacing-4` (`16px`), raising single-line Toast height from `36px` to `52px` while keeping horizontal padding `--padding-control-x` (`14px`), icon-to-text gap `--spacing-2` (`8px`), corner radius `--radius-toast` (`10px`), and icon size `--size-toast-icon` (`16px`) unchanged.
  - Updated both Toast icon color and message text color (`--color-toast-text`) to `--color-text-secondary` (Light `#494949`, Dark `#B9B9B9`) across all Toast scenarios.
  - Updated Toast typography to use the dedicated font-weight token `--font-weight-toast` (`500`, `.medium`) instead of borrowing `--font-weight-control`.
  - Aligned Toast 3-layer folded stacking geometry and entrance/exit animations with the `shadcn` (`@base-ui/react/toast`) reference:
    - Anchored stacked cards at bottom center (`anchor: .bottom`), with scale step `--scale-step-toast-stack = 0.10` (`1.00`, `0.90`, `0.80`) and upward peek offset `--offset-toast-stack = 12px` (`-(index * 12px) - (shrink * frontmostHeight)`).
    - Kept the outer `ToastStackView` container mounted continuously and assigned monotonic sequence indices for stable `.zIndex` ordering during entrance, stacking, and exit transitions.
    - Updated entrance motion so newly triggered Toasts remain `100%` opaque (`opacity = 1`) and slide up from `150%` of card height (`--distance-toast-motion: 150%`, ratio `1.5`) over `--duration-toast-motion = 0.50s` (`cubic-bezier(0.22, 1, 0.36, 1)`).
    - Differentiated exit animations in `ToastCenter.renderedItems` while keeping `ToastCenter.visibleItems` synchronous (`<= 3`):
      - Natural timer expiration (`isEnding && !isLimited`) slides down by `150%` of card height while fading out to `opacity = 0` over `0.50s`.
      - Overflow eviction beyond 3 layers (`isLimited`, `stackIndex = 3`, `scale = 0.70`) continues pushing upward and shrinking at the top of the stack while fading out to `opacity = 0` over `0.50s`.
    - Added independent behind-card inner content opacity transition (`--duration-toast-content = 0.25s`, `cubic-bezier(0.22, 1, 0.36, 1)`) and card height synchronization transition (`--duration-toast-height = 0.15s`).

## Verification

- `swift test --package-path apps/macos-native --filter ToastTests`
