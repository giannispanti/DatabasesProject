-- Q10.sql

SELECT 
    do1.ΟΝΟΜΑ AS 'Δραστική Ουσία 1',
    do2.ΟΝΟΜΑ AS 'Δραστική Ουσία 2',
    COUNT(*) AS 'Συχνότητα Εμφάνισης (Ζεύγους)'
FROM (
    -- ΒΗΜΑ 1α: Μοναδικές ουσίες ανά νοσηλεία (Πρώτο αντίγραφο)
    SELECT DISTINCT s.ΝΟΣΗΛΕΙΑ_FK, dof.ΔΡΑΣΤΙΚΗ_ΟΥΣΙΑ_FK
    FROM SYNTAGOGRAFISI s
    JOIN DRASTIKES_OYSIES_FARMAKOY dof ON s.ΚΩΔΙΚΟΣ_ΦΑΡΜΑΚΟΥ_FK = dof.ΚΩΔΙΚΟΣ_EMA_FK
) t1
JOIN (
    -- ΒΗΜΑ 1β: Μοναδικές ουσίες ανά νοσηλεία (Δεύτερο αντίγραφο για το Self-Join)
    SELECT DISTINCT s.ΝΟΣΗΛΕΙΑ_FK, dof.ΔΡΑΣΤΙΚΗ_ΟΥΣΙΑ_FK
    FROM SYNTAGOGRAFISI s
    JOIN DRASTIKES_OYSIES_FARMAKOY dof ON s.ΚΩΔΙΚΟΣ_ΦΑΡΜΑΚΟΥ_FK = dof.ΚΩΔΙΚΟΣ_EMA_FK
) t2 
  ON t1.ΝΟΣΗΛΕΙΑ_FK = t2.ΝΟΣΗΛΕΙΑ_FK         -- Πρέπει να είναι στην ίδια νοσηλεία (ίδιος ασθενής)
  AND t1.ΔΡΑΣΤΙΚΗ_ΟΥΣΙΑ_FK < t2.ΔΡΑΣΤΙΚΗ_ΟΥΣΙΑ_FK -- Το ΜΑΓΙΚΟ ΚΟΛΠΟ για αποφυγή διπλοτύπων (π.χ. Α-Β και Β-Α)

-- Ενώνουμε με τον πίνακα DRASTIKI_OYSIA για να πάρουμε τα κανονικά ονόματα αντί για κωδικούς
JOIN DRASTIKI_OYSIA do1 ON t1.ΔΡΑΣΤΙΚΗ_ΟΥΣΙΑ_FK = do1.ΚΩΔΙΚΟΣ_ΔΟ
JOIN DRASTIKI_OYSIA do2 ON t2.ΔΡΑΣΤΙΚΗ_ΟΥΣΙΑ_FK = do2.ΚΩΔΙΚΟΣ_ΔΟ

GROUP BY 
    t1.ΔΡΑΣΤΙΚΗ_ΟΥΣΙΑ_FK, 
    t2.ΔΡΑΣΤΙΚΗ_ΟΥΣΙΑ_FK, 
    do1.ΟΝΟΜΑ, 
    do2.ΟΝΟΜΑ
ORDER BY 
    `Συχνότητα Εμφάνισης (Ζεύγους)` DESC
LIMIT 3;