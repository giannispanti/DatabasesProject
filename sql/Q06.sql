-- Q06.sql

ANALYZE 
SELECT 
    n.ΚΩΔΙΚΟΣ_ΝΟΣΗΛΕΙΑΣ AS 'Κωδ. Νοσηλείας',
    n.ΗΜΕΡΟΜΗΝΙΑ_ΕΙΣΟΔΟΥ AS 'Είσοδος',
    n.ΔΙΑΓΝΩΣΗ_ΕΙΣΟΔΟΥ_FK AS 'Διάγνωση Εισόδου',
    n.ΔΙΑΓΝΩΣΗ_ΕΞΟΔΟΥ_FK AS 'Διάγνωση Εξόδου',
    n.ΣΥΝΟΛΙΚΟ_ΚΟΣΤΟΣ AS 'Συνολικό Κόστος',
    ROUND((an.ΠΟΙΟΤΗΤΑ + an.ΚΑΘΑΡΙΟΤΗΤΑ + an.ΦΑΓΗΤΟ + an.ΣΥΝΟΛΙΚΗ_ΕΜΠΕΙΡΙΑ) / 4.0, 2) AS 'Μ.Ο. Αξιολόγησης'
FROM 
    NOSILEIA n IGNORE INDEX (idx_nosileia_pat)
LEFT JOIN 
    AKSIOLOGHSH_NOSILEIAS an ON n.ΚΩΔΙΚΟΣ_ΝΟΣΗΛΕΙΑΣ = an.ΝΟΣΗΛΕΙΑ_FK
WHERE 
    n.ΑΜΚΑ_ΑΣΘΕΝΗ_FK = '80425373377' 
ORDER BY 
    n.ΗΜΕΡΟΜΗΝΙΑ_ΕΙΣΟΔΟΥ DESC;

ANALYZE 
SELECT 
    n.ΚΩΔΙΚΟΣ_ΝΟΣΗΛΕΙΑΣ AS 'Κωδ. Νοσηλείας',
    n.ΗΜΕΡΟΜΗΝΙΑ_ΕΙΣΟΔΟΥ AS 'Είσοδος',
    n.ΔΙΑΓΝΩΣΗ_ΕΙΣΟΔΟΥ_FK AS 'Διάγνωση Εισόδου',
    n.ΔΙΑΓΝΩΣΗ_ΕΞΟΔΟΥ_FK AS 'Διάγνωση Εξόδου',
    n.ΣΥΝΟΛΙΚΟ_ΚΟΣΤΟΣ AS 'Συνολικό Κόστος',
    ROUND((an.ΠΟΙΟΤΗΤΑ + an.ΚΑΘΑΡΙΟΤΗΤΑ + an.ΦΑΓΗΤΟ + an.ΣΥΝΟΛΙΚΗ_ΕΜΠΕΙΡΙΑ) / 4.0, 2) AS 'Μ.Ο. Αξιολόγησης'
FROM 
    NOSILEIA n FORCE INDEX (idx_nosileia_pat)
LEFT JOIN 
    AKSIOLOGHSH_NOSILEIAS an ON n.ΚΩΔΙΚΟΣ_ΝΟΣΗΛΕΙΑΣ = an.ΝΟΣΗΛΕΙΑ_FK
WHERE 
    n.ΑΜΚΑ_ΑΣΘΕΝΗ_FK = '80425373377' 
ORDER BY 
    n.ΗΜΕΡΟΜΗΝΙΑ_ΕΙΣΟΔΟΥ DESC;