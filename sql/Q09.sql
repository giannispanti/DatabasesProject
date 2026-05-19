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