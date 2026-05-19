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