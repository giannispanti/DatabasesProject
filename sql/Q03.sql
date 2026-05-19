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