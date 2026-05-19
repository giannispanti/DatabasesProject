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