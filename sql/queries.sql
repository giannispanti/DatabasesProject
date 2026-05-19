-- Q01.sql

SELECT 
    n.ΤΜΗΜΑ_FK AS 'Τμήμα',
    YEAR(n.ΗΜΕΡΟΜΗΝΙΑ_ΕΞΟΔΟΥ) AS 'Έτος',
    n.ΚΕΝ_FK AS 'Κωδικός ΚΕΝ',
    a.ΑΣΦΑΛΙΣΤΙΚΟΣ_ΦΟΡΕΑΣ_FK AS 'Ασφαλιστικός Φορέας',
    
    COUNT(n.ΚΩΔΙΚΟΣ_ΝΟΣΗΛΕΙΑΣ) AS 'Πλήθος Νοσηλειών',
    
    SUM(kost.ΒΑΣΙΚΟ_ΚΟΣΤΟΣ) AS 'Συνολικό Βασικό Έσοδο',
    
    SUM(
        CASE 
            WHEN DATEDIFF(n.ΗΜΕΡΟΜΗΝΙΑ_ΕΞΟΔΟΥ, n.ΗΜΕΡΟΜΗΝΙΑ_ΕΙΣΟΔΟΥ) > k.ΜΔΝ 
            THEN (DATEDIFF(n.ΗΜΕΡΟΜΗΝΙΑ_ΕΞΟΔΟΥ, n.ΗΜΕΡΟΜΗΝΙΑ_ΕΙΣΟΔΟΥ) - k.ΜΔΝ) * kost.ΗΜΕΡΗΣΙΑ_ΠΡΟΣΘΕΤΗ_ΧΡΕΩΣΗ
            ELSE 0 
        END
    ) AS 'Συνολική Πρόσθετη Χρέωση',
    SUM(n.ΣΥΝΟΛΙΚΟ_ΚΟΣΤΟΣ) AS 'Τελικό Σύνολο Εσόδων'
FROM 
    NOSILEIA n
JOIN 
    ASTHENIS a ON n.ΑΜΚΑ_ΑΣΘΕΝΗ_FK = a.ΑΜΚΑ
JOIN 
    KEN k ON n.ΚΕΝ_FK = k.ΚΩΔΙΚΟΣ_ΚΕΝ
JOIN 
    KOSTOLOGHSH kost ON n.ΚΕΝ_FK = kost.ΚΕΝ_FK AND a.ΑΣΦΑΛΙΣΤΙΚΟΣ_ΦΟΡΕΑΣ_FK = kost.ΑΣΦΑΛΙΣΤΙΚΟΣ_ΦΟΡΕΑΣ_FK
WHERE 
    n.ΗΜΕΡΟΜΗΝΙΑ_ΕΞΟΔΟΥ IS NOT NULL
GROUP BY 
    n.ΤΜΗΜΑ_FK, 
    YEAR(n.ΗΜΕΡΟΜΗΝΙΑ_ΕΞΟΔΟΥ), 
    n.ΚΕΝ_FK, 
    a.ΑΣΦΑΛΙΣΤΙΚΟΣ_ΦΟΡΕΑΣ_FK
ORDER BY 
    'Έτος' DESC, 
    n.ΤΜΗΜΑ_FK ASC, 
    'Τελικό Σύνολο Εσόδων' DESC;

-- Q02.sql

SELECT 
    i.ΑΜΚΑ_FK AS 'ΑΜΚΑ',
    p.ΕΠΩΝΥΜΟ AS 'Επώνυμο',
    p.ΟΝΟΜΑ AS 'Όνομα',
    
    (SELECT IF(COUNT(*) > 0, 'ΝΑΙ', 'ΟΧΙ')
     FROM EFIMERIA_PROSOPIKOY ep
     WHERE ep.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK = i.ΑΜΚΑ_FK 
       AND YEAR(ep.ΗΜΕΡΟΜΗΝΙΑ_FK) = 2025
    ) AS 'Εφημερία Φέτος',
    
    (SELECT COUNT(*)
     FROM EPEMBASI e
     WHERE e.ΑΜΚΑ_ΚΥΡΙΟΥ_ΙΑΤΡΟΥ_FK = i.ΑΜΚΑ_FK
    ) AS 'Πλήθος Επεμβάσεων'

FROM 
    IATROS i
JOIN 
    PROSOPIKO p ON i.ΑΜΚΑ_FK = p.ΑΜΚΑ
WHERE 
    i.ΕΙΔΙΚΟΤΗΤΑ = 'ΓΕΝΙΚΗ ΧΕΙΡΟΥΡΓΙΚΗ' -- Βάζουμε όποια ειδικότητα θέλουμε
ORDER BY 
    p.ΕΠΩΝΥΜΟ ASC, 
    p.ΟΝΟΜΑ ASC;

-- Q03.sql

SELECT 
    a.ΑΜΚΑ,
    a.ΕΠΩΝΥΜΟ AS 'Επώνυμο',
    a.ΟΝΟΜΑ AS 'Όνομα',
    n.ΤΜΗΜΑ_FK AS 'Τμήμα',
    
    COUNT(n.ΚΩΔΙΚΟΣ_ΝΟΣΗΛΕΙΑΣ) AS 'Πλήθος Νοσηλειών',
    
    SUM(n.ΣΥΝΟΛΙΚΟ_ΚΟΣΤΟΣ) AS 'Συνολικό Κόστος'

FROM 
    ASTHENIS a
JOIN 
    NOSILEIA n ON a.ΑΜΚΑ = n.ΑΜΚΑ_ΑΣΘΕΝΗ_FK
WHERE 
    n.ΗΜΕΡΟΜΗΝΙΑ_ΕΞΟΔΟΥ IS NOT NULL
GROUP BY 
    a.ΑΜΚΑ, 
    a.ΕΠΩΝΥΜΟ, 
    a.ΟΝΟΜΑ, 
    n.ΤΜΗΜΑ_FK
HAVING 
    COUNT(n.ΚΩΔΙΚΟΣ_ΝΟΣΗΛΕΙΑΣ) > 3
ORDER BY 
    'Πλήθος Νοσηλειών' DESC, 
    'Συνολικό Κόστος' DESC;

-- Q04.sql

ANALYZE
SELECT 
    p.ΕΠΩΝΥΜΟ AS 'Επώνυμο Ιατρού',
    p.ΟΝΟΜΑ AS 'Όνομα Ιατρού',
    ROUND(AVG(ai.ΦΡΟΝΤΙΔΑ), 2) AS 'Μ.Ο. Ποιότητας Φροντίδας',
    ROUND(AVG(an.ΣΥΝΟΛΙΚΗ_ΕΜΠΕΙΡΙΑ), 2) AS 'Μ.Ο. Συνολικής Εμπειρίας'
FROM 
    AKSIOLOGHSH_IATROY ai IGNORE INDEX (idx_eval_doc_amka)
JOIN 
    PROSOPIKO p ON ai.ΑΜΚΑ_ΙΑΤΡΟΥ_FK = p.ΑΜΚΑ
JOIN 
    AKSIOLOGHSH_NOSILEIAS an ON ai.ΝΟΣΗΛΕΙΑ_FK = an.ΝΟΣΗΛΕΙΑ_FK
WHERE 
    ai.ΑΜΚΑ_ΙΑΤΡΟΥ_FK = '32003791769' 
GROUP BY 
    ai.ΑΜΚΑ_ΙΑΤΡΟΥ_FK, p.ΕΠΩΝΥΜΟ, p.ΟΝΟΜΑ;

ANALYZE
SELECT 
    p.ΕΠΩΝΥΜΟ AS 'Επώνυμο Ιατρού',
    p.ΟΝΟΜΑ AS 'Όνομα Ιατρού',
    ROUND(AVG(ai.ΦΡΟΝΤΙΔΑ), 2) AS 'Μ.Ο. Ποιότητας Φροντίδας',
    ROUND(AVG(an.ΣΥΝΟΛΙΚΗ_ΕΜΠΕΙΡΙΑ), 2) AS 'Μ.Ο. Συνολικής Εμπειρίας'
FROM 
    AKSIOLOGHSH_IATROY ai FORCE INDEX (idx_eval_doc_amka)
JOIN 
    PROSOPIKO p ON ai.ΑΜΚΑ_ΙΑΤΡΟΥ_FK = p.ΑΜΚΑ
JOIN 
    AKSIOLOGHSH_NOSILEIAS an ON ai.ΝΟΣΗΛΕΙΑ_FK = an.ΝΟΣΗΛΕΙΑ_FK
WHERE 
    ai.ΑΜΚΑ_ΙΑΤΡΟΥ_FK = '32003791769' 
GROUP BY 
    ai.ΑΜΚΑ_ΙΑΤΡΟΥ_FK, p.ΕΠΩΝΥΜΟ, p.ΟΝΟΜΑ;

-- Q05.sql

SELECT 
    p.ΑΜΚΑ AS 'ΑΜΚΑ Ιατρού',
    p.ΕΠΩΝΥΜΟ AS 'Επώνυμο',
    p.ΟΝΟΜΑ AS 'Όνομα',
    
    TIMESTAMPDIFF(YEAR, p.ΗΜΕΡΟΜΗΝΙΑ_ΓΕΝΝΗΣΗΣ, CURDATE()) AS 'Ηλικία',
    COUNT(e.ΚΩΔΙΚΟΣ) AS 'Πλήθος Επεμβάσεων'
FROM 
    PROSOPIKO p
JOIN 
    EPEMBASI e ON p.ΑΜΚΑ = e.ΑΜΚΑ_ΚΥΡΙΟΥ_ΙΑΤΡΟΥ_FK
WHERE 
    p.ΗΜΕΡΟΜΗΝΙΑ_ΓΕΝΝΗΣΗΣ > DATE_SUB(CURDATE(), INTERVAL 35 YEAR)
GROUP BY 
    p.ΑΜΚΑ, 
    p.ΕΠΩΝΥΜΟ, 
    p.ΟΝΟΜΑ, 
    p.ΗΜΕΡΟΜΗΝΙΑ_ΓΕΝΝΗΣΗΣ
ORDER BY 
    COUNT(e.ΚΩΔΙΚΟΣ) DESC;

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

-- Q07.sql

SELECT 
    d.ΚΩΔΙΚΟΣ_ΔΟ AS KODIKOS_OUSIAS,
    d.ΟΝΟΜΑ AS ONOMA_OUSIAS,
    COUNT(DISTINCT a.ΑΜΚΑ_ΑΣΘΕΝΗ_FK) AS ARITHMOS_ASTHENON,
    COUNT(DISTINCT df.ΚΩΔΙΚΟΣ_EMA_FK) AS ARITHMOS_FARMAKON
FROM 
    DRASTIKI_OYSIA d
LEFT JOIN 
    ALLERGIES a ON d.ΚΩΔΙΚΟΣ_ΔΟ = a.ΔΡΑΣΤΙΚΗ_ΟΥΣΙΑ_FK
LEFT JOIN 
    DRASTIKES_OYSIES_FARMAKOY df ON d.ΚΩΔΙΚΟΣ_ΔΟ = df.ΔΡΑΣΤΙΚΗ_ΟΥΣΙΑ_FK
GROUP BY 
    d.ΚΩΔΙΚΟΣ_ΔΟ, 
    d.ΟΝΟΜΑ
ORDER BY 
    ARITHMOS_ASTHENON DESC;

-- Q08.sql

SELECT 
    p.ΑΜΚΑ, 
    p.ΕΠΩΝΥΜΟ, 
    p.ΟΝΟΜΑ, 
    p.ΤΥΠΟΣ_ΠΡΟΣΩΠΙΚΟΥ AS 'Ειδικότητα'
FROM 
    PROSOPIKO p
WHERE 
    NOT EXISTS (
        SELECT 1
        FROM EFIMERIA_PROSOPIKOY ep
        WHERE ep.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK = p.ΑΜΚΑ
          AND ep.ΗΜΕΡΟΜΗΝΙΑ_FK = '2025-04-09' -- Η συγκεκριμένη ημερομηνία
          AND ep.ΤΜΗΜΑ_FK = 'ΟΡΘΟΠΕΔΙΚΗ'      -- Το συγκεκριμένο τμήμα
    )
ORDER BY 
    p.ΤΥΠΟΣ_ΠΡΟΣΩΠΙΚΟΥ ASC, 
    p.ΕΠΩΝΥΜΟ ASC, 
    p.ΟΝΟΜΑ ASC;

-- Q09.sql

SELECT 
    ys.ΕΤΟΣ AS 'Έτος',
    ys.ΣΥΝΟΛΟ_ΗΜΕΡΩΝ AS 'Συνολικές Ημέρες Νοσηλείας',
    COUNT(ys.ΑΜΚΑ) AS 'Πλήθος Ασθενών',
    GROUP_CONCAT(ys.ΑΜΚΑ SEPARATOR ', ') AS 'ΑΜΚΑ Ασθενών'
    
FROM (
    SELECT 
        ΑΜΚΑ_ΑΣΘΕΝΗ_FK AS ΑΜΚΑ,
        YEAR(ΗΜΕΡΟΜΗΝΙΑ_ΕΙΣΟΔΟΥ) AS ΕΤΟΣ,
        SUM(DATEDIFF(ΗΜΕΡΟΜΗΝΙΑ_ΕΞΟΔΟΥ, ΗΜΕΡΟΜΗΝΙΑ_ΕΙΣΟΔΟΥ)) AS ΣΥΝΟΛΟ_ΗΜΕΡΩΝ
    FROM 
        NOSILEIA
    WHERE 
        ΗΜΕΡΟΜΗΝΙΑ_ΕΞΟΔΟΥ IS NOT NULL 
    GROUP BY 
        ΑΜΚΑ_ΑΣΘΕΝΗ_FK, 
        YEAR(ΗΜΕΡΟΜΗΝΙΑ_ΕΙΣΟΔΟΥ)
    HAVING 
        SUM(DATEDIFF(ΗΜΕΡΟΜΗΝΙΑ_ΕΞΟΔΟΥ, ΗΜΕΡΟΜΗΝΙΑ_ΕΙΣΟΔΟΥ)) > 15
) AS ys

GROUP BY 
    ys.ΕΤΟΣ, 
    ys.ΣΥΝΟΛΟ_ΗΜΕΡΩΝ
HAVING 
    COUNT(ys.ΑΜΚΑ) > 1
ORDER BY 
    ys.ΕΤΟΣ DESC, 
    ys.ΣΥΝΟΛΟ_ΗΜΕΡΩΝ DESC;

-- Q10.sql

SELECT 
    do1.ΟΝΟΜΑ AS 'Δραστική Ουσία 1',
    do2.ΟΝΟΜΑ AS 'Δραστική Ουσία 2',
    COUNT(*) AS 'Συχνότητα Εμφάνισης (Ζεύγους)'
FROM (
    -- ΒΗΜΑ 1α: Μοναδικές ουσίες ανά νοσηλεία (Πρώτο αντίγραφο)
    SELECT DISTINCT s.ΝΟΣΗΛΕΙΑ_FK, dof.ΔΡΑΣΤΙΚΗ_ΟΥΣΙΑ_FK
    FROM SYNTAGOGRAFISI s
    JOIN DRASTIKES_OYSIES_FARMAKOY dof ON s.ΚΩΔΙΚΟΣ_ΦΑΡΜΑΚΟΥ_FK = dof.ΚΩΔΙΚΟΣ_EMA_FK
) t1
JOIN (
    -- ΒΗΜΑ 1β: Μοναδικές ουσίες ανά νοσηλεία (Δεύτερο αντίγραφο για το Self-Join)
    SELECT DISTINCT s.ΝΟΣΗΛΕΙΑ_FK, dof.ΔΡΑΣΤΙΚΗ_ΟΥΣΙΑ_FK
    FROM SYNTAGOGRAFISI s
    JOIN DRASTIKES_OYSIES_FARMAKOY dof ON s.ΚΩΔΙΚΟΣ_ΦΑΡΜΑΚΟΥ_FK = dof.ΚΩΔΙΚΟΣ_EMA_FK
) t2 
  ON t1.ΝΟΣΗΛΕΙΑ_FK = t2.ΝΟΣΗΛΕΙΑ_FK         -- Πρέπει να είναι στην ίδια νοσηλεία (ίδιος ασθενής)
  AND t1.ΔΡΑΣΤΙΚΗ_ΟΥΣΙΑ_FK < t2.ΔΡΑΣΤΙΚΗ_ΟΥΣΙΑ_FK -- Το ΜΑΓΙΚΟ ΚΟΛΠΟ για αποφυγή διπλοτύπων (π.χ. Α-Β και Β-Α)

-- Ενώνουμε με τον πίνακα DRASTIKI_OYSIA για να πάρουμε τα κανονικά ονόματα αντί για κωδικούς
JOIN DRASTIKI_OYSIA do1 ON t1.ΔΡΑΣΤΙΚΗ_ΟΥΣΙΑ_FK = do1.ΚΩΔΙΚΟΣ_ΔΟ
JOIN DRASTIKI_OYSIA do2 ON t2.ΔΡΑΣΤΙΚΗ_ΟΥΣΙΑ_FK = do2.ΚΩΔΙΚΟΣ_ΔΟ

GROUP BY 
    t1.ΔΡΑΣΤΙΚΗ_ΟΥΣΙΑ_FK, 
    t2.ΔΡΑΣΤΙΚΗ_ΟΥΣΙΑ_FK, 
    do1.ΟΝΟΜΑ, 
    do2.ΟΝΟΜΑ
ORDER BY 
    `Συχνότητα Εμφάνισης (Ζεύγους)` DESC
LIMIT 3;

-- Q11.sql

SELECT 
    p.ΑΜΚΑ AS 'ΑΜΚΑ Ιατρού',
    p.ΕΠΩΝΥΜΟ AS 'Επώνυμο',
    p.ΟΝΟΜΑ AS 'Όνομα',
    COUNT(e.ΚΩΔΙΚΟΣ) AS 'Φετινές Επεμβάσεις'
FROM 
    PROSOPIKO p
JOIN 
    IATROS i ON p.ΑΜΚΑ = i.ΑΜΚΑ_FK
-- Χρησιμοποιούμε LEFT JOIN και βάζουμε το έτος στο ON, 
-- ώστε να μην χάσουμε τους ιατρούς με 0 επεμβάσεις
LEFT JOIN 
    EPEMBASI e ON i.ΑΜΚΑ_FK = e.ΑΜΚΑ_ΚΥΡΙΟΥ_ΙΑΤΡΟΥ_FK 
              AND YEAR(e.ΗΜΕΡΟΜΗΝΙΑ) = 2024
GROUP BY 
    p.ΑΜΚΑ, 
    p.ΕΠΩΝΥΜΟ, 
    p.ΟΝΟΜΑ
HAVING 
    COUNT(e.ΚΩΔΙΚΟΣ) <= (
        -- ΥΠΟΕΡΩΤΗΜΑ: Βρίσκει τον μέγιστο αριθμό επεμβάσεων φέτος από έναν ιατρό
        SELECT COUNT(ΚΩΔΙΚΟΣ)
        FROM EPEMBASI
        WHERE YEAR(ΗΜΕΡΟΜΗΝΙΑ) = 2024
        GROUP BY ΑΜΚΑ_ΚΥΡΙΟΥ_ΙΑΤΡΟΥ_FK
        ORDER BY COUNT(ΚΩΔΙΚΟΣ) DESC
        LIMIT 1
    ) - 5
ORDER BY 
    'Φετινές Επεμβάσεις' DESC,
    p.ΕΠΩΝΥΜΟ ASC;

-- Q12.sql

SELECT 
    ep.ΤΜΗΜΑ_FK AS 'Τμήμα',
    ep.ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK AS 'Βάρδια',
    p.ΤΥΠΟΣ_ΠΡΟΣΩΠΙΚΟΥ AS 'Τύπος Προσωπικού',
    
    COALESCE(i.ΕΙΔΙΚΟΤΗΤΑ, n.ΒΑΘΜΙΔΑ, dp.ΡΟΛΟΣ) AS 'Υποκλάση (Ειδικότητα/Βαθμίδα/Ρόλος)',
    
    COUNT(ep.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK) AS 'Προγραμματισμένος Αριθμός'

FROM 
    EFIMERIA_PROSOPIKOY ep
JOIN 
    PROSOPIKO p ON ep.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK = p.ΑΜΚΑ
LEFT JOIN 
    IATROS i ON p.ΑΜΚΑ = i.ΑΜΚΑ_FK
LEFT JOIN 
    NOSILEYTHS n ON p.ΑΜΚΑ = n.ΑΜΚΑ_FK
LEFT JOIN 
    DIOIKITIKO_PROSOPIKO dp ON p.ΑΜΚΑ = dp.ΑΜΚΑ_FK

WHERE 
    ep.ΗΜΕΡΟΜΗΝΙΑ_FK BETWEEN '2025-04-07' AND '2025-04-13'

GROUP BY 
    ep.ΤΜΗΜΑ_FK,
    ep.ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK,
    p.ΤΥΠΟΣ_ΠΡΟΣΩΠΙΚΟΥ,
    COALESCE(i.ΕΙΔΙΚΟΤΗΤΑ, n.ΒΑΘΜΙΔΑ, dp.ΡΟΛΟΣ)

ORDER BY 
    ep.ΤΜΗΜΑ_FK ASC, 
    ep.ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK ASC, 
    p.ΤΥΠΟΣ_ΠΡΟΣΩΠΙΚΟΥ ASC;

-- Q13.sql

WITH RECURSIVE SupervisionHierarchy AS (
    -- ΒΗΜΑ 1: Anchor Member (Το 1ο επίπεδο - Άμεσος Επόπτης)
    SELECT 
        i.ΑΜΚΑ_FK AS Doctor_AMKA,
        i.ΑΜΚΑ_ΕΠΟΠΤΗ_FK AS Supervisor_AMKA,
        1 AS Supervision_Level
    FROM 
        IATROS i
    WHERE 
        i.ΑΜΚΑ_ΕΠΟΠΤΗ_FK IS NOT NULL

    UNION ALL

    -- ΒΗΜΑ 2: Recursive Member (Ανεβαίνουμε τα επίπεδα μέχρι τον Διευθυντή)
    SELECT 
        sh.Doctor_AMKA,
        i_sup.ΑΜΚΑ_ΕΠΟΠΤΗ_FK AS Supervisor_AMKA,
        sh.Supervision_Level + 1 AS Supervision_Level
    FROM 
        SupervisionHierarchy sh
    JOIN 
        IATROS i_sup ON sh.Supervisor_AMKA = i_sup.ΑΜΚΑ_FK
    WHERE 
        i_sup.ΑΜΚΑ_ΕΠΟΠΤΗ_FK IS NOT NULL
)

-- ΒΗΜΑ 3: Τελικό SELECT για την εμφάνιση των αποτελεσμάτων με Ονοματεπώνυμα
SELECT 
    p_doc.ΕΠΩΝΥΜΟ AS 'Επώνυμο Ιατρού',
    p_doc.ΟΝΟΜΑ AS 'Όνομα Ιατρού',
    i_doc.ΒΑΘΜΙΔΑ AS 'Βαθμίδα',
    sh.Supervision_Level AS 'Επίπεδο Εποπτείας',
    p_sup.ΕΠΩΝΥΜΟ AS 'Επώνυμο Επόπτη',
    p_sup.ΟΝΟΜΑ AS 'Όνομα Επόπτη',
    i_sup.ΒΑΘΜΙΔΑ AS 'Βαθμίδα Επόπτη'
FROM 
    SupervisionHierarchy sh
JOIN 
    IATROS i_doc ON sh.Doctor_AMKA = i_doc.ΑΜΚΑ_FK
JOIN 
    PROSOPIKO p_doc ON sh.Doctor_AMKA = p_doc.ΑΜΚΑ
JOIN 
    IATROS i_sup ON sh.Supervisor_AMKA = i_sup.ΑΜΚΑ_FK
JOIN 
    PROSOPIKO p_sup ON sh.Supervisor_AMKA = p_sup.ΑΜΚΑ
ORDER BY 
    p_doc.ΕΠΩΝΥΜΟ ASC, 
    p_doc.ΟΝΟΜΑ ASC, 
    sh.Supervision_Level ASC;

-- Q14.sql

WITH YearlyAdmissions AS (
    SELECT 
        ΔΙΑΓΝΩΣΗ_ΕΙΣΟΔΟΥ_FK AS ICD10,
        YEAR(ΗΜΕΡΟΜΗΝΙΑ_ΕΙΣΟΔΟΥ) AS Ετος,
        COUNT(ΚΩΔΙΚΟΣ_ΝΟΣΗΛΕΙΑΣ) AS Πλήθος
    FROM 
        NOSILEIA
    GROUP BY 
        ΔΙΑΓΝΩΣΗ_ΕΙΣΟΔΟΥ_FK, 
        YEAR(ΗΜΕΡΟΜΗΝΙΑ_ΕΙΣΟΔΟΥ)
    HAVING 
        COUNT(ΚΩΔΙΚΟΣ_ΝΟΣΗΛΕΙΑΣ) >= 5 -- Φίλτρο: τουλάχιστον 5 περιστατικά
)

SELECT 
    y1.ICD10 AS 'Κωδικός ICD-10',
    d.ΠΕΡΙΓΡΑΦΗ AS 'Περιγραφή Διάγνωσης',
    y1.Ετος AS 'Έτος 1',
    y2.Ετος AS 'Έτος 2',
    y1.Πλήθος AS 'Αριθμός Εισαγωγών (Κοινός)'
FROM 
    YearlyAdmissions y1
JOIN 
    YearlyAdmissions y2 
    ON y1.ICD10 = y2.ICD10                
    AND y2.Ετος = y1.Ετος + 1             
    AND y1.Πλήθος = y2.Πλήθος             
JOIN 
    DIAGNOSI d ON y1.ICD10 = d.ΚΩΔΙΚΟΣ_ICD10 
ORDER BY 
    y1.ICD10 ASC, 
    y1.Ετος ASC;

-- Q15.sql

SELECT 
    ls.Level AS 'Επίπεδο Επείγοντος (Triage)',
    ls.TotalCases AS 'Σύνολο Περιστατικών',
    ROUND(ls.AvgWaitMin, 1) AS 'Μέσος Χρόνος Αναμονής (Λεπτά)',
    ROUND(ls.AdmissionRate, 1) AS 'Ποσοστό Εισαγωγών (%)',
    COALESCE(dd.TMHMA, 'ΧΩΡΙΣ ΝΟΣΗΛΕΙΑ (Εξιτήριο/Άλλο)') AS 'Τμήμα Παραπομπής',
    COALESCE(dd.DeptCases, 0) AS 'Περιστατικά ανά Τμήμα'
FROM (
    -- ΒΗΜΑ 1 (Υποερώτημα 1): Γενικά Στατιστικά ανά Επίπεδο Επείγοντος
    SELECT 
        ΕΠΙΠΕΔΟ_ΕΠΕΙΓΟΝΤΟΣ AS Level,
        COUNT(ΑΜΚΑ_ΑΣΘΕΝΗ_FK) AS TotalCases,
        
        -- Μέσος χρόνος αναμονής σε λεπτά (από άφιξη μέχρι εξυπηρέτηση)
        AVG(TIMESTAMPDIFF(MINUTE, ΩΡΑ_ΑΦΙΞΗΣ, ΩΡΑ_ΕΞΥΠΗΡΕΤΗΣΗΣ)) AS AvgWaitMin,
        
        -- Ποσοστό που οδήγησε σε νοσηλεία (ΝΟΣΗΛΕΙΑ_FK is not null)
        (SUM(CASE WHEN ΝΟΣΗΛΕΙΑ_FK IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(ΑΜΚΑ_ΑΣΘΕΝΗ_FK)) AS AdmissionRate
    FROM 
        DIALOGI
    GROUP BY 
        ΕΠΙΠΕΔΟ_ΕΠΕΙΓΟΝΤΟΣ
) AS ls

LEFT JOIN (
    -- ΒΗΜΑ 2 (Υποερώτημα 2): Κατανομή μόνο αυτών που έκαναν Εισαγωγή, ανά Τμήμα
    SELECT 
        d.ΕΠΙΠΕΔΟ_ΕΠΕΙΓΟΝΤΟΣ AS Level,
        n.ΤΜΗΜΑ_FK AS TMHMA,
        COUNT(d.ΑΜΚΑ_ΑΣΘΕΝΗ_FK) AS DeptCases
    FROM 
        DIALOGI d
    JOIN 
        NOSILEIA n ON d.ΝΟΣΗΛΕΙΑ_FK = n.ΚΩΔΙΚΟΣ_ΝΟΣΗΛΕΙΑΣ
    GROUP BY 
        d.ΕΠΙΠΕΔΟ_ΕΠΕΙΓΟΝΤΟΣ, 
        n.ΤΜΗΜΑ_FK
) AS dd ON ls.Level = dd.Level

ORDER BY 
    ls.Level ASC, 
    dd.DeptCases DESC;