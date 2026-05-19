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