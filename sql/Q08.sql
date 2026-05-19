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