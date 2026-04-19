---
name: css-grid-subgrid
type: tacit
problem: CSS subgrid inheritance behavior differs across browsers causing layout breaks mobile viewport
cause: Subgrid specification partially implemented desktop Firefox Safari but not yet mobile Chrome 100
solution: Feature detect subgrid using CSS supports query fallback to flexbox gap for missing browsers
prevention: Add visual regression snapshot test suite per target browser with Percy or Chromatic CI integration
related_files:
  - src/styles/grid-layout.css
  - src/components/DashboardGrid.tsx
---

# CSS Subgrid Cross-Browser

Documented layout pattern for subgrid fallback.
