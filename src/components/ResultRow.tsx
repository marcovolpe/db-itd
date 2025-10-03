import React, { useState } from "react";
import { displayPhone } from "../lib/phone";
import { parseBirthFromExtra } from "../lib/birth";

export type Rec = {
  id: number;
  telefono: string | null;
  idfb: string | null;      // non mostrato
  nome: string | null;
  cognome: string | null;
  sesso: string | null;
  natoa: string | null;     // Località di nascita
  residente: string | null; // Località di residenza
  statocivile: string | null;
  azienda: string | null;
  dataAcc: string | null;   // non mostrato
  niente: string | null;
  niente2: string | null;   // extra (potrebbe contenere info su data di nascita)
};

export default function ResultRow({ rec }: { rec: Rec }){
  const [copied, setCopied] = useState(false);

  const fullName = [rec.nome, rec.cognome].filter(Boolean).join(" ") || "(Senza nome)";
  const phoneShown = rec.telefono ? displayPhone(rec.telefono) : "";

  const birthExtra = parseBirthFromExtra(rec.niente2);
  const hasExtras = birthExtra.extras.length > 0;

  const handleCopy = async () => {
    if (!phoneShown) return;
    try {
      await navigator.clipboard.writeText(phoneShown);
      setCopied(true);
      setTimeout(() => setCopied(false), 1200);
    } catch { /* ignore */ }
  };

  return (
    <div className="item">
      <div style={{display:'flex',justifyContent:'space-between',gap:12,alignItems:'flex-start'}}>
        <div style={{flex:1,minWidth:0}}>
          <strong style={{fontSize:18}}>{fullName}</strong>

          {/* Riga info chiave in due colonne responsive */}
          <div style={{display:'grid', gap:6, gridTemplateColumns:'repeat(auto-fit,minmax(260px,1fr))', marginTop:6}}>
            <div className="muted">
              <span style={{fontWeight:600}}>Nato/a a:</span>{" "}
              {rec.natoa && rec.natoa.trim() !== "" ? rec.natoa : "—"}
              {birthExtra.dob && (
                <>
                  {" "}· <span style={{fontWeight:600}}>il</span> {birthExtra.dob}
                </>
              )}
            </div>

            <div className="muted">
              <span style={{fontWeight:600}}>Residente a:</span>{" "}
              {rec.residente && rec.residente.trim() !== "" ? rec.residente : "—"}
            </div>
          </div>

          {/* Azienda sotto, se presente */}
          <div className="muted" style={{marginTop:6}}>
            <span style={{fontWeight:600}}>Azienda:</span>{" "}
            {rec.azienda && rec.azienda.trim() !== "" ? rec.azienda : "—"}
          </div>

          {/* Extra legati alla nascita (altri token di niente2) */}
          {hasExtras && (
            <div style={{marginTop:8, display:'flex', flexWrap:'wrap', gap:6, alignItems:'center'}}>
              <span className="muted" style={{fontWeight:600}}>Altri dati nascita:</span>
              {birthExtra.extras.map((t, i) => (
                <span key={i} className="pill">{t}</span>
              ))}
            </div>
          )}

          {/* Sesso + Telefono con copia */}
          <div className="muted" style={{marginTop:8, display:'flex', gap:8, alignItems:'center', flexWrap:'wrap'}}>
            <span className="pill">{rec.sesso || "n/d"}</span>

            {phoneShown ? (
              <span style={{display:'inline-flex', alignItems:'center', gap:8}}>
                <span className="pill">{phoneShown}</span>
                <button
                  onClick={handleCopy}
                  title="Copia numero"
                  style={{padding:'6px 10px', fontSize:14}}
                >
                  {copied ? "Copiato ✓" : "Copia"}
                </button>
              </span>
            ) : null}
          </div>
        </div>

        {/* Colonna destra vuota (niente idfb/dataAcc) solo per allineamento */}
        <div style={{minWidth:12}} />
      </div>
    </div>
  );
}
