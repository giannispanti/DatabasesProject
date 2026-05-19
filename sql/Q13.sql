-- Q13.sql

WITH RECURSIVE SupervisionHierarchy AS (
    -- ΒΗΜΑ 1: Anchor Member (Το 1ο επίπεδο - Άμεσος Επόπτης)
    SELECT 
        i.ΑΜΚΑ_FK AS Doctor_AMKA,
        i.ΑΜΚΑ_ΕΠΟΠΤΗ_FK AS Supervisor_AMKA,
        1 AS Supervision_Level
    FROM 
        IATROS i
    WHERE 
        i.ΑΜΚΑ_ΕΠΟΠΤΗ_FK IS NOT NULL

    UNION ALL

    -- ΒΗΜΑ 2: Recursive Member (Ανεβαίνουμε τα επίπεδα μέχρι τον Διευθυντή)
    SELECT 
        sh.Doctor_AMKA,
        i_sup.ΑΜΚΑ_ΕΠΟΠΤΗ_FK AS Supervisor_AMKA,
        sh.Supervision_Level + 1 AS Supervision_Level
    FROM 
        SupervisionHierarchy sh
    JOIN 
        IATROS i_sup ON sh.Supervisor_AMKA = i_sup.ΑΜΚΑ_FK
    WHERE 
        i_sup.ΑΜΚΑ_ΕΠΟΠΤΗ_FK IS NOT NULL
)

-- ΒΗΜΑ 3: Τελικό SELECT για την εμφάνιση των αποτελεσμάτων με Ονοματεπώνυμα
SELECT 
    p_doc.ΕΠΩΝΥΜΟ AS 'Επώνυμο Ιατρού',
    p_doc.ΟΝΟΜΑ AS 'Όνομα Ιατρού',
    i_doc.ΒΑΘΜΙΔΑ AS 'Βαθμίδα',
    sh.Supervision_Level AS 'Επίπεδο Εποπτείας',
    p_sup.ΕΠΩΝΥΜΟ AS 'Επώνυμο Επόπτη',
    p_sup.ΟΝΟΜΑ AS 'Όνομα Επόπτη',
    i_sup.ΒΑΘΜΙΔΑ AS 'Βαθμίδα Επόπτη'
FROM 
    SupervisionHierarchy sh
JOIN 
    IATROS i_doc ON sh.Doctor_AMKA = i_doc.ΑΜΚΑ_FK
JOIN 
    PROSOPIKO p_doc ON sh.Doctor_AMKA = p_doc.ΑΜΚΑ
JOIN 
    IATROS i_sup ON sh.Supervisor_AMKA = i_sup.ΑΜΚΑ_FK
JOIN 
    PROSOPIKO p_sup ON sh.Supervisor_AMKA = p_sup.ΑΜΚΑ
ORDER BY 
    p_doc.ΕΠΩΝΥΜΟ ASC, 
    p_doc.ΟΝΟΜΑ ASC, 
    sh.Supervision_Level ASC;