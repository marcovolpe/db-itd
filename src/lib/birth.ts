// Parser semplici per estrarre la Data di Nascita e altri extra da "niente2".

const monthMap: Record<string, string> = {
  "gennaio": "01","febbraio": "02","marzo": "03","aprile": "04","maggio": "05","giugno": "06",
  "luglio": "07","agosto": "08","settembre": "09","ottobre": "10","novembre": "11","dicembre": "12",
  "gen": "01","feb": "02","mar": "03","apr": "04","mag": "05","giu": "06",
  "lug": "07","ago": "08","set": "09","ott": "10","nov": "11","dic": "12"
};

function pad2(n: number) {
  return n < 10 ? `0${n}` : String(n);
}

function isValidY(y: number) {
  return y >= 1900 && y <= 2025;
}
function isValidDM(d: number, m: number) {
  return d >= 1 && d <= 31 && m >= 1 && m <= 12;
}

// 1) prova pattern numerici classici
function extractNumericDate(s: string): string | undefined {
  // dd/mm/yyyy o dd-mm-yyyy
  const m1 = s.match(/\b(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})\b/);
  if (m1) {
    const d = parseInt(m1[1], 10), m = parseInt(m1[2], 10), y = parseInt(m1[3], 10);
    if (isValidY(y) && isValidDM(d, m)) return `${pad2(d)}/${pad2(m)}/${y}`;
  }
  // yyyy-mm-dd o yyyy/mm/dd
  const m2 = s.match(/\b(19|20)\d{2}[\/\-](\d{1,2})[\/\-](\d{1,2})\b/);
  if (m2) {
    const y = parseInt(m2[0].slice(0,4),10);
    const rest = m2[0].slice(5);
    const m = parseInt(rest.split(/[\/\-]/)[0],10);
    const d = parseInt(rest.split(/[\/\-]/)[1],10);
    if (isValidY(y) && isValidDM(d, m)) return `${pad2(d)}/${pad2(m)}/${y}`;
  }
  return undefined;
}

// 2) prova pattern con mese testuale in italiano (es. "13 dicembre 1980", "3 gen 1975")
function extractItalianTextualDate(s: string): string | undefined {
  const re = new RegExp(`\\b(\\d{1,2})\\s+(${Object.keys(monthMap).join("|")})\\s+(\\d{4})\\b`, "i");
  const m = s.match(re);
  if (!m) return undefined;
  const d = parseInt(m[1],10);
  const monKey = m[2].toLowerCase();
  const y = parseInt(m[3],10);
  const mm = monthMap[monKey];
  if (mm && isValidY(y) && isValidDM(d, parseInt(mm,10))) return `${pad2(d)}/${mm}/${y}`;
  return undefined;
}

export function parseBirthFromExtra(extraRaw?: string): { dob?: string; extras: string[] } {
  if (!extraRaw) return { extras: [] };

  // Tokenizza sugli ":" (come sono stati concatenati), pulendo spazi
  const tokens = extraRaw.split(":").map(t => t.trim()).filter(t => t.length > 0);

  // Prova a estrarre la data da tutta la stringa
  const joined = tokens.join(" ");
  let dob = extractNumericDate(joined);
  if (!dob) dob = extractItalianTextualDate(joined);

  // Rimuovi dal set di extras i token che sono evidentemente la data già catturata
  const extras = tokens.filter(t => {
    if (!dob) return true;
    return !t.includes(dob) && !/(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{4})|(19|20)\d{2}[\/\-]\d{1,2}[\/\-]\d{1,2}/.test(t);
  });

  return { dob, extras };
}
