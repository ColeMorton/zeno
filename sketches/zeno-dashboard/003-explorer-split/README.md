## Variant: Explorer-split

### Design stance
Protocol explorers are multi-surface tools. Left nav for orientation, center for browsing, right for depth — each panel has one job.

### Key choices
- **Layout:** Three-panel shell: fixed sidebar (220px) → scrollable vault list → sticky detail panel (340px). No overlap, no modals for browsing.
- **Interaction:** Click a vault in the center list → right panel updates instantly with full detail (metrics grid, timeline, action buttons). Sidebar nav is present but the tab state is cosmetic for this sketch.
- **Content:** Vault cards show name/type/balance/status/APR. Detail panel shows 4-metric grid, activity timeline (4 events), and action buttons.
- **Typography:** 18px panel title, 14px card text, monospace for all numbers.

### Trade-offs
- **Strong at:** Deep exploration without losing context. The "browse → drill in" pattern is natural for analysts.
- **Weak at:** Screen real estate — needs at least 1024px to work well. The left sidebar steals space that could show data. On mobile it must collapse.

### Best for
- Analysts and researchers who need to compare vaults side-by-side.
- The "explore before acting" workflow — browse first, act on the detail panel.
- Protocol explorers / block explorers adapted for vault data.
