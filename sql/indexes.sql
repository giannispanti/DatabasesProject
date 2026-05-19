-- Q01.sql
CREATE INDEX idx_nosileia_exodos ON NOSILEIA(ΗΜΕΡΟΜΗΝΙΑ_ΕΞΟΔΟΥ);
CREATE INDEX idx_asthenis_foreas ON ASTHENIS(ΑΜΚΑ, ΑΣΦΑΛΙΣΤΙΚΟΣ_ΦΟΡΕΑΣ_FK);

-- Q02.sql
CREATE INDEX idx_iatros_eidikotita ON IATROS(ΕΙΔΙΚΟΤΗΤΑ);
CREATE INDEX idx_epem_kirios ON EPEMBASI(ΑΜΚΑ_ΚΥΡΙΟΥ_ΙΑΤΡΟΥ_FK);
CREATE INDEX idx_efimeria_psn_year ON EFIMERIA_PROSOPIKOY(ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK, ΗΜΕΡΟΜΗΝΙΑ_FK);

-- Q03.sql
CREATE INDEX idx_nosileia_pat_dept ON NOSILEIA(ΑΜΚΑ_ΑΣΘΕΝΗ_FK, ΤΜΗΜΑ_FK);

-- Q04.sql
CREATE INDEX idx_eval_doc_amka ON AKSIOLOGHSH_IATROY(ΑΜΚΑ_ΙΑΤΡΟΥ_FK);

-- Q05.sql
CREATE INDEX idx_psn_birth ON PROSOPIKO(ΗΜΕΡΟΜΗΝΙΑ_ΓΕΝΝΗΣΗΣ);
CREATE INDEX idx_epem_kirios ON EPEMBASI(ΑΜΚΑ_ΚΥΡΙΟΥ_ΙΑΤΡΟΥ_FK);

-- Q06.sql
CREATE INDEX idx_nosileia_pat ON NOSILEIA(ΑΜΚΑ_ΑΣΘΕΝΗ_FK);

-- Q07.sql
CREATE INDEX idx_all_ousia ON ALLERGIES(ΔΡΑΣΤΙΚΗ_ΟΥΣΙΑ_FK);
CREATE INDEX idx_dof_ousia ON DRASTIKES_OYSIES_FARMAKOY(ΔΡΑΣΤΙΚΗ_ΟΥΣΙΑ_FK);

-- Q08.sql
CREATE INDEX idx_efimeria_check ON EFIMERIA_PROSOPIKOY(ΗΜΕΡΟΜΗΝΙΑ_FK, ΤΜΗΜΑ_FK, ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK);

-- Q09.sql
CREATE INDEX idx_nosileia_amka_dates ON NOSILEIA(ΑΜΚΑ_ΑΣΘΕΝΗ_FK, ΗΜΕΡΟΜΗΝΙΑ_ΕΙΣΟΔΟΥ, ΗΜΕΡΟΜΗΝΙΑ_ΕΞΟΔΟΥ);

-- Q10.sql
CREATE INDEX idx_syntago_nosileia ON SYNTAGOGRAFISI(ΝΟΣΗΛΕΙΑ_FK);

-- Q11.sql
CREATE INDEX idx_epembasi_date_doc ON EPEMBASI(ΗΜΕΡΟΜΗΝΙΑ, ΑΜΚΑ_ΚΥΡΙΟΥ_ΙΑΤΡΟΥ_FK);

-- Q12.sql
CREATE INDEX idx_efim_date_dept_shift ON EFIMERIA_PROSOPIKOY(ΗΜΕΡΟΜΗΝΙΑ_FK, ΤΜΗΜΑ_FK, ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK);

-- Q13.sql
CREATE INDEX idx_iatros_epoptis ON IATROS(ΑΜΚΑ_ΕΠΟΠΤΗ_FK);

-- Q14.sql
CREATE INDEX idx_nosileia_icd_date ON NOSILEIA(ΔΙΑΓΝΩΣΗ_ΕΙΣΟΔΟΥ_FK, ΗΜΕΡΟΜΗΝΙΑ_ΕΙΣΟΔΟΥ);

-- Q15.sql
CREATE INDEX idx_dialogi_stats ON DIALOGI(ΕΠΙΠΕΔΟ_ΕΠΕΙΓΟΝΤΟΣ, ΝΟΣΗΛΕΙΑ_FK);