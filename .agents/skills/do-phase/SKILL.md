---
name: do-phase
description: Pick up the next uncompleted phase from PROGRESS.md, implement it, update progress, and commit.
disable-model-invocation: false
---

# Do Phase

Implement the next uncompleted project phase.

## Current Progress

!`cat docs/PROGRESS.md`

## Workflow

1. **Find the next phase** — from the progress table above, identify the first phase with status "Not Started" or "In Progress". The corresponding phase doc lives at `docs/phases/PHASE-XX.md`.

2. **Read the phase doc** and understand the goal, directory structure, detailed steps, dependencies, gotchas, and acceptance criteria.

3. **Implement the phase** by following the detailed steps in the doc:
   - Create and modify files as specified.
   - Install dependencies as needed.
   - Follow the exact module structure, file paths, and code outlined in the doc.
   - Where the doc provides placeholder/stub code (e.g. TODO comments, stubs), implement it as-is — do not fill in logic the doc explicitly defers to later phases.
   - **When writing or reviewing SwiftUI code, use the `/swiftui-pro` skill** to ensure best practices for macOS 14+.

4. **Write tests first (red/green TDD)** — before implementing application logic, write failing unit tests in `Squawk/SquawkTests/` that cover the acceptance criteria. Run `xcodebuild test` to confirm they fail (red). Then write the minimum implementation to make them pass (green). Repeat for each piece of testable logic. Tests should cover business logic, state machines, and data transforms — not SwiftUI views.

5. **Verify the build** — run `xcodebuild -project Squawk.xcodeproj -scheme Squawk -destination 'platform=macOS' build` to confirm everything compiles. **Do NOT use `swift build`** — it will compile but crash at runtime due to Metal shader requirements.

6. **Update `docs/PROGRESS.md`** — check off completed acceptance criteria and change the phase status to "Done" or "In Progress".

7. **Commit all changes** in a single commit with a message following this pattern:
   ```
   Phase XX: <short summary>

   <longer description of changes, dependencies added, and key decisions>
   ```

## Rules

- Do not modify files outside the scope of the phase doc unless necessary to fix a build break.
- Do not add features, refactor, or make improvements beyond what the phase doc specifies.
- If a step fails or a dependency doesn't exist, diagnose and adapt. Report blockers to the user rather than guessing.
- If the phase doc references test fixtures or sample data, create minimal valid versions.
