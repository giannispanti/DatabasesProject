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