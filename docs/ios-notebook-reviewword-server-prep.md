# iOS Notebook / ReviewWord Server Migration Prep

## Scope
- Current local persistence structure only
- Server migration preparation points only
- No API client implementation in this step

## 1. Current local data structure

### Notebook domain model
- `WordNotebook` stores notebook metadata as `id: UUID`, `title`, `descriptionText`, `items`, `createdAt`.
- `WordNotebookItem` stores notebook entries as `id: UUID`, `wordId: Int?`, `word`, `reading`, `meaning`, `note`, `addedAt`.
- Code:
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/Domain/Models/WordNotebook.swift`

### Notebook local persistence
- `NotebookStore` is the single local source of truth for notebook state.
- Persistence medium is `UserDefaults`.
- Storage key is `word_notebooks`.
- Save format is `[WordNotebook]` encoded as JSON via `JSONEncoder` / `JSONDecoder`.
- Load path:
  - `load()` decodes `[WordNotebook]`.
  - If decoding fails, it falls back to empty array.
- Save path:
  - `save()` sanitizes notebook items, encodes the full notebook array, then overwrites the whole value in `UserDefaults`.
- Code:
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/Data/Local/NotebookStore.swift:19`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/Data/Local/NotebookStore.swift:21`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/Data/Local/NotebookStore.swift:257`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/Data/Local/NotebookStore.swift:276`

### Notebook mutation structure
- Notebook-level mutations:
  - `addNotebook`
  - `updateNotebookTitle`
  - `updateNotebook`
  - `deleteNotebook`
- Item-level mutations:
  - `addItem` for manual words
  - `addJLPTWord` for dictionary-backed words
  - `updateItem`
  - `deleteItem`
- All mutations update the in-memory array first, then call `save()`.
- Code:
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/Data/Local/NotebookStore.swift:29`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/Data/Local/NotebookStore.swift:53`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/Data/Local/NotebookStore.swift:67`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/Data/Local/NotebookStore.swift:126`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/Data/Local/NotebookStore.swift:160`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/Data/Local/NotebookStore.swift:203`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/Data/Local/NotebookStore.swift:248`

### Notebook duplicate handling
- Duplicate detection is local and synchronous.
- The effective rule is:
  - same `wordId` when both sides have `wordId`
  - or same normalized expression
  - or same normalized expression plus same normalized reading
- `save()` also sanitizes notebook items and removes duplicates by normalized expression only.
- This means the persisted notebook list is effectively expression-unique inside each notebook, regardless of `wordId`.
- Code:
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/Data/Local/NotebookStore.swift:84`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/Data/Local/NotebookStore.swift:104`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/Data/Local/NotebookStore.swift:286`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/Data/Local/NotebookStore.swift:298`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/Data/Local/NotebookStore.swift:316`

### ReviewWord local persistence
- `ReviewWordStore` is a local set of `Int` word IDs.
- Persistence medium is `UserDefaults`.
- Storage key is `review_words`.
- Save format is `[Int]`, exposed in memory as `Set<Int>`.
- There is no per-item metadata such as `createdAt`, source, or server ID.
- Code:
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/Data/Local/ReviewWordStore.swift:5`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/Data/Local/ReviewWordStore.swift:8`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/Data/Local/ReviewWordStore.swift:10`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/Data/Local/ReviewWordStore.swift:19`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/Data/Local/ReviewWordStore.swift:54`

## 2. `wordId`-based storage and usage

### ReviewWord
- Review words are fully `wordId`-based.
- The persisted data is just a set of dictionary word IDs.
- This works only for words that exist in the dictionary database.
- Manual notebook words cannot participate in review state with the current structure.
- Code:
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/Data/Local/ReviewWordStore.swift:8`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/UI/Screens/Words/WordListViewModel.swift:140`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/UI/Screens/Words/WordDetailViewModel.swift:54`

### Notebook
- Notebook items support mixed identity:
  - JLPT-backed item: `wordId != nil`
  - manual item: `wordId == nil`
- This is already the core server-migration split.
- The UI depends on this split in `WordListItem.Source`:
  - `.jlpt(level:wordId:)`
  - `.notebook(notebookId:itemId:)`
- Notebook list items shown in the word list do not carry `wordId` through `WordListItem` for notebook source.
- That means downstream code treats notebook items as custom content, even if the original notebook item has a `wordId`.
- Code:
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/Domain/Models/WordNotebook.swift:25`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/Domain/Models/WordListItem.swift:4`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/Domain/Models/WordListItem.swift:33`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/Domain/Models/WordListItem.swift:48`

## 3. Manual input word structure

### Current structure
- Manual words are saved by `NotebookStore.addItem`.
- Required fields:
  - `word`
  - `meaning`
- Optional fields:
  - `reading`
  - `note`
- Identity:
  - local item `id: UUID`
  - `wordId` is always `nil`
- Code:
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/Data/Local/NotebookStore.swift:126`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/UI/Screens/Words/AddNotebookWordView.swift:178`

### Current UX behavior
- On manual add, the app checks if the same expression already exists in the local dictionary DB.
- If yes, it still allows saving as a manual notebook word after confirmation.
- So manual input is not strictly separate from dictionary-backed content. The distinction is whether the item was linked with a `wordId` at save time.
- Code:
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/UI/Screens/Words/AddNotebookWordView.swift:161`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/UI/Screens/Words/AddNotebookWordView.swift:170`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/UI/Screens/Words/AddNotebookWordView.swift:219`

## 4. Current UI / ViewModel dependency map

### NotebookStore consumers
- `WordListView`
  - owns a `NotebookStore`
  - streams `notebookStore.$notebooks` into `WordListViewModel.updateNotebooks`
- `NotebookDetailView`
  - reads notebook/items
  - directly mutates notebook/item create/update/delete
- `CreateNotebookView`
  - directly calls `addNotebook`
- `AddNotebookWordView`
  - directly calls `addItem` / `updateItem`
- `NotebookPickerSheetView`
  - directly calls `containsJLPTWord` / `addJLPTWord`
- `NotebookWordDetailView`
  - directly deletes item and opens manual edit
- `WordDetailView`
  - owns another `NotebookStore` and passes it to notebook picker / detail flow
- Code:
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/UI/Screens/Words/WordListView.swift:10`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/UI/Screens/Words/WordListView.swift:44`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/UI/Screens/Words/NotebookDetailView.swift:15`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/UI/Screens/Words/NotebookDetailView.swift:49`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/UI/Screens/Words/NotebookDetailView.swift:60`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/UI/Screens/Words/NotebookDetailView.swift:71`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/UI/Screens/Words/CreateNotebookView.swift:51`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/UI/Screens/Words/AddNotebookWordView.swift:181`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/UI/Screens/Words/AddNotebookWordView.swift:191`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/UI/Screens/Words/NotebookPickerSheetView.swift:23`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/UI/Screens/Words/NotebookPickerSheetView.swift:40`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/UI/Screens/Words/NotebookWordDetailView.swift:35`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/UI/Screens/Words/WordDetailView.swift:18`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/UI/Screens/Words/WordDetailView.swift:72`

### ReviewWordStore consumers
- `WordListViewModel`
  - owns `ReviewWordStore`
  - subscribes to `reviewWordIds`
  - toggles review state directly
- `WordDetailViewModel`
  - owns `ReviewWordStore`
  - subscribes to `reviewWordIds`
  - toggles review state directly
- Code:
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/UI/Screens/Words/WordListViewModel.swift:45`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/UI/Screens/Words/WordListViewModel.swift:52`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/UI/Screens/Words/WordListViewModel.swift:149`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/UI/Screens/Words/WordDetailViewModel.swift:13`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/UI/Screens/Words/WordDetailViewModel.swift:18`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/UI/Screens/Words/WordDetailViewModel.swift:54`

## 5. Server migration change points

### A. Notebook persistence boundary
- Primary replacement target:
  - `NotebookStore`
- Why:
  - it currently mixes storage concern, mutation logic, duplicate policy, and published UI state
- Server migration impact:
  - `load()` and `save()` cannot remain `UserDefaults`-centric
  - mutation methods become async request boundaries
  - optimistic update / rollback policy must be defined

### B. ReviewWord persistence boundary
- Primary replacement target:
  - `ReviewWordStore`
- Why:
  - it is already a narrow abstraction around membership changes
- Server migration impact:
  - `loadReviewSet`, `add`, `remove`, `toggle`, `saveReviewSet` should no longer directly read/write `UserDefaults`
  - review state refresh timing must become explicit

### C. ViewModel mutation flow
- `WordListViewModel` and `WordDetailViewModel` currently assume review mutations are synchronous and instantly reflected.
- When switched to server-backed stores, the following behavior must change:
  - direct toggle without loading state
  - immediate success haptic regardless of request result
  - no retry or rollback path
- Code:
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/UI/Screens/Words/WordListViewModel.swift:149`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/UI/Screens/Words/WordListViewModel.swift:173`
  - `apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/UI/Screens/Words/WordDetailViewModel.swift:54`

### D. Notebook UI mutation flow
- The notebook-related SwiftUI views currently call store mutation methods directly.
- This is acceptable for local state, but it couples UI to persistence semantics.
- Server-backed migration will be easier if notebook actions move behind a dedicated ViewModel or repository-facing facade.
- Highest-friction files:
  - `NotebookDetailView`
  - `AddNotebookWordView`
  - `CreateNotebookView`
  - `NotebookPickerSheetView`
  - `NotebookWordDetailView`

### E. ID model mismatch to resolve before API work
- Local notebook ID: `UUID`
- Local notebook item ID: `UUID`
- Review item identity: `wordId: Int`
- Manual notebook item identity: no dictionary `wordId`
- Before server wiring, decide whether:
  - server also uses UUID for notebook/item IDs
  - or app adds separate `serverId` fields
- Without this decision, update/delete sync will be fragile.

### F. Manual word payload definition
- Manual notebook words currently have enough data for creation, but not enough sync metadata.
- Likely missing future fields:
  - server item ID
  - sync state
  - updatedAt
  - deletedAt or soft-delete handling
  - ownership / author metadata if shared notebooks are planned

## 6. Keep vs change

### Keep
- `WordNotebook` / `WordNotebookItem` as UI-facing models are mostly usable.
- `wordId: Int?` is the right current shape for distinguishing dictionary-backed vs manual notebook items.
- `WordListItem.Source` split between JLPT and notebook is still useful for navigation and rendering.
- Search/filter/sort logic in `WordListViewModel` can mostly remain if it receives notebook data from a new source.
- SwiftUI screens and presentation flow can mostly remain if mutation APIs are surfaced cleanly.

### Change
- `NotebookStore` persistence implementation
- `ReviewWordStore` persistence implementation
- direct synchronous mutation assumptions in `WordListViewModel`
- direct synchronous mutation assumptions in `WordDetailViewModel`
- direct store mutation from notebook-related views
- duplicate enforcement policy location
  - currently local store-side
  - later should be aligned with server contract

## 7. Recommended preparation sequence

### Step 1
- Introduce protocol boundaries first, without API implementation.
- Suggested split:
  - `NotebookRepositoryProtocol`
  - `ReviewWordRepositoryProtocol`

### Step 2
- Make notebook and review mutations async at the boundary.
- Even if the first implementation remains local, the call shape should match future server behavior.

### Step 3
- Move notebook mutation orchestration out of SwiftUI views.
- Minimal candidates:
  - `NotebookListViewModel`
  - `NotebookDetailViewModel`
  - `AddNotebookWordViewModel`

### Step 4
- Decide server identity strategy.
- Recommended minimum:
  - preserve local `UUID` for SwiftUI identity
  - add optional server IDs to notebook and notebook item models

### Step 5
- Define explicit server DTO split:
  - notebook
  - notebook item from dictionary word
  - notebook item from manual word
  - review word membership

## 8. Practical conclusion
- `ReviewWordStore` is the easier migration target because the shape is already `Set<wordId>`.
- `NotebookStore` is the bigger migration target because it currently owns:
  - persistence
  - duplicate rules
  - notebook/item mutation rules
  - UI publication
- The largest structural risk is not API calling itself.
- The larger risk is that notebook-related SwiftUI views currently mutate the store directly, which makes async server behavior harder to layer in cleanly.
