// Trasforma l'input utente in una query FTS più tollerante:
// - separa per spazi e punteggiatura
// - aggiunge * ai termini >= 3 lettere
// - unisce con AND per restringere (meglio per utenti poco digitalizzati)
export function buildFtsQuery(input: string): string {
  const terms = input
    .trim()
    .split(/[\s,.;:/\\]+/)
    .filter(Boolean)
    .map(t => t.length >= 3 ? `${t}*` : t);
  if (terms.length === 0) return "";
  return terms.join(" AND ");
}

// Semplice test per "sembra un telefono"
export function looksLikePhone(s: string): boolean {
  const t = s.replace(/[^\d+]/g, "");
  return t.length >= 7;
}
