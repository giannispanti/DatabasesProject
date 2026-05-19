from __future__ import annotations

import csv
import re
import sys
from pathlib import Path

import pandas as pd
from bs4 import BeautifulSoup

ROOT = Path(__file__).resolve().parent
REFS = ROOT / "refs"
OUT = ROOT / "csv"
OUT.mkdir(exist_ok=True)

ICD10_RE = re.compile(r"^[A-Z][0-9]{2}(\.[0-9A-Z]{1,4})?[\+\*]?$")

# ICD-10

def preprocess_icd10() -> None:
    # Διαχωρίζουμε ICD-10 σε ΔΙΑΓΝΩΣΗ (όχι R-codes) και ΣΥΜΠΤΩΜΑ (R-codes).
    
    df = pd.read_excel(REFS / "icd10.xls", sheet_name=0, header=None,
                       names=["code", "description"])
    df["code"] = df["code"].astype(str).str.strip().str.upper()
    df["description"] = df["description"].astype(str).str.strip()
    df = df[df["code"].str.match(ICD10_RE)]
    df = df[df["description"].str.len() > 0]
    df = df.drop_duplicates(subset=["code"])

    sumptoma = df[df["code"].str.match(r"^R[0-9]{2}")].copy()
    diagnosi = df[~df["code"].str.match(r"^R[0-9]{2}")].copy()

    diagnosi.to_csv(OUT / "diagnosi.csv", index=False, quoting=csv.QUOTE_MINIMAL, encoding="utf-8",
                lineterminator='\n')

    sumptoma.insert(0, "id", range(1, len(sumptoma) + 1))
    sumptoma["category"] = "ICD-10 R-block"
    sumptoma[["id", "description", "category"]].to_csv(
        OUT / "sumptoma.csv", index=False,
        quoting=csv.QUOTE_MINIMAL, encoding="utf-8",
        lineterminator='\n')

    print(f"  diagnosi.csv: {len(diagnosi)} rows")
    print(f"  sumptoma.csv: {len(sumptoma)} rows")


# ΚΕΝ

def preprocess_ken() -> None:
    

    # Η δομή κάθε γραμμής στο DOC είναι: [κωδικός ΚΕΝ | περιγραφή ΚΕΝ | ΜΔΝ | κόστος | ...]
    
    html = (REFS / "ken.html").read_text(encoding="utf-8", errors="replace")
    soup = BeautifulSoup(html, "lxml")
    rows: list[tuple[str, str, int]] = []
    code_re = re.compile(r"^[A-Za-zΑ-Ωα-ω][0-9]{2}[A-Za-zΑ-Ωα-ω]{0,3}$")  # Greek pattern για ΚΕΝ

    for table in soup.find_all("table"):
        for tr in table.find_all("tr"):
            cells = [td.get_text(" ", strip=True) for td in tr.find_all("td")]
            if len(cells) < 3:
                continue
            code = cells[0].strip()
            if not code_re.match(code):
                continue
            title = re.sub(r"\s+", " ", cells[1]).strip()
            # Βρίσκουμε το πρώτο integer cell σαν ΜΔΝ
            mdn = None
            for c in cells[2:]:
                c_clean = c.replace(".", "").replace(",", "").strip()
                if c_clean.isdigit() and 1 <= int(c_clean) <= 999:
                    mdn = int(c_clean)
                    break
            if mdn is None:
                mdn = 5  # default αν δεν βρεθεί
            if title:
                rows.append((code, title[:200], mdn))

    # setup
    seen = set()
    unique = []
    for code, title, mdn in rows:
        if code in seen:
            continue
        seen.add(code)
        unique.append((code, title, mdn))

    with (OUT / "ken.csv").open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, quoting=csv.QUOTE_MINIMAL, lineterminator='\n')
        w.writerow(["code", "title", "description", "mdn"])
        for code, title, mdn in unique:
            w.writerow([code, title, title, mdn])
    print(f"  ken.csv: {len(unique)} rows")


# EMA Φάρμακα

def preprocess_ema() -> None:
    # Διάβασμα: header στη γραμμή 20 (0-based 19), data από γραμμή 21
    df = pd.read_excel(REFS / "ema_article57.xlsx", sheet_name=0,
                       skiprows=19, header=0)
    df.columns = ["product_name", "active_substance", "route",
                  "country", "mah", "pv_location", *df.columns[6:]]
    df = df[["product_name", "active_substance", "route", "country"]]
    df["route"] = df["route"].fillna("Γενικό").astype(str).str.strip()
    df = df.dropna(subset=["product_name", "active_substance"])
    df["product_name"] = df["product_name"].astype(str).str.strip()
    df["active_substance"] = df["active_substance"].astype(str).str.strip()
    df = df[df["product_name"].str.len() > 0]

    drugs = df.reset_index(drop=True)
    drugs["ema_code"] = ["EMA-" + str(i + 1).zfill(5) for i in range(len(drugs))]

    # Έξοδος ΦΑΡΜΑΚΟ
    with (OUT / "farmako.csv").open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, quoting=csv.QUOTE_MINIMAL, lineterminator='\n')
        w.writerow(["ema_code", "name", "category"])
        for _, r in drugs.iterrows():
            w.writerow([
                r["ema_code"],
                str(r["product_name"])[:150],
                str(r["route"])[:150] 
            ])

    drugs["substances"] = drugs["active_substance"].astype(str).str.split("|")
    exploded = drugs[["ema_code", "substances"]].explode("substances")

    # Καθαρισμός από κενά και αφαίρεση άδειων εγγραφών
    exploded["substances"] = exploded["substances"].str.strip()
    exploded = exploded[exploded["substances"].str.len() > 0]
    exploded = exploded[~exploded["substances"].isin(["nan", "None", "NULL"])] # Διώχνει τα σκουπίδια της Pandas

    # Unique substances 
    unique_subs = sorted(exploded["substances"].unique())
    sub_to_code = {s: "DO-" + str(i + 1).zfill(5) for i, s in enumerate(unique_subs)}

    # ΕΞΟΔΟΣ ΔΡΑΣΤΙΚΗ_ΟΥΣΙΑ (Με χρήση κατηγορίας από το Route) ---
    with (OUT / "drastiki_ousia.csv").open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, quoting=csv.QUOTE_MINIMAL, lineterminator='\n')
        w.writerow(["code", "name", "category"])
        for s in unique_subs:
            w.writerow([sub_to_code[s], s[:200], "Φαρμακευτική Ουσία"])

    # M:N ΔΡΑΣΤΙΚΕΣ_ΟΥΣΙΕΣ_ΦΑΡΜΑΚΟΥ
    with (OUT / "drastikes_farmakou.csv").open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, quoting=csv.QUOTE_MINIMAL, lineterminator='\n')
        w.writerow(["ema_code", "substance_code"])
        seen_pairs = set()
        for _, r in exploded.iterrows():
            sub_name = str(r["substances"]).strip()  # Καθαρίζουμε τυχόν κενά
            # Χρησιμοποιούμε το καθαρό sub_name για να βρούμε το ID
            pair = (r["ema_code"], sub_to_code[sub_name]) 
            # --------------------------------
            if pair in seen_pairs:
                continue
            seen_pairs.add(pair)
            w.writerow(pair)

    print(f"  farmako.csv: {len(drugs)} rows")
    print(f"  drastiki_ousia.csv: {len(unique_subs)} rows")
    print(f"  drastikes_farmakou.csv: {len(seen_pairs)} rows")


# Ιατρικές πράξεις

def preprocess_praxeis() -> None:
    """Διαχωρίζει σε:
        - epemvasi_catalog.csv   (Κατ. Γ, Δ, Ε)
        - ergastiriaki_catalog.csv (Κατ. Α, Β)
    """
    df = pd.read_excel(REFS / "iatrikes_praxeis.xls", sheet_name="ΤΕΛΙΚΟ",
                       header=None, names=["aa", "code", "name"])
    cat_re = re.compile(r"^\s*([Α-Ε])\.\s+")
    current_cat = None
    rows: list[tuple[str, str, str]] = []
    for _, r in df.iterrows():
        a, code, name = r["aa"], r["code"], r["name"]
        if pd.isna(code) and isinstance(a, str):
            m = cat_re.match(a)
            if m:
                current_cat = m.group(1)
            continue
        if pd.isna(code) or pd.isna(name):
            continue
        code = str(code).strip()
        name_s = re.sub(r"\s+", " ", str(name)).strip()
        if not code or not name_s or not current_cat:
            continue
        if name_s.upper() == "ΑΝΕΝΕΡΓΟΣ":
            continue
        rows.append((current_cat, code, name_s[:200]))

    with (OUT / "epemvasi_catalog.csv").open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, quoting=csv.QUOTE_MINIMAL, lineterminator='\n')
        w.writerow(["code", "category", "name"])
        n = 0
        CAT_MAP = {"Γ": "ΧΕΙΡΟΥΡΓΙΚΗ", "Δ": "ΔΙΑΓΝΩΣΤΙΚΗ", "Ε": "ΘΕΡΑΠΕΥΤΙΚΗ"}

        for cat, code, name in rows:
            if cat in ("Γ", "Δ", "Ε"):
                w.writerow([code, CAT_MAP[cat], name[:25]]) 
                n += 1
        print(f"  epemvasi_catalog.csv: {n} rows")

    with (OUT / "ergastiriaki_catalog.csv").open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, quoting=csv.QUOTE_MINIMAL, lineterminator='\n')
        w.writerow(["code", "category", "name"])
        n = 0
        for cat, code, name in rows:
            if cat in ("Α", "Β"):
                w.writerow([code, f"Κατηγορία {cat}", name])
                n += 1
        print(f"  ergastiriaki_catalog.csv: {n} rows")


# ICD ↔ ΚΕΝ map

def preprocess_icd_ken_map() -> None:
    try:
        df = pd.read_csv(REFS / "icd_ken_map.csv", header=0)
    except Exception as e:
        print(f"  icd_ken_map.csv: skipped ({e})")
        return
    # Κρατάμε τις δύο πρώτες στήλες που έχουν strings
    rows = []
    for _, r in df.iterrows():
        vals = [str(v).strip() for v in r.tolist() if pd.notna(v)]
        if len(vals) >= 2:
            # Βρίσκουμε το ICD-10 (regex match) και το ΚΕΝ
            icd = next((v for v in vals if ICD10_RE.match(v)), None)
            ken = next((v for v in vals if re.match(r"^[Α-Ωα-ω][0-9]{2}[Α-Ωα-ω]{0,3}?$", v)), None)
            if icd and ken:
                rows.append((icd, ken))
    rows = list(set(rows))
    with (OUT / "icd_ken_map.csv").open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, quoting=csv.QUOTE_MINIMAL, lineterminator='\n')
        w.writerow(["icd10", "ken"])
        for icd, ken in rows:
            w.writerow([icd, ken])
    print(f"  icd_ken_map.csv: {len(rows)} rows")


# main

def main() -> int:
    print("==> Preprocessing reference files")
    print("[1/5] ICD-10")
    preprocess_icd10()
    print("[2/5] ΚΕΝ (από HTML)")
    preprocess_ken()
    print("[3/5] EMA Article 57")
    preprocess_ema()
    print("[4/5] Ιατρικές πράξεις")
    preprocess_praxeis()
    print("[5/5] ICD ↔ ΚΕΝ map (optional)")
    preprocess_icd_ken_map()
    print("==> Έτοιμο. CSVs στο", OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())


"""
Διαβάζει τα αρχεία αναφοράς από refs/ και παράγει καθαρά CSV στο csv/,
έτοιμα για LOAD DATA INFILE.

Output αρχεία:
    csv/diagnosi.csv            ΔΙΑΓΝΩΣΗ (όλα τα ICD-10 codes ΕΚΤΟΣ από R)
    csv/sumptoma.csv            ΣΥΜΠΤΩΜΑ (μόνο R-codes)
    csv/ken.csv                 ΚΕΝ (parsed από ken.html)
    csv/farmako.csv             ΦΑΡΜΑΚΟ
    csv/drastiki_ousia.csv      ΔΡΑΣΤΙΚΗ_ΟΥΣΙΑ (unique active substances)
    csv/drastikes_farmakou.csv  ΔΡΑΣΤΙΚΕΣ_ΟΥΣΙΕΣ_ΦΑΡΜΑΚΟΥ (M:N)
    csv/epemvasi_catalog.csv    ΕΠΕΜΒΑΣΗ κατάλογος (κατηγορίες Γ/Δ/Ε)
    csv/ergastiriaki_catalog.csv ΕΡΓΑΣΤΗΡΙΑΚΗ ΕΞΕΤΑΣΗ κατάλογος (Α/Β)
    csv/icd_ken_map.csv         mapping ICD-10 → ΚΕΝ (για ΝΟΣΗΛΕΙΑ)
"""