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