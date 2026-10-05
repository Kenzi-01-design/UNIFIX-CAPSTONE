import { describe, expect, it } from 'vitest'
import { filterOfflineDraftsByScope } from './offlineReportDrafts.js'

describe('filterOfflineDraftsByScope', () => {
  it('only returns drafts belonging to the current browser session', () => {
    const drafts = [
      { id: 'one', ownerScope: 'session-one' },
      { id: 'two', ownerScope: 'session-two' },
      { id: 'legacy' }
    ]

    expect(filterOfflineDraftsByScope(drafts, 'session-one')).toEqual([drafts[0]])
  })
})
