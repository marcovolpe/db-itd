import React from "react";

type Props = {
  q: string;
  setQ: (v: string) => void;
  sesso: string;
  setSesso: (v: string) => void;
  residente: string;
  setResidente: (v: string) => void;
  onSearch: () => void;
};

export default function SearchBar({ q, setQ, sesso, setSesso, residente, setResidente, onSearch }: Props){
  return (
    <div className="card">
      <div className="row">
        <input
          placeholder="Cerca per nome, cognome, città, azienda, idfb o telefono…"
          value={q}
          onChange={e=>setQ(e.target.value)}
          style={{flex:1,minWidth:280}}
          onKeyDown={e=>{ if(e.key==='Enter') onSearch() }}
          aria-label="Cerca"
        />
        <select value={sesso} onChange={e=>setSesso(e.target.value)} style={{minWidth:160}} aria-label="Filtro Sesso">
          <option value="">Tutti i sessi</option>
          <option value="male">Uomo</option>
          <option value="female">Donna</option>
        </select>
        <input
          placeholder="Residente (es. Milan, Italy)"
          value={residente}
          onChange={e=>setResidente(e.target.value)}
          style={{minWidth:240}}
          aria-label="Filtro Residenza"
          onKeyDown={e=>{ if(e.key==='Enter') onSearch() }}
        />
        <button onClick={onSearch}>Cerca</button>
      </div>
      <p className="muted" style={{marginTop:8}}>
        Suggerimenti: prova con meno parole. Puoi scrivere <code>ross*</code> per cercare “Rossi/Rossetti…”.
      </p>
    </div>
  );
}
