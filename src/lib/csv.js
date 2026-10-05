export function encodeCsv(rows) {
  return rows
    .map((row) => row.map((value) => {
      const text = String(value ?? '')
      const safe = /^[\t\r\n ]*[=+\-@]/.test(text) ? `'${text}` : text
      return `"${safe.replaceAll('"', '""')}"`
    }).join(','))
    .join('\r\n')
}
