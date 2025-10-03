import React, { useEffect, useMemo, useState } from "react";
import SearchBar from "./components/SearchBar";
import ResultRow, { Rec } from "./components/ResultRow";
import { invoke } from "@tauri-apps/api/core";
import { buildFtsQuery, looksLikePhone } from "./lib/fts";

export default function App(){
  const [q,setQ] = useState("");
  const [sesso,setSesso] = useState("");
  const [residente,setResidente] = useState("");
  const [page,setPage] = useState(1);
  const [rows,setRows] = useState<Rec[]>([]);
  const [total,setTotal] = useState(0);
  const [loading,setLoading] = useState(false);
  const pageSize = 50;

  const prepared = useMemo(()=>{
    const isPhone = looksLikePhone(q);
    const fts = isPhone ? "" : buildFtsQuery(q);
    return { q, fts, isPhone };
  }, [q]);

  const doSearch = async()=>{
    setLoading(true);
    try{
      const res = await invoke<{ total:number, rows:Rec[] }>(
        "search_records",
        {
          q: prepared.q,
          fts: prepared.fts,
          isPhone: prepared.isPhone,
          sesso: sesso.trim(),
          residente: residente.trim(),
          page,
          pageSize
        }
      );
      setRows(res.rows);
      setTotal(res.total);
    } finally {
      setLoading(false);
    }
  };

  useEffect(()=>{ doSearch(); },[]);
  const maxPage = Math.max(1, Math.ceil(total/pageSize));

  return (
    <div className="container">
      <div className="topbar">
        <h1>Offline Finder</h1>
        <span className="badge">{total.toLocaleString()} risultati</span>
      </div>

      <SearchBar
        q={q} setQ={(v)=>{ setQ(v); }}
        sesso={sesso} setSesso={setSesso}
        residente={residente} setResidente={setResidente}
        onSearch={()=>{ setPage(1); doSearch(); }}
      />

      <div className="card results">
        {loading ? <p>Caricamento…</p> :
          rows.length === 0 ? <p>Nessun risultato. Prova con termini più generici.</p> :
          rows.map(r => <ResultRow key={r.id} rec={r} />)
        }
        <div className="pagination">
          <button disabled={page<=1} onClick={()=>{ setPage(p=>p-1); setTimeout(doSearch,0); }}>← Indietro</button>
          <span>Pagina {page} di {maxPage}</span>
          <button disabled={page>=maxPage} onClick={()=>{ setPage(p=>p+1); setTimeout(doSearch,0); }}>Avanti →</button>
        </div>
      </div>
    </div>
  );
}
