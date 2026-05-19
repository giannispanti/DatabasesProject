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