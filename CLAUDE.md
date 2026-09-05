# Startup Studio — rules for Claude

## Tests

**Do not create new tests until the owner says so.** No new test files, no new
test functions in existing files, no snapshot cases, no `@Test`/`func test…`
additions — in the app target or in any package. Keep the existing suites
green and run them as verification, but do not extend them. This applies to
every agent working in this repository (lanes, PMs, reviewers) until the owner
lifts the rule explicitly.
