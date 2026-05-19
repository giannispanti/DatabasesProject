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