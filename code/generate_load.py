# Παράγει το αρχείο load_data.sql

from __future__ import annotations

import csv
from multiprocessing import pool
import os
import random
import sys
from collections import defaultdict
from datetime import date, datetime, timedelta, time
from pathlib import Path
from typing import Iterable

import pandas as pd
from faker import Faker

# Paths / setup
ROOT = Path(__file__).resolve().parent
PROJECT_ROOT = ROOT.parent
CSV_DIR = ROOT / "csv"
OUT_FILE = PROJECT_ROOT / "load_data.sql"

fake = Faker("el_GR")
Faker.seed(42)
random.seed(42)

# Configuration

# Volumes
N_TMHMA = 15             # 15 τμήματα + 5 επιπλέον για κάλυψη πολλαπλών τμημάτων ανά ιατρό
N_DOCTORS = 300          # συμπεριλαμβάνει 15 διευθυντές
N_NURSES = 400
N_ADMIN = 100
N_BEDS_PER_DEPT = 20     # 20×15 = 300 κλίνες
N_ROOMS = 10
N_PATIENTS = 200
N_NOSILEIES = 1500
N_NOSILEIA_DAYS_SPAN = 1825      # ~5 χρόνια
NOSILEIES_START = date(2021, 5, 1) 
N_EFIMERIES_DAYS = 10     # 10 ημέρες × 15 τμήματα = 150 εφημερίες
# Standard base wait (minutes) ανά επίπεδο επείγοντος — για FIFO simulation
LEVEL_BASE_WAIT = {1: 90, 2: 60, 3: 30, 4: 15, 5: 2}
N_EPEMVASEIS = 750
N_LAB_TESTS = 200
N_PRESCRIPTIONS = 1200
N_TRIAGES = 3000
N_ALLERGIES = 100

# Doctor mix (sum must == N_DOCTORS)
N_DIEYTHYNTES = N_TMHMA       # 15  (ένας ανά τμήμα)
N_EPIM_A = 200                  # ΕΠΙΜΕΛΗΤΕΣ Α
N_EPIM_B = 45                  # ΕΠΙΜΕΛΗΤΕΣ Β
N_EIDIK = N_DOCTORS - N_DIEYTHYNTES - N_EPIM_A - N_EPIM_B  # 40 ΕΙΔΙΚΕΥΟΜΕΝΟΙ

# Shift staffing minimums (από triggers)
MIN_DOCTORS_PER_SHIFT = 3
MIN_NURSES_PER_SHIFT = 6
MIN_ADMIN_PER_SHIFT = 2

# Monthly caps (από triggers)
MAX_MONTHLY_SHIFTS = {
    "ΙΑΤΡΟΣ": 15,
    "ΝΟΣΗΛΕΥΤΗΣ": 20,
    "ΔΙΟΙΚΗΤΙΚΟ ΠΡΟΣΩΠΙΚΟ": 25,
}

INSURANCE_PROVIDERS = [
    ("ΕΦΚΑ", "Ηλεκτρονικός Εθνικός Φορέας Κοινωνικής Ασφάλισης"),
    ("ΕΟΠΥΥ", "Εθνικός Οργανισμός Παροχής Υπηρεσιών Υγείας"),
    ("GENERALI", "Generali Hellas"),
    ("INTERAMERICAN", "Interamerican"),
    ("NN", "NN Hellas"),
    ("ETHNIKI", "Εθνική Ασφαλιστική"),
    ("EUROLIFE", "Eurolife FFH"),
    ("METLIFE", "MetLife"),
    ("ALLIANZ", "Allianz Hellas"),
    ("ΑΝΑΣΦΑΛΙΣΤΟΣ", "Ανασφάλιστος"),
]

DEPARTMENT_NAMES = [
    "ΚΑΡΔΙΟΛΟΓΙΚΗ", "ΠΑΘΟΛΟΓΙΚΗ", "ΧΕΙΡΟΥΡΓΙΚΗ Α",
    "ΧΕΙΡΟΥΡΓΙΚΗ Β", "ΟΡΘΟΠΕΔΙΚΗ", "ΓΑΣΤΡΕΝΤΕΡΟΛΟΓΙΚΗ",
    "ΝΕΥΡΟΛΟΓΙΚΗ", "ΠΝΕΥΜΟΝΟΛΟΓΙΚΗ", "ΠΑΙΔΙΑΤΡΙΚΗ", "ΟΓΚΟΛΟΓΙΚΗ",
    "ΨΥΧΙΑΤΡΙΚΗ", "ΟΦΘΑΛΜΟΛΟΓΙΚΗ", "ΕΝΤΑΤΙΚΗ ΘΕΡΑΠΕΙΑ", "ΕΝΔΟΚΡΙΝΟΛΟΓΙΚΗ", "ΤΕΠ(ΤΜΗΜΑ ΕΠΕΙΓΟΝΤΩΝ ΠΕΡΙΣΤΑΤΙΚΩΝ)",
]

DOCTOR_SPECIALTIES = {
    "ΚΑΡΔΙΟΛΟΓΙΚΗ": "ΚΑΡΔΙΟΛΟΓΙΑ",
    "ΠΑΘΟΛΟΓΙΚΗ": "ΠΑΘΟΛΟΓΙΑ",
    "ΧΕΙΡΟΥΡΓΙΚΗ Α": "ΓΕΝΙΚΗ ΧΕΙΡΟΥΡΓΙΚΗ",
    "ΧΕΙΡΟΥΡΓΙΚΗ Β": "ΓΕΝΙΚΗ ΧΕΙΡΟΥΡΓΙΚΗ",
    "ΟΡΘΟΠΕΔΙΚΗ": "ΟΡΘΟΠΕΔΙΚΗ",
    "ΓΑΣΤΡΕΝΤΕΡΟΛΟΓΙΚΗ": "ΓΑΣΤΡΕΝΤΕΡΟΛΟΓΙΑ",
    "ΝΕΥΡΟΛΟΓΙΚΗ": "ΝΕΥΡΟΛΟΓΙΑ",
    "ΠΝΕΥΜΟΝΟΛΟΓΙΚΗ": "ΠΝΕΥΜΟΝΟΛΟΓΙΑ",
    "ΠΑΙΔΙΑΤΡΙΚΗ": "ΠΑΙΔΙΑΤΡΙΚΗ",
    "ΟΓΚΟΛΟΓΙΚΗ": "ΟΓΚΟΛΟΓΙΑ",
    "ΨΥΧΙΑΤΡΙΚΗ": "ΨΥΧΙΑΤΡΙΚΗ",
    "ΟΦΘΑΛΜΟΛΟΓΙΚΗ": "ΟΦΘΑΛΜΟΛΟΓΙΑ",
    "ΕΝΤΑΤΙΚΗ ΘΕΡΑΠΕΙΑ": "ΕΝΤΑΤΙΚΗ ΘΕΡΑΠΕΙΑ",
    "ΕΝΔΟΚΡΙΝΟΛΟΓΙΚΗ": "ΕΝΔΟΚΡΙΝΟΛΟΓΙΑ",
    "ΤΕΠ(ΤΜΗΜΑ ΕΠΕΙΓΟΝΤΩΝ ΠΕΡΙΣΤΑΤΙΚΩΝ)": "ΤΕΠ(ΤΜΗΜΑ ΕΠΕΙΓΟΝΤΩΝ ΠΕΡΙΣΤΑΤΙΚΩΝ)",
}

SHIFT_TYPES = ["ΠΡΩΙΝΗ", "ΑΠΟΓΕΥΜΑΤΙΝΗ", "ΝΥΧΤΕΡΙΝΗ"]
SHIFT_HOURS = {
    "ΠΡΩΙΝΗ":      ("07:00:00", "15:00:00", 0),  # next-day offset for end=0
    "ΑΠΟΓΕΥΜΑΤΙΝΗ": ("15:00:00", "23:00:00", 0),
    "ΝΥΧΤΕΡΙΝΗ":   ("23:00:00", "07:00:00", 1),
}

# SQL escape helpers

def sql_str(v) -> str:
    if v is None:
        return "NULL"
    if isinstance(v, (int, float)):
        return str(v)
    s = str(v).replace("\\", "\\\\").replace("'", "\\'")
    return f"'{s}'"


def insert(table: str, columns: list[str], rows: list[tuple]) -> str:
    if not rows:
        return ""
    out = [f"INSERT INTO {table} ({', '.join(columns)}) VALUES"]
    parts = []
    for r in rows:
        parts.append("(" + ", ".join(sql_str(v) for v in r) + ")")
    out.append(",\n".join(parts) + ";\n")
    return "\n".join(out)


def unique_amka_factory():
    used = set()
    def gen():
        while True:
            s = "".join(str(random.randint(0, 9)) for _ in range(11))
            if s[0] == "0":
                s = "1" + s[1:]
            if s not in used:
                used.add(s)
                return s
    return gen


def unique_email_factory():
    used = set()
    def gen(first: str, last: str, suffix: str = "hospital.gr") -> str:
        first_l = strip_greek(first).lower() or "user"
        last_l = strip_greek(last).lower() or "x"
        for i in range(1, 1000):
            email = f"{first_l}.{last_l}{i}@{suffix}"
            if email not in used:
                used.add(email)
                return email
        raise RuntimeError("email pool exhausted")
    return gen


_GR_TO_LATIN = {
    "α": "a", "ά": "a", "β": "v", "γ": "g", "δ": "d", "ε": "e", "έ": "e",
    "ζ": "z", "η": "i", "ή": "i", "θ": "th", "ι": "i", "ί": "i", "ϊ": "i",
    "ΐ": "i", "κ": "k", "λ": "l", "μ": "m", "ν": "n", "ξ": "x", "ο": "o",
    "ό": "o", "π": "p", "ρ": "r", "σ": "s", "ς": "s", "τ": "t", "υ": "y",
    "ύ": "y", "ϋ": "y", "ΰ": "y", "φ": "f", "χ": "ch", "ψ": "ps", "ω": "o",
    "ώ": "o",
}


def strip_greek(s: str) -> str:
    return "".join(_GR_TO_LATIN.get(ch.lower(), ch if ch.isalnum() else "") for ch in s)


def phone() -> str:
    return f"69{random.randint(10000000, 99999999)}"


def random_date(start: date, end: date) -> date:
    delta = (end - start).days
    return start + timedelta(days=random.randint(0, delta))

# Build everything

def build() -> None:
    out: list[str] = []
    out.append("-- ============================================================\n")
    out.append("-- load_data.sql — αυτογεννημένο από data_loader/generate_load.py\n")
    out.append(f"-- Δημιουργήθηκε: {datetime.now().isoformat(timespec='seconds')}\n")
    out.append("-- ============================================================\n\n")
    out.append("SET NAMES utf8mb4;\n")
    out.append("SET SESSION FOREIGN_KEY_CHECKS=0;\n")
    out.append("SET SESSION UNIQUE_CHECKS=0;\n\n")
    out.append("SET SESSION check_constraint_checks=0;\n")

    # ─────────────────────────────────────────────────────────────────────────
    # 1. Reference data via LOAD DATA INFILE
    out.append("-- ─── Reference data (LOAD DATA INFILE) ──────────────────\n")
    csv_dir_abs = str(CSV_DIR).replace("\\", "/")
    out.append(load_data_block(csv_dir_abs, "diagnosi.csv", "diagnosi",
                               ["ΚΩΔΙΚΟΣ_ICD10", "ΠΕΡΙΓΡΑΦΗ"]))
    out.append(load_data_block(csv_dir_abs, "sumptoma.csv", "symptoma",
                               ["ΚΩΔΙΚΟΣ_ΣΥΜΠΤΩΜΑΤΟΣ", "ΠΕΡΙΓΡΑΦΗ", "ΚΑΤΗΓΟΡΙΑ"]))
    out.append(load_data_block(csv_dir_abs, "ken.csv", "ken",
                               ["ΚΩΔΙΚΟΣ_ΚΕΝ", "ΤΙΤΛΟΣ", "ΠΕΡΙΓΡΑΦΗ", "ΜΔΝ"]))
    out.append(load_data_block(csv_dir_abs, "drastiki_ousia.csv", "drastiki_oysia",
                               ["ΚΩΔΙΚΟΣ_ΔΟ", "ΟΝΟΜΑ", "ΚΑΤΗΓΟΡΙΑ"]))
    out.append(load_data_block(csv_dir_abs, "farmako.csv", "farmako",
                               ["ΚΩΔΙΚΟΣ_EMA", "ΟΝΟΜΑ_ΦΑΡΜΑΚΟΥ", "ΚΑΤΗΓΟΡΙΑ"]))
    out.append(load_data_block(csv_dir_abs, "drastikes_farmakou.csv",
                               "drastikes_oysies_farmakoy",
                               ["ΚΩΔΙΚΟΣ_EMA_FK", "ΔΡΑΣΤΙΚΗ_ΟΥΣΙΑ_FK"]))

    # ─────────────────────────────────────────────────────────────────────────
    # 2. Faker-generated data (ordered for FKs)
    out.append("-- ─── Faker-generated data ───────────────────────────────\n\n")

    # Preload CSV catalogs that we'll reference
    diagnosi_codes = pd.read_csv(CSV_DIR / "diagnosi.csv")["code"].tolist()
    diagnosi_pool = diagnosi_codes[:100]
    sumptoma_ids = pd.read_csv(CSV_DIR / "sumptoma.csv")["id"].tolist()
    ken_codes = pd.read_csv(CSV_DIR / "ken.csv")["code"].tolist()
    farmako_codes = pd.read_csv(CSV_DIR / "farmako.csv")["ema_code"].tolist()
    drastiki_codes = pd.read_csv(CSV_DIR / "drastiki_ousia.csv")["code"].tolist()
    epemvasi_cat = pd.read_csv(CSV_DIR / "epemvasi_catalog.csv")
    ergastiriaki_cat = pd.read_csv(CSV_DIR / "ergastiriaki_catalog.csv")

    # Φτιάχνουμε lookup: farmako_code → set of substance codes  
    drug_substances = pd.read_csv(CSV_DIR / "drastikes_farmakou.csv")
    drug_sub_map: dict[str, set[str]] = defaultdict(set)
    for _, r in drug_substances.iterrows():
        drug_sub_map[r["ema_code"]].add(r["substance_code"])

    # 2.1 ΑΣΦΑΛΙΣΤΙΚΟΣ_ΦΟΡΕΑΣ
    out.append(insert("asfalistikos_foreas", ["ΤΥΠΟΣ"],
                     [(p,) for p, _desc in INSURANCE_PROVIDERS]))
    insurance_types = [p for p, _ in INSURANCE_PROVIDERS]

    # 2.2 ΠΡΟΣΩΠΙΚΟ (όλοι 800) — αλλά πρώτα παράγουμε όλα τα attrs
    amka_gen = unique_amka_factory()
    email_gen = unique_email_factory()

    personnel: list[dict] = []  # {amka, first, last, birth, hire, type}
    def make_person(ptype: str) -> dict:
        first = fake.first_name()
        last = fake.last_name()
        birth = random_date(date(1955, 1, 1), date(2000, 12, 31))
        # hire πρέπει να είναι > birth, και στο παρελθόν
        hire_min = max(birth + timedelta(days=22 * 365),
                       date(1990, 1, 1))
        hire_max = date(2024, 12, 31)
        if hire_min >= hire_max:
            hire = hire_max
        else:
            hire = random_date(hire_min, hire_max)
        return {
            "amka": amka_gen(),
            "first": first,
            "last": last,
            "birth": birth,
            "hire": hire,
            "type": ptype,
            "email": email_gen(first, last),
        }

    doctors = [make_person("ΙΑΤΡΟΣ") for _ in range(N_DOCTORS)]
    nurses = [make_person("ΝΟΣΗΛΕΥΤΗΣ") for _ in range(N_NURSES)]
    admins = [make_person("ΔΙΟΙΚΗΤΙΚΟ ΠΡΟΣΩΠΙΚΟ") for _ in range(N_ADMIN)]
    personnel = doctors + nurses + admins

    # Assign doctor ranks
    random.shuffle(doctors)
    for i, d in enumerate(doctors):
        if i < N_DIEYTHYNTES:
            d["rank"] = "ΔΙΕΥΘΥΝΤΗΣ"
        elif i < N_DIEYTHYNTES + N_EPIM_A:
            d["rank"] = "ΕΠΙΜΕΛΗΤΗΣ Α"
        elif i < N_DIEYTHYNTES + N_EPIM_A + N_EPIM_B:
            d["rank"] = "ΕΠΙΜΕΛΗΤΗΣ Β"
        else:
            d["rank"] = "ΕΙΔΙΚΕΥΟΜΕΝΟΣ"

    # Departments (15): ένας διευθυντής ανά τμήμα
    diefthyntes = [d for d in doctors if d["rank"] == "ΔΙΕΥΘΥΝΤΗΣ"]
    assert len(diefthyntes) == N_TMHMA == len(DEPARTMENT_NAMES)
    department_director = dict(zip(DEPARTMENT_NAMES, diefthyntes))

    # Assign κάθε ιατρός σε τμήμα
    license_numbers = random.sample(range(10000, 99999), k=len(doctors))
    for i, d in enumerate(doctors):
        if d["rank"] == "ΔΙΕΥΘΥΝΤΗΣ":
            dept = next(name for name, dr in department_director.items() if dr is d)
        else:
            dept = random.choice(DEPARTMENT_NAMES)
        d["dept"] = dept
        d["specialty"] = DOCTOR_SPECIALTIES[dept]
        d["license"] = f"ΙΣΑ-{license_numbers[i]}"  # ← εγγυημένα μοναδικό

    # ΕΙΔΙΚΕΥΟΜΕΝΟΙ → supervisor: random Α/Β/ΔΙΕΥΘΥΝΤΗΣ (όχι self)
    directors  = [d for d in doctors if d["rank"] == "ΔΙΕΥΘΥΝΤΗΣ"]
    epim_a     = [d for d in doctors if d["rank"] == "ΕΠΙΜΕΛΗΤΗΣ Α"]
    epim_b     = [d for d in doctors if d["rank"] == "ΕΠΙΜΕΛΗΤΗΣ Β"]
    eidikeyom  = [d for d in doctors if d["rank"] == "ΕΙΔΙΚΕΥΟΜΕΝΟΣ"]

    for d in directors:
        d["supervisor"] = None

    for d in epim_a:
        if random.random() < 0.15:
            d["supervisor"] = random.choice(directors)["amka"]
        else:
            d["supervisor"] = None

    for d in epim_b:
        if random.random() < 0.60:
            d["supervisor"] = random.choice(epim_a + directors)["amka"]
        else:
            d["supervisor"] = None

    for d in eidikeyom:
        d["supervisor"] = random.choice(epim_a + epim_b + directors)["amka"]

    # Nurses & admins: τμήμα assignment
    for n in nurses:
        n["dept"] = random.choice(DEPARTMENT_NAMES)
        n["rank"] = random.choice(["ΒΟΗΘΟΣ ΝΟΣΗΛΕΥΤΗ", "ΝΟΣΗΛΕΥΤΗΣ", "ΠΡΟΪΣΤΑΜΕΝΟΣ"])
    for a in admins:
        a["dept"] = random.choice(DEPARTMENT_NAMES)
        a["role"] = random.choice(["ΓΡΑΜΜΑΤΕΑΣ", "ΛΟΓΙΣΤΗΣ", "ΑΡΧΕΙΟΦΥΛΑΚΑΣ",
                                    "ΥΠΕΥΘΥΝΟΣ ΜΗΧΑΝΟΓΡΑΦΗΣΗΣ", "ΥΠΟΔΟΧΗ"])
        a["office"] = f"ΓΡΑΦΕΙΟ-{random.randint(1, 50)}"

    # 2.3 INSERT ΠΡΟΣΩΠΙΚΟ
    out.append("-- ΠΡΟΣΩΠΙΚΟ\n")
    prosopiko_rows = [(p["amka"], p["first"], p["last"], p["birth"].isoformat(),
             p["email"], p["hire"].isoformat(), p["type"]) for p in personnel]
    out.append(insert("prosopiko",
                     ["ΑΜΚΑ", "ΟΝΟΜΑ", "ΕΠΩΝΥΜΟ", "ΗΜΕΡΟΜΗΝΙΑ_ΓΕΝΝΗΣΗΣ",
                      "EMAIL", "ΗΜΕΡΟΜΗΝΙΑ_ΠΡΟΣΛΗΨΗΣ", "ΤΥΠΟΣ_ΠΡΟΣΩΠΙΚΟΥ"], prosopiko_rows))

    # 2.4 INSERT ΙΑΤΡΟΣ — διευθυντές ΠΡΩΤΟΣ, μετά Α/Β, μετά ΕΙΔΙΚΕΥΟΜΕΝΟΙ
    out.append("-- ΙΑΤΡΟΣ (sorted: ΔΙΕΥΘΥΝΤΗΣ → Α → Β → ΕΙΔΙΚΕΥΟΜΕΝΟΣ)\n")
    rank_order = {"ΔΙΕΥΘΥΝΤΗΣ": 0, "ΕΠΙΜΕΛΗΤΗΣ Α": 1,
                  "ΕΠΙΜΕΛΗΤΗΣ Β": 2, "ΕΙΔΙΚΕΥΟΜΕΝΟΣ": 3}
    doctors_sorted = sorted(doctors, key=lambda d: rank_order[d["rank"]])
    doctor_rows = [(d["amka"], d["license"], d["specialty"], d["rank"], d["supervisor"])
            for d in doctors_sorted]
    out.append(insert("iatros",
                     ["ΑΜΚΑ_FK", "ΑΡΙΘΜΟΣ_ΑΔΕΙΑΣ_ΣΥΛΛΟΓΟΥ", "ΕΙΔΙΚΟΤΗΤΑ",
                      "ΒΑΘΜΙΔΑ", "ΑΜΚΑ_ΕΠΟΠΤΗ_FK"], doctor_rows))

    # 2.5 ΤΜΗΜΑ — τώρα που υπάρχουν οι διευθυντές
    out.append("-- ΤΜΗΜΑ\n")
    tmima_rows = []
    for i, name in enumerate(DEPARTMENT_NAMES):
        tmima_rows.append((
            name,
            f"Τμήμα {name.title()} του νοσοκομείου",
            f"ΚΤΙΡΙΟ {chr(ord('Α') + (i % 4))}",
            (i % 6) + 1,
            N_BEDS_PER_DEPT,
            department_director[name]["amka"],
        ))
    out.append(insert("tmima",
                     ["ΟΝΟΜΑ", "ΠΕΡΙΓΡΑΦΗ", "ΚΤΙΡΙΟ", "ΟΡΟΦΟΣ",
                      "ΑΡΙΘΜΟΣ_ΚΛΙΝΩΝ", "ΑΜΚΑ_ΔΙΕΥΘΥΝΤΗ_FK"], tmima_rows))

    # 2.6 ΝΟΣΗΛΕΥΤΗΣ
    out.append("-- ΝΟΣΗΛΕΥΤΗΣ\n")
    nosileyths_rows = [(n["amka"], n["dept"], n["rank"]) for n in nurses]
    out.append(insert("nosileyths", ["ΑΜΚΑ_FK", "ΤΜΗΜΑ_FK", "ΒΑΘΜΙΔΑ"], nosileyths_rows))

    # 2.7 ΔΙΟΙΚΗΤΙΚΟ_ΠΡΟΣΩΠΙΚΟ
    out.append("-- ΔΙΟΙΚΗΤΙΚΟ_ΠΡΟΣΩΠΙΚΟ\n")
    dioikitiko_prosopiko_rows = [(a["amka"], a["dept"], a["role"], a["office"]) for a in admins]
    out.append(insert("dioikitiko_prosopiko",
                     ["ΑΜΚΑ_FK", "ΤΜΗΜΑ_FK", "ΡΟΛΟΣ", "ΓΡΑΦΕΙΟ_ΕΡΓΑΣΙΑΣ"], dioikitiko_prosopiko_rows))

    # 2.8 ΤΗΛΕΦΩΝΟ_ΠΡΟΣΩΠΙΚΟΥ
    out.append("-- ΤΗΛΕΦΩΝΟ_ΠΡΟΣΩΠΙΚΟΥ\n")
    thl_prosopikoy_rows = []
    for p in personnel:
        for _ in range(random.choice([1, 1, 2])):
            num = phone()
            if (p["amka"], num) in {(r[0], r[1]) for r in thl_prosopikoy_rows}:
                continue
            thl_prosopikoy_rows.append((p["amka"], num,
                                         random.choice(["ΚΙΝΗΤΟ", "ΣΤΑΘΕΡΟ", "ΕΡΓΑΣΙΑΣ"])))
    out.append(insert("thlefono_prosopikoy",
                     ["ΑΜΚΑ_FK", "ΑΡΙΘΜΟΣ", "ΤΥΠΟΣ"], thl_prosopikoy_rows))

    # 2.9 ΚΛΙΝΗ
    out.append("-- ΚΛΙΝΗ\n")
    beds: list[tuple[int, str]] = []
    klini_rows = []
    for dept in DEPARTMENT_NAMES:
        for num in range(1, N_BEDS_PER_DEPT + 1):
            ktype = random.choice(["ΑΠΛΗ", "ΕΝΤΑΤΙΚΗ", "ΗΜΙΕΝΤΑΤΙΚΗ"])
            beds.append((num, dept))
            klini_rows.append((num, dept, ktype, "ΔΙΑΘΕΣΙΜΗ"))
    out.append(insert("klini",
                     ["ΑΡΙΘΜΟΣ_ΚΛΙΝΗΣ", "ΤΜΗΜΑ_FK", "ΤΥΠΟΣ_ΚΛΙΝΗΣ", "ΚΑΤΑΣΤΑΣΗ"], klini_rows))

    # 2.10 ΧΩΡΟΣ
    out.append("-- ΧΩΡΟΣ\n")
    xoros_rows = []
    for i in range(1, N_ROOMS + 1):
        xoros_rows.append((
            i,
            f"ΧΕΙΡΟΥΡΓΕΙΟ {i}" if i <= 6 else f"ΑΙΘΟΥΣΑ ΕΠΕΜΒΑΣΗΣ {i}",
            "ΧΕΙΡΟΥΡΓΕΙΟ" if i <= 6 else "ΑΙΘΟΥΣΑ ΕΠΕΜΒΑΣΗΣ",
            f"ΚΤΙΡΙΟ {chr(ord('Α') + (i % 3))}",
            (i % 4) + 1,
            random.randint(1, 8),
        ))
    out.append(insert("xoros",
                     ["ΚΩΔΙΚΟΣ_ΧΩΡΟΥ", "ΟΝΟΜΑ", "ΤΥΠΟΣ", "ΚΤΙΡΙΟ",
                      "ΟΡΟΦΟΣ", "ΧΩΡΗΤΙΚΟΤΗΤΑ"], xoros_rows))

    # 2.11 ΙΑΤΡΟΣ_HAS_ΤΜΗΜΑ
    out.append("-- ΙΑΤΡΟΣ_HAS_ΤΜΗΜΑ\n")
    pairs: set[tuple[str, str]] = set()
    for d in doctors:
        pairs.add((d["amka"], d["dept"]))
        # Μερικοί καλύπτουν και άλλο τμήμα
        if random.random() < 0.5:
            extra = random.choice(DEPARTMENT_NAMES)
            pairs.add((d["amka"], extra))
    out.append(insert("iatros_has_tmima",
                     ["ΙΑΤΡΟΣ_ΑΜΚΑ_FK", "ΤΜΗΜΑ_ΟΝΟΜΑ_FK"],
                     sorted(pairs)))

    # 2.12 ΑΣΘΕΝΗΣ
    out.append("-- ΑΣΘΕΝΗΣ\n")
    patients: list[dict] = []
    used_pat_emails: set[str] = set()
    for _ in range(N_PATIENTS):
        gender = random.choice(["Α", "Θ"])
        first = fake.first_name_male() if gender == "Α" else fake.first_name_female()
        last = fake.last_name()
        # Avoid duplicate (first, last, …) email via simple counter
        em_base = strip_greek(first).lower() + "." + strip_greek(last).lower()
        em = em_base + str(random.randint(1, 9999)) + "@example.gr"
        while em in used_pat_emails:
            em = em_base + str(random.randint(1, 99999)) + "@example.gr"
        used_pat_emails.add(em)
        patients.append({
            "amka": amka_gen(),
            "first": first[:15],
            "last": last[:25],
            "patronymo": fake.first_name_male()[:25],
            "birth": random_date(date(1930, 1, 1), date(2024, 12, 31)),
            "gender": gender,
            "weight": round(random.uniform(45, 110), 2),
            "height": round(random.uniform(1.45, 1.95), 2),
            "address": (fake.street_address() or "Οδός 1")[:45],
            "email": em[:45],
            "job": random.choice([
                "ΣΥΝΤΑΞΙΟΥΧΟΣ", "ΥΠΑΛΛΗΛΟΣ", "ΕΛΕΥΘΕΡΟΣ ΕΠΑΓΓΕΛΜΑΤΙΑΣ",
                "ΦΟΙΤΗΤΗΣ", "ΑΓΡΟΤΗΣ", "ΟΙΚΙΑΚΑ", "ΑΝΕΡΓΟΣ",
            ]),
            "nationality": random.choice([
                "ΕΛΛΗΝΙΚΗ", "ΕΛΛΗΝΙΚΗ", "ΕΛΛΗΝΙΚΗ", "ΑΛΒΑΝΙΚΗ", "ΣΥΡΙΑΚΗ",
            ]),
            "insurance": random.choice(insurance_types),
        })
    asthenis_rows = [(p["amka"], p["first"], p["last"], p["patronymo"],
             p["birth"].isoformat(), p["gender"], p["weight"], p["height"],
             p["address"], p["email"], p["job"], p["nationality"], p["insurance"])
            for p in patients]
    out.append(insert("asthenis",
                     ["ΑΜΚΑ", "ΟΝΟΜΑ", "ΕΠΩΝΥΜΟ", "ΠΑΤΡΩΝΥΜΟ",
                      "ΗΜΕΡΟΜΗΝΙΑ_ΓΕΝΝΗΣΗΣ", "ΦΥΛΟ", "ΒΑΡΟΣ", "ΥΨΟΣ",
                      "ΔΙΕΥΘΥΝΣΗ", "EMAIL", "ΕΠΑΓΓΕΛΜΑ", "ΥΠΗΚΟΟΤΗΤΑ",
                      "ΑΣΦΑΛΙΣΤΙΚΟΣ_ΦΟΡΕΑΣ_FK"], asthenis_rows))

    # 2.13 ΤΗΛΕΦΩΝΟ_ΑΣΘΕΝΗ
    out.append("-- ΤΗΛΕΦΩΝΟ_ΑΣΘΕΝΗ\n")
    pat_phones: set[tuple[str, str]] = set()
    thl_astheni_rows = []
    for p in patients:
        for _ in range(random.choice([1, 1, 2])):
            num = phone()
            if (p["amka"], num) in pat_phones:
                continue
            pat_phones.add((p["amka"], num))
            thl_astheni_rows.append((p["amka"], num,
                         random.choice(["ΚΙΝΗΤΟ", "ΣΤΑΘΕΡΟ", "ΕΡΓΑΣΙΑΣ"])))
    out.append(insert("thlefono_astheni",
                     ["ΑΜΚΑ_ΑΣΘΕΝΗ_FK", "ΑΡΙΘΜΟΣ", "ΤΥΠΟΣ"], thl_astheni_rows))

    # 2.14 ΣΤΟΙΧΕΙΑ_ΟΙΚΕΙΩΝ
    out.append("-- ΣΤΟΙΧΕΙΑ_ΟΙΚΕΙΩΝ\n")
    stoixeia_oikeion_rows = []
    used_kin: set[tuple[str, str]] = set()
    for p in patients:
        for _ in range(1):
            num = phone()
            if (p["amka"], num) in used_kin:
                continue
            used_kin.add((p["amka"], num))
            stoixeia_oikeion_rows.append((
                p["amka"], num,
                fake.first_name()[:45], fake.last_name()[:45],
                fake.first_name_male()[:45],
                random.choice(["ΣΥΖΥΓΟΣ", "ΓΟΝΕΑΣ", "ΑΔΕΛΦΟΣ/Η",
                                "ΠΑΙΔΙ", "ΦΙΛΟΣ/Η"]),
            ))
    out.append(insert("stoixeia_oikeion",
                     ["ΑΜΚΑ_ΑΣΘΕΝΗ_FK", "ΤΗΛΕΦΩΝΟ", "ΟΝΟΜΑ", "ΕΠΩΝΥΜΟ",
                      "ΠΑΤΡΩΝΥΜΟ", "ΣΧΕΣΗ_ΑΣΘΕΝΗ"], stoixeia_oikeion_rows))

    # 2.15 ΑΛΛΕΡΓΙΕΣ
    out.append("-- ΑΛΛΕΡΓΙΕΣ\n")
    allergy_pairs: set[tuple[str, str]] = set()
    while len(allergy_pairs) < N_ALLERGIES:
        allergy_pairs.add((random.choice(patients)["amka"],
                           random.choice(drastiki_codes)))
    out.append(insert("allergies",
                     ["ΑΜΚΑ_ΑΣΘΕΝΗ_FK", "ΔΡΑΣΤΙΚΗ_ΟΥΣΙΑ_FK"],
                     sorted(allergy_pairs)))

    # Φτιάξε lookup: patient_amka → set of substance codes
    patient_allergies: dict[str, set[str]] = defaultdict(set)
    for pat_amka, sub_code in allergy_pairs:
        patient_allergies[pat_amka].add(sub_code)

    # 2.16 ΝΟΣΗΛΕΙΑ + ΚΟΣΤΟΛΟΓΗΣΗ (γιατί χρειάζεται για τα triggers)
    out.append("-- ΝΟΣΗΛΕΙΑ\n")
    nosileies: list[dict] = []
    patient_amkas = [p["amka"] for p in patients]
    patient_weights = [3 if i < 50 else 1 for i in range(len(patients))]
    # bed occupancy tracker: (bed, dept) → list of (admit, discharge|None)
    bed_intervals: dict[tuple[int, str], list[tuple[date, date | None]]] = defaultdict(list)

    used_kens_in_nosileia: set[str] = set()
    nosil_id = 1
    actual_count = 0
    while actual_count < N_NOSILEIES:
        r = random.random()
        if r < 0.40:
            admit = random_date(date(2025, 1, 1), date(2025, 12, 1))
        elif r < 0.70:
            admit = random_date(date(2024, 1, 1), date(2024, 12, 1))
        else:
            admit = random_date(date(2021, 1, 1), date(2023, 12, 31))
        is_open = random.random() < 0.1
        if is_open:
            discharge = None
            exit_diag = None
        else:
            stay = random.randint(1, 14)
            discharge = admit + timedelta(days=stay)
            exit_diag = random.choice(diagnosi_pool)

        # Find a bed that's free during this interval
        attempts = 0
        chosen_bed = None
        while attempts < 100:
            bed_num, bed_dept = random.choice(beds)
            conflict = False
            for a, d in bed_intervals[(bed_num, bed_dept)]:
                end = d if d is not None else date(9999, 1, 1)
                cur_end = discharge if discharge is not None else date(9999, 1, 1)
                if not (cur_end <= a or admit >= end):
                    conflict = True
                    break
            if not conflict:
                chosen_bed = (bed_num, bed_dept)
                break
            attempts += 1

        if chosen_bed is None:  # δεν βρέθηκε κλίνη, παράλειψε
            continue

        bed_num, bed_dept = chosen_bed
        bed_intervals[(bed_num, bed_dept)].append((admit, discharge))
        ken = random.choice(ken_codes)
        used_kens_in_nosileia.add(ken)
        nosileies.append({
            "id": nosil_id,
            "patient": random.choices(patient_amkas, weights=patient_weights, k=1)[0],
            "doctor": random.choice([d for d in doctors
                                     if d["rank"] != "ΕΙΔΙΚΕΥΟΜΕΝΟΣ"])["amka"],
            "therapy": random.choice([
                "Φαρμακευτική αγωγή", "Χειρουργική αντιμετώπιση",
                "Συντηρητική θεραπεία", "Διαγνωστικός έλεγχος",
            ]),
            "dept": bed_dept,
            "bed": bed_num,
            "admit": admit,
            "discharge": discharge,
            "entry_diag": random.choice(diagnosi_pool),
            "exit_diag": exit_diag,
            "ken": ken,
        })
        nosil_id += 1
        actual_count += 1

    # Pre-create ΚΟΣΤΟΛΟΓΗΣΗ ΠΡΙΝ από ΝΟΣΗΛΕΙΑ (trigger trg_calc_total_cost
    # κάνει lookup σε ΚΟΣΤΟΛΟΓΗΣΗ — χρειάζεται να υπάρχει ήδη)
    out.append("-- ΚΟΣΤΟΛΟΓΗΣΗ (πριν από ΝΟΣΗΛΕΙΑ για το trg_calc_total_cost)\n")
    kostologhsh_rows = []
    for ken in used_kens_in_nosileia:
        for ins in insurance_types:
            kostologhsh_rows.append((ken, ins,
                                     round(random.uniform(500, 5000), 2),
                                     round(random.uniform(50, 300), 2)))
    out.append(insert("kostologhsh",
                     ["ΚΕΝ_FK", "ΑΣΦΑΛΙΣΤΙΚΟΣ_ΦΟΡΕΑΣ_FK",
                      "ΒΑΣΙΚΟ_ΚΟΣΤΟΣ", "ΗΜΕΡΗΣΙΑ_ΠΡΟΣΘΕΤΗ_ΧΡΕΩΣΗ"], kostologhsh_rows))

    # ΝΟΣΗΛΕΙΑ INSERT
    noshleia_rows = []
    for n in nosileies:
        noshleia_rows.append((
            n["id"], n["patient"], n["doctor"], n["therapy"], n["dept"], n["bed"],
            n["admit"].isoformat() + " 10:00:00",
            (n["discharge"].isoformat() + " 14:00:00") if n["discharge"] else None,
            n["entry_diag"], n["exit_diag"], n["ken"], None,
        ))
    out.append(insert("nosileia",
                     ["ΚΩΔΙΚΟΣ_ΝΟΣΗΛΕΙΑΣ", "ΑΜΚΑ_ΑΣΘΕΝΗ_FK", "ΑΜΚΑ_ΙΑΤΡΟΥ_FK",
                      "ΘΕΡΑΠΕΙΑ", "ΤΜΗΜΑ_FK", "ΚΛΙΝΗ_FK",
                      "ΗΜΕΡΟΜΗΝΙΑ_ΕΙΣΟΔΟΥ", "ΗΜΕΡΟΜΗΝΙΑ_ΕΞΟΔΟΥ",
                      "ΔΙΑΓΝΩΣΗ_ΕΙΣΟΔΟΥ_FK", "ΔΙΑΓΝΩΣΗ_ΕΞΟΔΟΥ_FK",
                      "ΚΕΝ_FK", "ΣΥΝΟΛΙΚΟ_ΚΟΣΤΟΣ"], noshleia_rows))
    # Ενημέρωση ΚΑΤΑΣΤΑΣΗ κλίνης για ανοικτές νοσηλείες
    # (τα triggers είναι disabled κατά το load, οπότε το κάνουμε manually)
    out.append("-- Ενημέρωση κατάστασης κλινών για ανοικτές νοσηλείες\n")
    out.append("""\
    UPDATE KLINI k
    JOIN NOSILEIA n ON n.ΚΛΙΝΗ_FK = k.ΑΡΙΘΜΟΣ_ΚΛΙΝΗΣ
                AND n.ΤΜΗΜΑ_FK  = k.ΤΜΗΜΑ_FK
    SET k.ΚΑΤΑΣΤΑΣΗ = 'ΚΑΤΕΙΛΗΜΜΕΝΗ'
    WHERE n.ΗΜΕΡΟΜΗΝΙΑ_ΕΞΟΔΟΥ IS NULL;\n\n""")

    # 2.17 ΕΦΗΜΕΡΙΑ, ΒΑΡΔΙΑ, ΕΦΗΜΕΡΙΑ_ΠΡΟΣΩΠΙΚΟΥ
    out.append("-- ΕΦΗΜΕΡΙΑ\n")
    # 5 τυχαίες μέρες 2023 | 10 τυχαίες 2024 εκ των οποίων 1 εβδομάδα συνεχόμενη για τα queries | 15 τυχαίες 2025
    _start = date(2025, 4, 7)  # ή όποια εβδομάδα θες
    consecutive_week = [_start + timedelta(days=i) for i in range(7)]

    _remaining_2025 = [
        date(2025, 1, 1) + timedelta(days=i)
        for i in range(365)
        if date(2025, 1, 1) + timedelta(days=i) not in set(consecutive_week)
    ]
    extra_days = random.sample(_remaining_2025, 3)

    efim_dates = sorted(set(consecutive_week + extra_days))
    efim_rows = [(d.isoformat(), dept) for d in efim_dates for dept in DEPARTMENT_NAMES]
    out.append(insert("efimeria", ["ΗΜΕΡΟΜΗΝΙΑ", "ΤΜΗΜΑ_FK"], efim_rows))

    out.append("-- ΒΑΡΔΙΑ\n")
    vardia_rows = []
    for d in efim_dates:
        for dept in DEPARTMENT_NAMES:
            for stype in SHIFT_TYPES:
                s, e, _ = SHIFT_HOURS[stype]
                vardia_rows.append((stype, d.isoformat(), dept, 1))
    out.append(insert("bardia",
                     ["ΤΥΠΟΣ_ΒΑΡΔΙΑΣ", "ΗΜΕΡΟΜΗΝΙΑ_FK", "ΤΜΗΜΑ_FK",
                      "ΟΜΑΔΑ_ΕΦΗΜΕΡΙΑΣ"], vardia_rows))

    # ── ΕΦΗΜΕΡΙΑ_ΠΡΟΣΩΠΙΚΟΥ
    out.append("-- ΕΦΗΜΕΡΙΑ_ΠΡΟΣΩΠΙΚΟΥ (honors all triggers & tiered senior selection)\n")

    # Helper: shift end datetime
    def shift_window(d: date, stype: str) -> tuple[datetime, datetime]:
        s_str, e_str, end_offset = SHIFT_HOURS[stype]
        s_dt = datetime.combine(d, datetime.strptime(s_str, "%H:%M:%S").time())
        e_dt = datetime.combine(d + timedelta(days=end_offset),
                            datetime.strptime(e_str, "%H:%M:%S").time())
        return s_dt, e_dt

    # State trackers
    monthly_count: dict[tuple[str, int, int], int] = defaultdict(int)
    person_shift_times: dict[str, list[tuple[datetime, datetime]]] = defaultdict(list)
    consecutive_nights: dict[str, dict[date, bool]] = defaultdict(dict)

    def can_assign(amka: str, ptype: str, d: date, stype: str, ignore_cap: bool = False) -> bool:
        # 1. Monthly cap (Unless ignored during fallback)
        if not ignore_cap:
            limit = MAX_MONTHLY_SHIFTS[ptype]
            key = (amka, d.year, d.month)
            if monthly_count[key] >= limit:
                return False

        # 2. 8h ξεκούραση μεταξύ βαρδιών
        new_s, new_e = shift_window(d, stype)
        for prev_s, prev_e in person_shift_times[amka]:
            if new_s < prev_e + timedelta(hours=8) and new_e + timedelta(hours=8) > prev_s:
                return False

        # 3. Μέγιστο 2 συνεχόμενες νυχτερινές
        if stype == "ΝΥΧΤΕΡΙΝΗ":
            back = 0
            check = d - timedelta(days=1)
            while consecutive_nights[amka].get(check, False):
                back += 1
                check -= timedelta(days=1)
            fwd = 0
            check = d + timedelta(days=1)
            while consecutive_nights[amka].get(check, False):
                fwd += 1
                check += timedelta(days=1)
            if back + 1 + fwd > 3:
                return False
        return True

    def commit_assignment(amka: str, ptype: str, d: date, stype: str) -> None:
        monthly_count[(amka, d.year, d.month)] += 1
        person_shift_times[amka].append(shift_window(d, stype))
        if stype == "ΝΥΧΤΕΡΙΝΗ":
            consecutive_nights[amka][d] = True

    # Indexing
    doc_by_amka = {d["amka"]: d for d in doctors}
    seniors_amkas = [d["amka"] for d in doctors if d["rank"] in ("ΕΠΙΜΕΛΗΤΗΣ Α", "ΔΙΕΥΘΥΝΤΗΣ")]
    other_doc_amkas = [d["amka"] for d in doctors if d["rank"] not in ("ΕΠΙΜΕΛΗΤΗΣ Α", "ΔΙΕΥΘΥΝΤΗΣ")]
    nurse_amkas = [n["amka"] for n in nurses]
    admin_amkas = [a["amka"] for a in admins]

    ep_rows = []

    def pick(pool: list[str], ptype: str, d: date, stype: str, 
             exclude: set[str], ignore_cap: bool = False) -> str | None:
        candidates = [a for a in pool if a not in exclude]
        random.shuffle(candidates)
        for amka in candidates:
            if can_assign(amka, ptype, d, stype, ignore_cap):
                return amka
        return None

    for d in efim_dates:
        for dept in DEPARTMENT_NAMES:
            for stype in SHIFT_TYPES:
                assigned_this_shift: set[str] = set()
            
                # --- STEP 1: SENIOR SELECTION (Tiered Fallback) ---
                senior = None
                # Tier 1: Senior του τμήματος, εντός ορίου
                dept_seniors = [a for a in seniors_amkas if doc_by_amka[a]["dept"] == dept]
                senior = pick(dept_seniors, "ΙΑΤΡΟΣ", d, stype, assigned_this_shift)
            
                # Tier 2: Οποιοσδήποτε Senior, εντός ορίου
                if senior is None:
                    senior = pick(seniors_amkas, "ΙΑΤΡΟΣ", d, stype, assigned_this_shift)
            
                if senior:
                    assigned_this_shift.add(senior)
                    commit_assignment(senior, "ΙΑΤΡΟΣ", d, stype)
                    ep_rows.append((stype, d.isoformat(), dept, senior, "ΕΠΙΒΛΕΠΩΝ"))
                else:
                    print(f" [error] Critical failure for {d} {dept} {stype}: No senior available even with cap bypass", file=sys.stderr)
                    continue

                # --- STEP 2: ADDITIONAL DOCTORS ---
                for _ in range(MIN_DOCTORS_PER_SHIFT - 1):
                    # Δοκιμή με όριο
                    docp = pick(other_doc_amkas + seniors_amkas, "ΙΑΤΡΟΣ", d, stype, assigned_this_shift)
                    if docp:
                        assigned_this_shift.add(docp)
                        commit_assignment(docp, "ΙΑΤΡΟΣ", d, stype)
                        rank = doc_by_amka[docp]["rank"]
                        role = "ΕΙΔΙΚΕΥΟΜΕΝΟΣ" if rank == "ΕΙΔΙΚΕΥΟΜΕΝΟΣ" else "ΙΑΤΡΟΣ"
                        ep_rows.append((stype, d.isoformat(), dept, docp, role))

                # STEP 3: NURSES — μόνο του τμήματος
                dept_nurses = [n["amka"] for n in nurses if n["dept"] == dept]
                for _ in range(MIN_NURSES_PER_SHIFT):
                    nn = pick(dept_nurses, "ΝΟΣΗΛΕΥΤΗΣ", d, stype, assigned_this_shift)
                    if nn:
                        assigned_this_shift.add(nn)
                        commit_assignment(nn, "ΝΟΣΗΛΕΥΤΗΣ", d, stype)
                        ep_rows.append((stype, d.isoformat(), dept, nn, "ΝΟΣΗΛΕΥΤΗΣ"))

                # STEP 4: ADMINS — μόνο του τμήματος
                dept_admins = [a["amka"] for a in admins if a["dept"] == dept]
                for _ in range(MIN_ADMIN_PER_SHIFT):
                    aa = pick(dept_admins, "ΔΙΟΙΚΗΤΙΚΟ ΠΡΟΣΩΠΙΚΟ", d, stype, assigned_this_shift)
                    if aa:
                        assigned_this_shift.add(aa)
                        commit_assignment(aa, "ΔΙΟΙΚΗΤΙΚΟ ΠΡΟΣΩΠΙΚΟ", d, stype)
                        ep_rows.append((stype, d.isoformat(), dept, aa, "ΓΡΑΜΜΑΤΕΙΑ"))

    out.append(insert("efimeria_prosopikoy",
                 ["ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK", "ΗΜΕΡΟΜΗΝΙΑ_FK", "ΤΜΗΜΑ_FK",
                  "ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK", "ΡΟΛΟΣ_ΕΦΗΜΕΡΙΑΣ"], ep_rows))
    # Επαλήθευση ελάχιστης στελέχωσης βάρδιας
    shift_staff: dict[tuple, dict[str, int]] = defaultdict(lambda: {"IATROS": 0, "NOSILEYTHS": 0, "DIOIKITIKO": 0})
    nurse_amkas  = {n["amka"] for n in nurses}
    admin_amkas  = {a["amka"] for a in admins}
    doctor_amkas = {d["amka"] for d in doctors}

    for row in ep_rows:
        stype, date_str, dept, amka, _ = row
        key = (stype, date_str, dept)
        if amka in doctor_amkas:
            shift_staff[key]["IATROS"] += 1
        elif amka in nurse_amkas:
            shift_staff[key]["NOSILEYTHS"] += 1
        elif amka in admin_amkas:
            shift_staff[key]["DIOIKITIKO"] += 1

    violations = [
        f"  {key}: ιατροί={v['IATROS']}, νοσηλευτές={v['NOSILEYTHS']}, διοικητικοί={v['DIOIKITIKO']}"
        for key, v in shift_staff.items()
        if v["IATROS"] < 3 or v["NOSILEYTHS"] < 6 or v["DIOIKITIKO"] < 2
    ]
    if violations:
        print(f"[WARNING] {len(violations)} βάρδιες με ανεπαρκή στελέχωση:")
        for v in violations[:10]:
            print(v)

    # 2.18 ΕΠΕΜΒΑΣΗ
    out.append("-- ΕΠΕΜΒΑΣΗ\n")

    room_busy:   dict[int, list[tuple[datetime, datetime]]] = defaultdict(list)
    doctor_busy: dict[str, list[tuple[datetime, datetime]]] = defaultdict(list)

    def _conflicts(intervals, s, e):
        return any(not (e <= a or s >= b) for a, b in intervals)

    epemvasi_rows: list[tuple] = []
    epemvasi_windows: dict[int, tuple[datetime, datetime]] = {}
    sample = epemvasi_cat.sample(min(N_EPEMVASEIS, len(epemvasi_cat)),
                                random_state=42)
    non_eidik = [d for d in doctors if d["rank"] != "ΕΙΔΙΚΕΥΟΜΕΝΟΣ"]

    ep_id = 1
    for _, r in sample.iterrows():
        placed = False
        for _try in range(50):
            nos = random.choice(nosileies)
            admit = nos["admit"]
            discharge = nos["discharge"] if nos["discharge"] else admit + timedelta(days=14)
            epem_date = random_date(admit, discharge)
            dur = random.randint(30, 360)
            h = random.randint(7, 19); m = random.choice([0, 15, 30, 45])
            s_dt = datetime.combine(epem_date, time(h, m))
            e_dt = s_dt + timedelta(minutes=dur)
            room = random.randint(1, N_ROOMS)
            doc  = random.choice(non_eidik)["amka"]
            if _conflicts(room_busy[room], s_dt, e_dt):    continue
            if _conflicts(doctor_busy[doc], s_dt, e_dt):   continue
            room_busy[room].append((s_dt, e_dt))
            doctor_busy[doc].append((s_dt, e_dt))
            epemvasi_rows.append((
                ep_id, nos["id"], doc, room,
                r["name"][:25], r["category"][:50],
                dur, round(random.uniform(200, 5000), 2),
                s_dt.isoformat(sep=' '),
            ))
            epemvasi_windows[ep_id] = (s_dt, e_dt)
            ep_id += 1
            placed = True
            break

    out.append(insert("epembasi",
                ["ΚΩΔΙΚΟΣ", "ΝΟΣΗΛΕΙΑ_FK", "ΑΜΚΑ_ΚΥΡΙΟΥ_ΙΑΤΡΟΥ_FK",
                    "ΧΩΡΟΣ_FK", "ΟΝΟΜΑ", "ΚΑΤΗΓΟΡΙΑ", "ΔΙΑΡΚΕΙΑ",
                    "ΚΟΣΤΟΣ", "ΗΜΕΡΟΜΗΝΙΑ"], epemvasi_rows))

    # 2.19 ΕΠΕΜΒΑΣΗ_ΒΟΗΘΟΙ
    out.append("-- ΕΠΕΜΒΑΣΗ_ΒΟΗΘΟΙ\n")
    voithoi_pairs: set[tuple[int, str]] = set()
    helper_busy: dict[str, list[tuple[datetime, datetime]]] = defaultdict(list)
    epem_boithoi_rows = []

    for ep in epemvasi_rows:
        ep_code, _nos, main_doc, *_ = ep
        s_dt, e_dt = epemvasi_windows[ep_code]
        for _ in range(random.choice([1, 2, 3])):
            for _try in range(30):
                helper = random.choice(doctors + nurses)["amka"]
                if helper == main_doc:                       continue
                if (ep_code, helper) in voithoi_pairs:       continue
                if _conflicts(doctor_busy[helper], s_dt, e_dt): continue
                if _conflicts(helper_busy[helper], s_dt, e_dt): continue
                voithoi_pairs.add((ep_code, helper))
                helper_busy[helper].append((s_dt, e_dt))
                epem_boithoi_rows.append((ep_code, helper,
                    random.choice(["ΒΟΗΘΟΣ ΧΕΙΡΟΥΡΓΟΥ",
                                    "ΑΝΑΙΣΘΗΣΙΟΛΟΓΟΣ",
                                    "ΝΟΣΗΛΕΥΤΗΣ ΧΕΙΡΟΥΡΓΕΙΟΥ"])))
                break

    out.append(insert("epembasi_boithoi",
                    ["ΚΩΔΙΚΟΣ_ΕΠΕΜΒΑΣΗΣ_FK", "ΑΜΚΑ_ΒΟΗΘΟΥ_FK", "ΡΟΛΟΣ"],
                    epem_boithoi_rows))

    # 2.20 ΕΡΓΑΣΤΗΡΙΑΚΗ_ΕΞΕΤΑΣΗ
    out.append("-- ΕΡΓΑΣΤΗΡΙΑΚΗ_ΕΞΕΤΑΣΗ\n")
    sample = ergastiriaki_cat.sample(min(N_LAB_TESTS, len(ergastiriaki_cat)),
                                      random_state=43)
    lab_rows = []
    used_lab_codes: set[str] = set()
    attempts = 0
    while len(lab_rows) < N_LAB_TESTS and attempts < N_LAB_TESTS * 10:
        attempts += 1
        r = ergastiriaki_cat.sample(1).iloc[0]
        nos = random.choice(nosileies)
        code = r["code"] + f"-{nos['id']}"
        if code in used_lab_codes:
            continue
        used_lab_codes.add(code)
        lab_rows.append((
            code, nos["id"],
            round(random.uniform(0.1, 200), 2),
            random.choice(["mg/dL", "mmol/L", "g/dL", "U/L", "/μL"]),
            random.choice([d for d in doctors
                          if d["rank"] != "ΕΙΔΙΚΕΥΟΜΕΝΟΣ"])["amka"],
            random.choice(["ΑΙΜΑΤΟΛΟΓΙΚΟ", "ΒΙΟΧΗΜΙΚΟ", "ΑΠΕΙΚΟΝΙΣΤΙΚΟ"]),
            nos["admit"].isoformat() + " 09:00:00",
            round(random.uniform(5, 200), 2),
            "ΦΥΣΙΟΛΟΓΙΚΟ" if random.random() > 0.3 else "ΠΑΘΟΛΟΓΙΚΟ",
        ))
    out.append(insert("ergastiriaki_eksetasi",
                     ["ΚΩΔΙΚΟΣ_ΕΞΕΤΑΣΗΣ", "ΝΟΣΗΛΕΙΑ_FK", "ΑΡΙΘΜΗΤΙΚΗ_ΤΙΜΗ",
                      "ΜΟΝΑΔΑ_ΜΕΤΡΗΣΗΣ", "ΕΝΤΟΛΕΑΣ_ΙΑΤΡΟΣ_FK", "ΤΥΠΟΣ",
                      "ΗΜΕΡΟΜΗΝΙΑ", "ΚΟΣΤΟΣ", "ΑΠΟΤΕΛΕΣΜΑ"], lab_rows))

    # 2.21 ΔΙΑΛΟΓΗ
    out.append("-- ΔΙΑΛΟΓΗ\n")

    OUTCOME_CHOICES = ["ΕΙΣΑΓΩΓΗ", "ΕΞΙΤΗΡΙΟ", "ΠΑΡΑΜΟΝΗ ΓΙΑ ΕΞΕΤΑΣΕΙΣ"]
    OUTCOME_WEIGHTS = [30, 50, 20]

    TRIAGE_START = date(2023, 1, 1)
    TRIAGE_END   = date(2025, 12, 31)

    # ── Step 0: Χώρισε νοσηλείες σε emergency / planned ──────────────────────
    # ~40% των νοσηλειών είναι επείγουσες (θα συνδεθούν 1:1 με triage ΕΙΣΑΓΩΓΗ)
    # Οι υπόλοιπες είναι προγραμματισμένες (χωρίς triage — π.χ. από γιατρό)
    emergency_pool = random.sample(nosileies, int(len(nosileies) * 0.40))

    pat_emergency_nos: dict[str, list[dict]] = defaultdict(list)
    for n in emergency_pool:
      pat_emergency_nos[n["patient"]].append(n)

    assigned_nos_ids: set[int] = set()   # κάθε νοσηλεία → max 1 triage

    # ── Step 1: Παραγωγή raw events ───────────────────────────────────────────
    used_triage: set[tuple[str, str]] = set()
    raw_triages: list[dict] = []

    for _ in range(N_TRIAGES):
        for _attempt in range(30):
            pat = random.choice(patients)["amka"]
            # Δοκίμασε emergency νοσηλεία (40%) αλλιώς ελεύθερη ημερομηνία
            available = [n for n in pat_emergency_nos.get(pat, [])
                        if n["id"] not in assigned_nos_ids]
            if available and random.random() < 0.6:
                nos = random.choice(available)
                arr_date = nos["admit"]
            else:
                nos = None
                arr_date = random_date(TRIAGE_START, TRIAGE_END)

            arrival = datetime(arr_date.year, arr_date.month, arr_date.day,
                                random.randint(0, 9), random.randint(0, 59))
            key = (pat, arrival.isoformat(sep=" "))
            if key not in used_triage:
                used_triage.add(key)
                break
        else:
            continue

        level   = random.randint(1, 5)
        outcome = random.choices(OUTCOME_CHOICES, weights=OUTCOME_WEIGHTS, k=1)[0]

        nos_id = None
        if outcome == "ΕΙΣΑΓΩΓΗ" and nos is not None:
            nos_id = nos["id"]
            assigned_nos_ids.add(nos_id)
        elif outcome == "ΕΙΣΑΓΩΓΗ":
            outcome = random.choice(["ΕΞΙΤΗΡΙΟ", "ΠΑΡΑΜΟΝΗ ΓΙΑ ΕΞΕΤΑΣΕΙΣ"])

        raw_triages.append({
            "pat": pat, "arrival": arrival,
            "level": level, "outcome": outcome, "nos_id": nos_id,
        })

    # ── Step 2: FIFO simulation ανά επίπεδο επείγοντος ───────────────────────
    by_level: dict[int, list[dict]] = {l: [] for l in range(1, 6)}
    for tr in raw_triages:
        by_level[tr["level"]].append(tr)

    for lvl, queue in by_level.items():
        queue.sort(key=lambda x: x["arrival"])   # FIFO
        server_free = datetime.min
        base = LEVEL_BASE_WAIT[lvl]
        for tr in queue:
            start  = max(server_free, tr["arrival"])
            wait   = max(1, int(random.gauss(base, base * 0.2)))
            served = start + timedelta(minutes=wait)
            tr["served"] = served
            server_free  = served

    # ── Step 3: Build insert rows ─────────────────────────────────────────────
    triages: list[tuple] = []
    for tr in (t for queue in by_level.values() for t in queue):
        triages.append((
            tr["pat"],
            random.choice(nurses)["amka"],
            tr["arrival"].isoformat(sep=" "),
            tr["level"],
            tr["outcome"],
            tr["nos_id"],
            tr["served"].isoformat(sep=" "),
        ))

    out.append(insert("dialogi",
                    ["ΑΜΚΑ_ΑΣΘΕΝΗ_FK", "ΑΜΚΑ_ΝΟΣΗΛΕΥΤΗ_FK", "ΩΡΑ_ΑΦΙΞΗΣ",
                    "ΕΠΙΠΕΔΟ_ΕΠΕΙΓΟΝΤΟΣ", "ΑΠΟΤΕΛΕΣΜΑ", "ΝΟΣΗΛΕΙΑ_FK",
                    "ΩΡΑ_ΕΞΥΠΗΡΕΤΗΣΗΣ"], triages))
    
    # 2.22 ΣΥΜΠΤΩΜΑ_ΔΙΑΛΟΓΗΣ
    out.append("-- ΣΥΜΠΤΩΜΑ_ΔΙΑΛΟΓΗΣ\n")
    symptoma_dialogis_rows = []
    seen_sd: set[tuple[str, str, int]] = set()
    for tr in triages:
        for _ in range(random.choice([1, 2, 3])):
            sid = random.choice(sumptoma_ids)
            key = (tr[0], tr[2], sid)
            if key in seen_sd:
                continue
            seen_sd.add(key)
            symptoma_dialogis_rows.append((tr[0], tr[2], sid))
    out.append(insert("symptoma_dialogis",
                     ["ΑΜΚΑ_ΑΣΘΕΝΗ_FK", "ΩΡΑ_ΑΦΙΞΗΣ_FK",
                      "ΚΩΔΙΚΟΣ_ΣΥΜΠΤΩΜΑΤΟΣ_FK"], symptoma_dialogis_rows))

    # 2.23 ΣΥΝΤΑΓΟΓΡΑΦΗΣΗ
    out.append("-- ΣΥΝΤΑΓΟΓΡΑΦΗΣΗ\n")
    rx_pk_seen: set[tuple] = set()
    rx_rows = []
    for nos in nosileies:
        for _ in range(random.randint(2, 4)):
            start = nos["admit"]
            end = start + timedelta(days=random.randint(3, 30))

            drug = random.choice(farmako_codes)
            subs = drug_sub_map.get(drug, set())
            if subs & patient_allergies.get(nos["patient"], set()):
                continue

            rx = (
                nos["doctor"], nos["patient"],
                drug,
                start.isoformat(),
                round(random.uniform(50, 500), 3),
                random.choice(["1x ημερησίως", "2x ημερησίως", "3x ημερησίως",
                               "ανά 8h", "ανά 12h"]),
                end.isoformat(),
                nos["id"],
            )

            pk = (rx[0], rx[1], rx[2], rx[3])
            if pk in rx_pk_seen:
                continue
            rx_pk_seen.add(pk)
            rx_rows.append(rx)

    out.append(insert("syntagografisi",
                 ["ΑΜΚΑ_ΙΑΤΡΟΥ_FK", "ΑΜΚΑ_ΑΣΘΕΝΗ_FK", "ΚΩΔΙΚΟΣ_ΦΑΡΜΑΚΟΥ_FK",
                  "ΗΜΕΡΟΜΗΝΙΑ_ΕΝΑΡΞΗΣ", "ΔΟΣΟΛΟΓΙΑ", "ΣΥΧΝΟΤΗΤΑ",
                  "ΗΜΕΡΟΜΗΝΙΑ_ΛΗΞΗΣ", "ΝΟΣΗΛΕΙΑ_FK"], rx_rows))
    nosileies_with_rx = {rx[7] for rx in rx_rows}

    # 2.24 ΑΞΙΟΛΟΓΗΣΗ_ΝΟΣΗΛΕΙΑΣ + ΑΞΙΟΛΟΓΗΣΗ_ΙΑΤΡΟΥ (μόνο για κλειστές νοσηλείες)
    out.append("-- ΑΞΙΟΛΟΓΗΣΗ_ΝΟΣΗΛΕΙΑΣ\n")
    closed = [n for n in nosileies if n["discharge"] is not None]
    aksiologhsh_nosileias_rows = []
    for n in closed:
        aksiologhsh_nosileias_rows.append((n["id"], random.randint(1, 5), random.randint(1, 5),
                                           random.randint(1, 5), random.randint(1, 5)))
    out.append(insert("aksiologhsh_nosileias",
                     ["ΝΟΣΗΛΕΙΑ_FK", "ΠΟΙΟΤΗΤΑ", "ΚΑΘΑΡΙΟΤΗΤΑ", "ΦΑΓΗΤΟ",
                      "ΣΥΝΟΛΙΚΗ_ΕΜΠΕΙΡΙΑ"], aksiologhsh_nosileias_rows))

    out.append("-- ΑΞΙΟΛΟΓΗΣΗ_ΙΑΤΡΟΥ\n")
    aksiologhsh_iatroy_rows = []
    for n in closed:
        if n["id"] in nosileies_with_rx: # type: ignore
            aksiologhsh_iatroy_rows.append((n["id"], n["doctor"], random.randint(1, 5))) # type: ignore
    out.append(insert("aksiologhsh_iatroy",
                     ["ΝΟΣΗΛΕΙΑ_FK", "ΑΜΚΑ_ΙΑΤΡΟΥ_FK", "ΦΡΟΝΤΙΔΑ"], aksiologhsh_iatroy_rows))

    out.append("-- ΕΙΚΟΝΑ\n")
    eikona_rows = []
    # Ιατροί
    for d in doctors:
        eikona_rows.append(("IATROS", d["amka"],
                        f"/images/iatros/{d['amka']}.jpg",
                        f"Φωτογραφία ιατρού {d['first']} {d['last']}"))
    # Τμήματα
    for name in DEPARTMENT_NAMES:
        eikona_rows.append(("TMIMA", name,
                             f"/images/tmima/{name}.jpg",
                             f"Φωτογραφία τμήματος {name}"))
    # Νοσηλευτές
    for n in nurses:
        eikona_rows.append(("NOSILEYTHS", n["amka"],
                            f"/images/nosileyths/{n['amka']}.jpg",
                            f"Φωτογραφία νοσηλευτή {n['first']} {n['last']}"))
    # Διοικητικό
    for a in admins:
        eikona_rows.append(("DIOIKITIKO_PROSOPIKO", a["amka"],
                            f"/images/dioikitiko/{a['amka']}.jpg",
                            f"Φωτογραφία διοικητικού {a['first']} {a['last']}"))
    # Κλίνες
    for bed_num, bed_dept in beds:
        eikona_rows.append(("KLINI", f"{bed_num}_{bed_dept}",
                            f"/images/klini/{bed_dept}_{bed_num}.jpg",
                            f"Φωτογραφία κλίνης {bed_num} τμήματος {bed_dept}"))
    # Χώροι
    for i in range(1, N_ROOMS + 1):
        eikona_rows.append(("XOROS", str(i),
                            f"/images/xoros/{i}.jpg",
                            f"Φωτογραφία χώρου {i}"))
    # Επεμβάσεις
    for ep in epemvasi_rows:
        eikona_rows.append(("EPEMBASI", str(ep[0]),
                            f"/images/epembasi/{ep[0]}.jpg",
                            f"Φωτογραφία επέμβασης {ep[4]}"))
    # Εργαστηριακές
    for r in lab_rows:
        eikona_rows.append(("ERGASTIRIAKI_EKSETASI", str(r[0]),
                            f"/images/ergastiriaki/{r[0]}.jpg",
                            f"Φωτογραφία εξέτασης {r[0]}"))

    out.append(insert("eikona",
                 ["ENTITY_TYPE", "ENTITY_ID", "PATH", "DESCRIPTION"],
                 eikona_rows))

    # ─────────────────────────────────────────────────────────────────────────
    out.append("\nSET SESSION FOREIGN_KEY_CHECKS=1;\n")
    out.append("SET SESSION UNIQUE_CHECKS=1;\n")
    out.append("SET SESSION check_constraint_checks=1;\n")
    out.append("COMMIT;\n")

    OUT_FILE.write_text("".join(out), encoding="utf-8")
    print(f"==> Wrote {OUT_FILE} ({OUT_FILE.stat().st_size // 1024} KB)")


def load_data_block(csv_dir_abs: str, fname: str, table: str,
                     cols: list[str]) -> str:
    return (
        f"LOAD DATA LOCAL INFILE '{csv_dir_abs}/{fname}'\n"
        f"INTO TABLE {table}\n"
        f"CHARACTER SET utf8mb4\n"
        f"FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"'\n"
        f"LINES TERMINATED BY '\\n'\n"
        f"IGNORE 1 LINES\n"
        f"({', '.join(cols)});\n\n"
    )


if __name__ == "__main__":
    build()
