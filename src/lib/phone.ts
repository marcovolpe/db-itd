// Utility per formattare la visualizzazione del telefono con prefisso "+".
// Regole:
// - se parte con "+", lo lasciamo com'è
// - se parte con "00", lo convertiamo in "+" (es. 0039... -> +39...)
// - se parte con "39", aggiungiamo "+39..." (senza toccare il resto)
// - altrimenti, prefix "+39" al numero ripulito
export function displayPhone(raw: string): string {
  const t = raw.trim();
  if (!t) return "";
  if (t.startsWith("+")) return t;

  const digits = t.replace(/[^\d]/g, "");
  if (!digits) return "";

  if (digits.startsWith("00")) return "+" + digits.slice(2);
  if (digits.startsWith("39")) return "+" + digits;

  return "+39" + digits;
}
