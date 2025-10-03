#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use once_cell::sync::Lazy;
use regex::Regex;
use rusqlite::{Connection, OpenFlags};
use serde::Serialize;
use std::{path::{Path, PathBuf}, sync::Mutex};

static DB: Lazy<Mutex<Option<Connection>>> = Lazy::new(|| Mutex::new(None));

#[derive(Serialize)]
struct Rec {
  id: i64,
  telefono: Option<String>,
  idfb: Option<String>,
  nome: Option<String>,
  cognome: Option<String>,
  sesso: Option<String>,
  natoa: Option<String>,
  residente: Option<String>,
  statocivile: Option<String>,
  azienda: Option<String>,
  dataAcc: Option<String>,
  niente: Option<String>,
  niente2: Option<String>,
}

fn find_db_path() -> PathBuf {
  // punto di partenza: cartella dell'eseguibile
  let mut dirs: Vec<PathBuf> = vec![];
  if let Ok(exe) = std::env::current_exe() {
    if let Some(exe_dir) = exe.parent() {
      // build (release):  <exe>/../data/db.sqlite
      dirs.push(exe_dir.join("..").join("data").join("db.sqlite"));
      // dev (cargo run):  <exe>/../../data/db.sqlite
      dirs.push(exe_dir.join("..").join("..").join("data").join("db.sqlite"));
      // dev (un altro caso): <exe>/../../../data/db.sqlite
      dirs.push(exe_dir.join("..").join("..").join("..").join("data").join("db.sqlite"));
    }
  }
  // fallback: project root (se eseguito da repo)
  if let Ok(cwd) = std::env::current_dir() {
    dirs.push(cwd.join("data").join("db.sqlite"));
    dirs.push(cwd.join("..").join("data").join("db.sqlite"));
  }

  for p in dirs {
    if p.exists() { return p; }
  }
  // ultimo fallback: quello "classico" (magari verrà creato vuoto, ma almeno il path è coerente)
  PathBuf::from("data/db.sqlite")
}

fn open_db(_app: &tauri::AppHandle) -> Result<(), String> {
  let candidate = find_db_path();
  if !candidate.exists() {
    return Err(format!("db.sqlite non trovato. Percorso provato: {}", candidate.display()));
  }

  let db_path = candidate.canonicalize().unwrap_or(candidate);
  let mut guard = DB.lock().map_err(|_| "DB mutex poisoned".to_string())?;
  if guard.is_none() {
    let conn = Connection::open_with_flags(db_path, OpenFlags::SQLITE_OPEN_READ_ONLY)
      .map_err(|e| format!("open db failed: {e}"))?;

    // PRAGMAs sicure in read-only
    conn.pragma_update(None, "cache_size", &-400000i64).map_err(|e| e.to_string())?;
    conn.pragma_update(None, "temp_store", &"MEMORY").map_err(|e| e.to_string())?;
    conn.pragma_update(None, "mmap_size", &30000000000i64).map_err(|e| e.to_string())?;

    *guard = Some(conn);
  }
  Ok(())
}

fn sanitize_match(s: &str) -> String {
  let re = Regex::new(r#"[^0-9A-Za-z_\*\s"]+"#).unwrap();
  re.replace_all(s, " ").to_string()
}

#[tauri::command]
fn search_records(
  app: tauri::AppHandle,
  q: String,
  fts: String,
  isPhone: bool,
  sesso: String,
  residente: String,
  page: i64,
  pageSize: i64
) -> Result<serde_json::Value, String>
{
  open_db(&app)?;
  let guard = DB.lock().map_err(|_| "DB mutex poisoned".to_string())?;
  let conn = guard.as_ref().ok_or("DB connection not initialized")?;

  let limit = pageSize.max(1);
  let offset = (page.max(1) - 1) * limit;

  let mut where_sql = String::from("1=1");
  let mut params: Vec<rusqlite::types::Value> = Vec::new();

  if !sesso.trim().is_empty() {
    where_sql.push_str(" AND r.sesso = ? ");
    params.push(rusqlite::types::Value::Text(sesso.clone()));
  }
  if !residente.trim().is_empty() {
    where_sql.push_str(" AND r.residente LIKE ? ");
    params.push(rusqlite::types::Value::Text(format!("%{}%", residente.trim())));
  }

  let use_fts = !fts.trim().is_empty() && !isPhone;

  let (count_sql, select_sql, params_count, mut params_select) = if isPhone && !q.trim().is_empty() {
    where_sql.push_str(" AND r.telefono LIKE ? ");
    params.push(rusqlite::types::Value::Text(format!("%{}%", q.trim().replace(' ', ""))));
    (
      format!("SELECT COUNT(*) FROM records r WHERE {}", where_sql),
      format!(r#"
        SELECT r.id, r.telefono, r.idfb, r.nome, r.cognome, r.sesso, r.natoa, r.residente,
               r.statocivile, r.azienda, r.dataAcc, r.niente, r.niente2
        FROM records r
        WHERE {where_sql}
        ORDER BY r.id
        LIMIT ? OFFSET ?
      "#),
      params.clone(),
      params.clone()
    )
  } else if use_fts {
    where_sql.push_str(" AND r.id = f.rowid AND records_fts MATCH ? ");
    let m = sanitize_match(&fts);
    params.push(rusqlite::types::Value::Text(m));
    (
      format!("SELECT COUNT(*) FROM records r JOIN records_fts f ON f.rowid=r.id WHERE {}", where_sql),
      format!(r#"
        SELECT r.id, r.telefono, r.idfb, r.nome, r.cognome, r.sesso, r.natoa, r.residente,
               r.statocivile, r.azienda, r.dataAcc, r.niente, r.niente2
        FROM records r
        JOIN records_fts f ON f.rowid=r.id
        WHERE {where_sql}
        ORDER BY r.id
        LIMIT ? OFFSET ?
      "#),
      params.clone(),
      params.clone()
    )
  } else {
    if !q.trim().is_empty() {
      where_sql.push_str(" AND ( r.cognome LIKE ? OR r.nome LIKE ? OR r.azienda LIKE ? OR r.residente LIKE ? ) ");
      let like = format!("%{}%", q.trim());
      params.push(rusqlite::types::Value::Text(like.clone()));
      params.push(rusqlite::types::Value::Text(like.clone()));
      params.push(rusqlite::types::Value::Text(like.clone()));
      params.push(rusqlite::types::Value::Text(like));
    }
    (
      format!("SELECT COUNT(*) FROM records r WHERE {}", where_sql),
      format!(r#"
        SELECT r.id, r.telefono, r.idfb, r.nome, r.cognome, r.sesso, r.natoa, r.residente,
               r.statocivile, r.azienda, r.dataAcc, r.niente, r.niente2
        FROM records r
        WHERE {where_sql}
        ORDER BY r.id
        LIMIT ? OFFSET ?
      "#),
      params.clone(),
      params.clone()
    )
  };

  // COUNT
  let mut stmt = conn.prepare(&count_sql).map_err(|e| e.to_string())?;
  let total: i64 = stmt
    .query_row(rusqlite::params_from_iter(params_count.iter()), |row| row.get(0))
    .map_err(|e| e.to_string())?;

  // SELECT
  params_select.push(rusqlite::types::Value::Integer(limit.into()));
  params_select.push(rusqlite::types::Value::Integer(offset.into()));

  let mut stmt = conn.prepare(&select_sql).map_err(|e| e.to_string())?;
  let mut rows_iter = stmt
    .query(rusqlite::params_from_iter(params_select.iter()))
    .map_err(|e| e.to_string())?;

  let mut out: Vec<Rec> = Vec::with_capacity(limit as usize);
  while let Some(row) = rows_iter.next().map_err(|e| e.to_string())? {
    out.push(Rec{
      id: row.get(0).unwrap_or_default(),
      telefono: row.get(1).ok(),
      idfb: row.get(2).ok(),
      nome: row.get(3).ok(),
      cognome: row.get(4).ok(),
      sesso: row.get(5).ok(),
      natoa: row.get(6).ok(),
      residente: row.get(7).ok(),
      statocivile: row.get(8).ok(),
      azienda: row.get(9).ok(),
      dataAcc: row.get(10).ok(),
      niente: row.get(11).ok(),
      niente2: row.get(12).ok(),
    });
  }

  Ok(serde_json::json!({ "total": total, "rows": out }))
}

fn main() {
  tauri::Builder::default()
    .invoke_handler(tauri::generate_handler![search_records])
    .run(tauri::generate_context!())
    .expect("error while running tauri app");
}
