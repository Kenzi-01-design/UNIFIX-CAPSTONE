import { describe, expect, it } from 'vitest'
import { encodeCsv } from './csv.js'

describe('encodeCsv', () => {
  it('quotes and escapes cells containing CSV syntax', () => {
    expect(encodeCsv([['Title', 'A, "quoted" title']]))
      .toBe('"Title","A, ""quoted"" title"')
  })

  it('neutralizes spreadsheet formulas, including whitespace-prefixed values', () => {
    expect(encodeCsv([['=1+1', ' +SUM(A1:A2)', '-2', '@cmd']]))
      .toBe('"\'=1+1","\' +SUM(A1:A2)","\'-2","\'@cmd"')
  })
})
