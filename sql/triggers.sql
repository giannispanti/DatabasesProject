-- TRIGGER: ΗΜΕΡΟΜΗΝΙΑ_ΓΕΝΝΗΣΗΣ προσωπικού δεν μπορεί να είναι στο μέλλον
DELIMITER //

CREATE TRIGGER trg_psn_birth_not_future_insert
BEFORE INSERT ON PROSOPIKO
FOR EACH ROW
BEGIN
    IF NEW.ΗΜΕΡΟΜΗΝΙΑ_ΓΕΝΝΗΣΗΣ >= CURDATE() THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ΗΜΕΡΟΜΗΝΙΑ_ΓΕΝΝΗΣΗΣ προσωπικού πρέπει να είναι στο παρελθόν';
    END IF;
END //

CREATE TRIGGER trg_psn_birth_not_future_update
BEFORE UPDATE ON PROSOPIKO
FOR EACH ROW
BEGIN
    IF NEW.ΗΜΕΡΟΜΗΝΙΑ_ΓΕΝΝΗΣΗΣ >= CURDATE() THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ΗΜΕΡΟΜΗΝΙΑ_ΓΕΝΝΗΣΗΣ προσωπικού πρέπει να είναι στο παρελθόν';
    END IF;
END //

DELIMITER ;

-- TRIGGER: αποτροπή κυκλικής εποπτείας μήκους 2 (αν Α επιβλέπει τον Β, ο Β δεν γίνεται να επιβλέπει τον Α)

DELIMITER //

CREATE TRIGGER trg_doc_no_2cycle_insert
BEFORE INSERT ON IATROS
FOR EACH ROW
BEGIN
    IF NEW.ΑΜΚΑ_ΕΠΟΠΤΗ_FK IS NOT NULL THEN
        IF EXISTS (
            SELECT 1 FROM IATROS
            WHERE ΑΜΚΑ_FK = NEW.ΑΜΚΑ_ΕΠΟΠΤΗ_FK
              AND ΑΜΚΑ_ΕΠΟΠΤΗ_FK = NEW.ΑΜΚΑ_FK
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Κυκλική εποπτεία δεν επιτρέπεται';
        END IF;
    END IF;
END //

CREATE TRIGGER trg_doc_no_2cycle_update
BEFORE UPDATE ON IATROS
FOR EACH ROW
BEGIN
    IF NEW.ΑΜΚΑ_ΕΠΟΠΤΗ_FK IS NOT NULL THEN
        IF EXISTS (
            SELECT 1 FROM IATROS
            WHERE ΑΜΚΑ_FK = NEW.ΑΜΚΑ_ΕΠΟΠΤΗ_FK
              AND ΑΜΚΑ_ΕΠΟΠΤΗ_FK = NEW.ΑΜΚΑ_FK
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Κυκλική εποπτεία δεν επιτρέπεται';
        END IF;
    END IF;
END //

DELIMITER ;

-- TRIGGER: ο διευθυντής τμήματος πρέπει να ανήκει στο τμήμα που διευθύνει

DELIMITER //

CREATE TRIGGER trg_director_belongs_to_dept_update
BEFORE UPDATE ON TMIMA
FOR EACH ROW
BEGIN
    IF (NEW.ΑΜΚΑ_ΔΙΕΥΘΥΝΤΗ_FK <> OLD.ΑΜΚΑ_ΔΙΕΥΘΥΝΤΗ_FK
        OR NEW.ΟΝΟΜΑ <> OLD.ΟΝΟΜΑ) THEN
        IF NOT EXISTS (
            SELECT 1 FROM IATROS_HAS_TMIMA
            WHERE ΙΑΤΡΟΣ_ΑΜΚΑ_FK  = NEW.ΑΜΚΑ_ΔΙΕΥΘΥΝΤΗ_FK
              AND ΤΜΗΜΑ_ΟΝΟΜΑ_FK  = NEW.ΟΝΟΜΑ
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Ο διευθυντής πρέπει να ανήκει στο τμήμα που διευθύνει';
        END IF;
    END IF;
END //

CREATE TRIGGER trg_director_membership_delete
BEFORE DELETE ON IATROS_HAS_TMIMA
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1 FROM TMIMA
        WHERE ΟΝΟΜΑ              = OLD.ΤΜΗΜΑ_ΟΝΟΜΑ_FK
          AND ΑΜΚΑ_ΔΙΕΥΘΥΝΤΗ_FK = OLD.ΙΑΤΡΟΣ_ΑΜΚΑ_FK
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Δεν μπορεί να αφαιρεθεί ο διευθυντής από το τμήμα που διευθύνει';
    END IF;
END //

DELIMITER ;

-- TRIGGER: ο διευθυντής τμήματος πρέπει να είναι ιατρός με ΒΑΘΜΙΔΑ = 'ΔΙΕΥΘΥΝΤΗΣ'

DELIMITER //

CREATE TRIGGER trg_dept_director_is_director_insert
BEFORE INSERT ON TMIMA
FOR EACH ROW
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM IATROS
        WHERE ΑΜΚΑ_FK = NEW.ΑΜΚΑ_ΔΙΕΥΘΥΝΤΗ_FK
          AND ΒΑΘΜΙΔΑ = 'ΔΙΕΥΘΥΝΤΗΣ'
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ο διευθυντής τμήματος πρέπει να είναι ιατρός με "ΒΑΘΜΙΔΑ" ΔΙΕΥΘΥΝΤΗΣ';
    END IF;
END //

CREATE TRIGGER trg_dept_director_is_director_update
BEFORE UPDATE ON TMIMA
FOR EACH ROW
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM IATROS
        WHERE ΑΜΚΑ_FK = NEW.ΑΜΚΑ_ΔΙΕΥΘΥΝΤΗ_FK
          AND ΒΑΘΜΙΔΑ = 'ΔΙΕΥΘΥΝΤΗΣ'
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ο διευθυντής τμήματος πρέπει να είναι ιατρός με "ΒΑΘΜΙΔΑ" ΔΙΕΥΘΥΝΤΗΣ';
    END IF;
END //

DELIMITER ;

-- Trigger για να ελένξει αν είναι κατειλημμένη η κλίνη

DELIMITER //

CREATE TRIGGER trg_bed_maintenance_check
BEFORE UPDATE ON KLINI
FOR EACH ROW
BEGIN
    IF NEW.ΚΑΤΑΣΤΑΣΗ = 'ΥΠΟ ΣΥΝΤΗΡΗΣΗ' 
       AND OLD.ΚΑΤΑΣΤΑΣΗ = 'ΚΑΤΕΙΛΗΜΜΕΝΗ' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Η κλίνη είναι κατειλημμένη και δεν μπορεί να τεθεί υπό συντήρηση.';
    END IF;

    IF OLD.ΚΑΤΑΣΤΑΣΗ = 'ΥΠΟ ΣΥΝΤΗΡΗΣΗ' 
       AND NEW.ΚΑΤΑΣΤΑΣΗ = 'ΚΑΤΕΙΛΗΜΜΕΝΗ' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Η κλίνη βρίσκεται υπό συντήρηση, οπότε δεν μπορεί να εισαχθεί σε αυτή ασθενής.';
    END IF;

END //

DELIMITER ;

-- Trigger για έλεγχο διαθεσιμότητας χώρου την ίδια ημερομηνία

DELIMITER //

CREATE TRIGGER trg_no_room_overlap_insert
BEFORE INSERT ON EPEMBASI
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1 FROM EPEMBASI
        WHERE ΧΩΡΟΣ_FK = NEW.ΧΩΡΟΣ_FK
          AND ΚΩΔΙΚΟΣ <> NEW.ΚΩΔΙΚΟΣ
          AND NEW.ΗΜΕΡΟΜΗΝΙΑ < DATE_ADD(ΗΜΕΡΟΜΗΝΙΑ, INTERVAL ΔΙΑΡΚΕΙΑ MINUTE)
          AND DATE_ADD(NEW.ΗΜΕΡΟΜΗΝΙΑ, INTERVAL NEW.ΔΙΑΡΚΕΙΑ MINUTE) > ΗΜΕΡΟΜΗΝΙΑ
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ο χώρος είναι ήδη κατειλημμένος αυτή την ώρα';
    END IF;
END //

CREATE TRIGGER trg_no_room_overlap_update
BEFORE UPDATE ON EPEMBASI
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1 FROM EPEMBASI
        WHERE ΧΩΡΟΣ_FK = NEW.ΧΩΡΟΣ_FK
          AND ΚΩΔΙΚΟΣ <> NEW.ΚΩΔΙΚΟΣ
          AND NEW.ΗΜΕΡΟΜΗΝΙΑ < DATE_ADD(ΗΜΕΡΟΜΗΝΙΑ, INTERVAL ΔΙΑΡΚΕΙΑ MINUTE)
          AND DATE_ADD(NEW.ΗΜΕΡΟΜΗΝΙΑ, INTERVAL NEW.ΔΙΑΡΚΕΙΑ MINUTE) > ΗΜΕΡΟΜΗΝΙΑ
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ο χώρος είναι ήδη κατειλημμένος αυτή την ώρα';
    END IF;
END //

DELIMITER ;

-- Trigger Έλεγχος για κύριο χειρουργό την ίδια ώρα

DELIMITER //

CREATE TRIGGER trg_no_doc_overlap_insert
BEFORE INSERT ON EPEMBASI
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1 FROM EPEMBASI
        WHERE ΑΜΚΑ_ΚΥΡΙΟΥ_ΙΑΤΡΟΥ_FK = NEW.ΑΜΚΑ_ΚΥΡΙΟΥ_ΙΑΤΡΟΥ_FK
          AND NEW.ΗΜΕΡΟΜΗΝΙΑ < DATE_ADD(ΗΜΕΡΟΜΗΝΙΑ, INTERVAL ΔΙΑΡΚΕΙΑ MINUTE)
          AND DATE_ADD(NEW.ΗΜΕΡΟΜΗΝΙΑ, INTERVAL NEW.ΔΙΑΡΚΕΙΑ MINUTE) > ΗΜΕΡΟΜΗΝΙΑ
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ο ιατρός συμμετέχει ήδη σε επέμβαση αυτή την ώρα';
    END IF;

    IF EXISTS (
        SELECT 1 FROM EPEMBASI_BOITHOI εβ
        JOIN EPEMBASI ε ON ε.ΚΩΔΙΚΟΣ = εβ.ΚΩΔΙΚΟΣ_ΕΠΕΜΒΑΣΗΣ_FK
        WHERE εβ.ΑΜΚΑ_ΒΟΗΘΟΥ_FK = NEW.ΑΜΚΑ_ΚΥΡΙΟΥ_ΙΑΤΡΟΥ_FK
          AND NEW.ΗΜΕΡΟΜΗΝΙΑ < DATE_ADD(ε.ΗΜΕΡΟΜΗΝΙΑ, INTERVAL ε.ΔΙΑΡΚΕΙΑ MINUTE)
          AND DATE_ADD(NEW.ΗΜΕΡΟΜΗΝΙΑ, INTERVAL NEW.ΔΙΑΡΚΕΙΑ MINUTE) > ε.ΗΜΕΡΟΜΗΝΙΑ
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ο ιατρός συμμετέχει ήδη ως βοηθός σε επέμβαση αυτή την ώρα';
    END IF;
END //

-- Trigger Έλεγχος για βοηθούς ιατρούς την ίδια ώρα

CREATE TRIGGER trg_no_assistant_overlap_insert
BEFORE INSERT ON EPEMBASI_BOITHOI
FOR EACH ROW
BEGIN
    DECLARE v_start DATETIME;
    DECLARE v_dur   INT;

    SELECT ΗΜΕΡΟΜΗΝΙΑ, ΔΙΑΡΚΕΙΑ INTO v_start, v_dur
    FROM EPEMBASI WHERE ΚΩΔΙΚΟΣ = NEW.ΚΩΔΙΚΟΣ_ΕΠΕΜΒΑΣΗΣ_FK;

    IF EXISTS (
        SELECT 1 FROM EPEMBASI
        WHERE ΑΜΚΑ_ΚΥΡΙΟΥ_ΙΑΤΡΟΥ_FK = NEW.ΑΜΚΑ_ΒΟΗΘΟΥ_FK
          AND v_start < DATE_ADD(ΗΜΕΡΟΜΗΝΙΑ, INTERVAL ΔΙΑΡΚΕΙΑ MINUTE)
          AND DATE_ADD(v_start, INTERVAL v_dur MINUTE) > ΗΜΕΡΟΜΗΝΙΑ
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ο βοηθός είναι κύριος χειρουργός σε άλλη ταυτόχρονη επέμβαση';
    END IF;
    
    IF EXISTS (
        SELECT 1 FROM EPEMBASI_BOITHOI εβ
        JOIN EPEMBASI ε ON ε.ΚΩΔΙΚΟΣ = εβ.ΚΩΔΙΚΟΣ_ΕΠΕΜΒΑΣΗΣ_FK
        WHERE εβ.ΑΜΚΑ_ΒΟΗΘΟΥ_FK = NEW.ΑΜΚΑ_ΒΟΗΘΟΥ_FK
          AND εβ.ΚΩΔΙΚΟΣ_ΕΠΕΜΒΑΣΗΣ_FK <> NEW.ΚΩΔΙΚΟΣ_ΕΠΕΜΒΑΣΗΣ_FK
          AND v_start < DATE_ADD(ε.ΗΜΕΡΟΜΗΝΙΑ, INTERVAL ε.ΔΙΑΡΚΕΙΑ MINUTE)
          AND DATE_ADD(v_start, INTERVAL v_dur MINUTE) > ε.ΗΜΕΡΟΜΗΝΙΑ
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ο βοηθός συμμετέχει ήδη σε άλλη ταυτόχρονη επέμβαση';
    END IF;
END //

DELIMITER ;

-- TRIGGER: ΗΜΕΡΟΜΗΝΙΑ_ΓΕΝΝΗΣΗΣ ασθενούς δεν μπορεί να είναι στο μέλλον (νεογέννητα επιτρέπονται)

DELIMITER //

CREATE TRIGGER trg_pat_birth_not_future_insert
BEFORE INSERT ON ASTHENIS
FOR EACH ROW
BEGIN
    IF NEW.ΗΜΕΡΟΜΗΝΙΑ_ΓΕΝΝΗΣΗΣ > CURDATE() THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ΗΜΕΡΟΜΗΝΙΑ_ΓΕΝΝΗΣΗΣ ασθενούς δεν μπορεί να είναι στο μέλλον';
    END IF;
END //

CREATE TRIGGER trg_pat_birth_not_future_update
BEFORE UPDATE ON ASTHENIS
FOR EACH ROW
BEGIN
    IF NEW.ΗΜΕΡΟΜΗΝΙΑ_ΓΕΝΝΗΣΗΣ > CURDATE() THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ΗΜΕΡΟΜΗΝΙΑ_ΓΕΝΝΗΣΗΣ ασθενούς δεν μπορεί να είναι στο μέλλον';
    END IF;
END //

DELIMITER ;

-- Triger για να μη είναι στο ίδιο δωμάτιο 2 νοσηλείες την ίδια στιγμή

DELIMITER //

CREATE TRIGGER trg_no_double_bed_booking
BEFORE INSERT ON NOSILEIA
FOR EACH ROW
BEGIN
    DECLARE v_count INT;

    SELECT COUNT(*) INTO v_count
    FROM NOSILEIA
    WHERE ΚΛΙΝΗ_FK = NEW.ΚΛΙΝΗ_FK
    AND ΤΜΗΜΑ_FK = NEW.ΤΜΗΜΑ_FK
    AND ΗΜΕΡΟΜΗΝΙΑ_ΕΙΣΟΔΟΥ < COALESCE(NEW.ΗΜΕΡΟΜΗΝΙΑ_ΕΞΟΔΟΥ, '9999-01-01')
    AND COALESCE(ΗΜΕΡΟΜΗΝΙΑ_ΕΞΟΔΟΥ, '9999-01-01') > NEW.ΗΜΕΡΟΜΗΝΙΑ_ΕΙΣΟΔΟΥ;

    IF v_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Η κλίνη είναι ήδη κατειλημμένη';
    END IF;
END //

DELIMITER ;

DELIMITER //

CREATE TRIGGER trg_bed_occupied_onadmit
AFTER INSERT ON NOSILEIA
FOR EACH ROW
BEGIN
    IF NEW.ΗΜΕΡΟΜΗΝΙΑ_ΕΞΟΔΟΥ IS NULL THEN
          UPDATE KLINI
    SET ΚΑΤΑΣΤΑΣΗ = 'ΚΑΤΕΙΛΗΜΜΕΝΗ'
    WHERE ΑΡΙΘΜΟΣ_ΚΛΙΝΗΣ = NEW.ΚΛΙΝΗ_FK
      AND ΤΜΗΜΑ_FK        = NEW.ΤΜΗΜΑ_FK;
    END IF;
END //

CREATE TRIGGER trg_bed_free_ondischarge
AFTER UPDATE ON NOSILEIA
FOR EACH ROW
BEGIN
    IF NEW.ΗΜΕΡΟΜΗΝΙΑ_ΕΞΟΔΟΥ IS NOT NULL
       AND OLD.ΗΜΕΡΟΜΗΝΙΑ_ΕΞΟΔΟΥ IS NULL THEN
        UPDATE KLINI
        SET ΚΑΤΑΣΤΑΣΗ = 'ΔΙΑΘΕΣΙΜΗ'
        WHERE ΑΡΙΘΜΟΣ_ΚΛΙΝΗΣ = NEW.ΚΛΙΝΗ_FK
          AND ΤΜΗΜΑ_FK        = NEW.ΤΜΗΜΑ_FK;
    END IF;
END //

DELIMITER ;

DELIMITER //

-- Trigger 1: BEFORE INSERT — έλεγχοι συνέπειας

CREATE TRIGGER trg_dialogi_bi
BEFORE INSERT ON DIALOGI
FOR EACH ROW
BEGIN
    -- Κανόνας 1: μόνο ΕΙΣΑΓΩΓΗ μπορεί να έχει ΝΟΣΗΛΕΙΑ_FK
    IF NEW.ΑΠΟΤΕΛΕΣΜΑ <> 'ΕΙΣΑΓΩΓΗ' AND NEW.ΝΟΣΗΛΕΙΑ_FK IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ΝΟΣΗΛΕΙΑ_FK πρέπει NULL όταν αποτέλεσμα ≠ ΕΙΣΑΓΩΓΗ';
    END IF;

    -- Κανόνας 2: η νοσηλεία πρέπει να ανήκει στον ίδιο ασθενή
    IF NEW.ΑΠΟΤΕΛΕΣΜΑ = 'ΕΙΣΑΓΩΓΗ' AND NEW.ΝΟΣΗΛΕΙΑ_FK IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM NOSILEIA
            WHERE ΚΩΔΙΚΟΣ_ΝΟΣΗΛΕΙΑΣ = NEW.ΝΟΣΗΛΕΙΑ_FK
              AND ΑΜΚΑ_ΑΣΘΕΝΗ_FK    = NEW.ΑΜΚΑ_ΑΣΘΕΝΗ_FK
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Η νοσηλεία δεν ανήκει στον ασθενή της διαλογής';
        END IF;
    END IF;
END //

-- Trigger 2: AFTER INSERT — συγχρόνισε ΗΜΕΡΟΜΗΝΙΑ_ΕΙΣΟΔΟΥ

CREATE TRIGGER trg_dialogi_ai
AFTER INSERT ON DIALOGI
FOR EACH ROW
BEGIN
    IF NEW.ΑΠΟΤΕΛΕΣΜΑ  = 'ΕΙΣΑΓΩΓΗ'
       AND NEW.ΝΟΣΗΛΕΙΑ_FK       IS NOT NULL
       AND NEW.ΩΡΑ_ΕΞΥΠΗΡΕΤΗΣΗΣ IS NOT NULL
    THEN
         UPDATE NOSILEIA
            SET ΗΜΕΡΟΜΗΝΙΑ_ΕΙΣΟΔΟΥ = NEW.ΩΡΑ_ΕΞΥΠΗΡΕΤΗΣΗΣ
            WHERE ΚΩΔΙΚΟΣ_ΝΟΣΗΛΕΙΑΣ = NEW.ΝΟΣΗΛΕΙΑ_FK
                AND (ΗΜΕΡΟΜΗΝΙΑ_ΕΞΟΔΟΥ IS NULL
                OR ΗΜΕΡΟΜΗΝΙΑ_ΕΞΟΔΟΥ >= NEW.ΩΡΑ_ΕΞΥΠΗΡΕΤΗΣΗΣ);
    END IF;
END //


-- Trigger 3: BEFORE UPDATE — ίδιοι έλεγχοι

CREATE TRIGGER trg_dialogi_bu
BEFORE UPDATE ON DIALOGI
FOR EACH ROW
BEGIN
    IF NEW.ΑΠΟΤΕΛΕΣΜΑ <> 'ΕΙΣΑΓΩΓΗ' AND NEW.ΝΟΣΗΛΕΙΑ_FK IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ΝΟΣΗΛΕΙΑ_FK πρέπει NULL όταν αποτέλεσμα ≠ ΕΙΣΑΓΩΓΗ';
    END IF;

    IF NEW.ΑΠΟΤΕΛΕΣΜΑ = 'ΕΙΣΑΓΩΓΗ' AND NEW.ΝΟΣΗΛΕΙΑ_FK IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM NOSILEIA
            WHERE ΚΩΔΙΚΟΣ_ΝΟΣΗΛΕΙΑΣ = NEW.ΝΟΣΗΛΕΙΑ_FK
              AND ΑΜΚΑ_ΑΣΘΕΝΗ_FK    = NEW.ΑΜΚΑ_ΑΣΘΕΝΗ_FK
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Η νοσηλεία δεν ανήκει στον ασθενή της διαλογής';
        END IF;
    END IF;
END //


-- DIALOGI Trigger 4: AFTER UPDATE — συγχρόνισε αν άλλαξε η ώρα/νοσηλεία

CREATE TRIGGER trg_dialogi_au
AFTER UPDATE ON DIALOGI
FOR EACH ROW
BEGIN
    IF NEW.ΑΠΟΤΕΛΕΣΜΑ  = 'ΕΙΣΑΓΩΓΗ'
       AND NEW.ΝΟΣΗΛΕΙΑ_FK       IS NOT NULL
       AND NEW.ΩΡΑ_ΕΞΥΠΗΡΕΤΗΣΗΣ IS NOT NULL
       AND (NEW.ΩΡΑ_ΕΞΥΠΗΡΕΤΗΣΗΣ <> OLD.ΩΡΑ_ΕΞΥΠΗΡΕΤΗΣΗΣ
            OR NEW.ΝΟΣΗΛΕΙΑ_FK   <> OLD.ΝΟΣΗΛΕΙΑ_FK
            OR OLD.ΝΟΣΗΛΕΙΑ_FK   IS NULL)
    THEN
        UPDATE NOSILEIA
        SET ΗΜΕΡΟΜΗΝΙΑ_ΕΙΣΟΔΟΥ = NEW.ΩΡΑ_ΕΞΥΠΗΡΕΤΗΣΗΣ
        WHERE ΚΩΔΙΚΟΣ_ΝΟΣΗΛΕΙΑΣ = NEW.ΝΟΣΗΛΕΙΑ_FK
            AND (ΗΜΕΡΟΜΗΝΙΑ_ΕΞΟΔΟΥ IS NULL
            OR ΗΜΕΡΟΜΗΝΙΑ_ΕΞΟΔΟΥ >= NEW.ΩΡΑ_ΕΞΥΠΗΡΕΤΗΣΗΣ);

    END IF;
END //

DELIMITER ;

-- Trigger: Νοσηλευτής/ Διοικητικό προσωπικό ανήκουν μόνο σε βάρδιες του τμήματός τους

DELIMITER //

CREATE TRIGGER trg_staff_belongs_to_shift_dept
BEFORE INSERT ON EFIMERIA_PROSOPIKOY
FOR EACH ROW
BEGIN
    DECLARE v_type VARCHAR(30);

    SELECT ΤΥΠΟΣ_ΠΡΟΣΩΠΙΚΟΥ INTO v_type
    FROM PROSOPIKO
    WHERE ΑΜΚΑ = NEW.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK;

    IF v_type = 'ΝΟΣΗΛΕΥΤΗΣ' THEN
        IF NOT EXISTS (
            SELECT 1 FROM NOSILEYTHS
            WHERE ΑΜΚΑ_FK   = NEW.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK
              AND ΤΜΗΜΑ_FK  = NEW.ΤΜΗΜΑ_FK
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Ο νοσηλευτής δεν ανήκει στο τμήμα αυτής της βάρδιας';
        END IF;

    ELSEIF v_type = 'ΔΙΟΙΚΗΤΙΚΟ ΠΡΟΣΩΠΙΚΟ' THEN
        IF NOT EXISTS (
            SELECT 1 FROM DIOIKITIKO_PROSOPIKO
            WHERE ΑΜΚΑ_FK   = NEW.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK
              AND ΤΜΗΜΑ_FK  = NEW.ΤΜΗΜΑ_FK
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Το διοικητικό προσωπικό δεν ανήκει στο τμήμα αυτής της βάρδιας';
        END IF;
    END IF;
END //

CREATE TRIGGER trg_staff_belongs_to_shift_dept_update
BEFORE UPDATE ON EFIMERIA_PROSOPIKOY
FOR EACH ROW
BEGIN
    DECLARE v_type VARCHAR(30);

    SELECT ΤΥΠΟΣ_ΠΡΟΣΩΠΙΚΟΥ INTO v_type
    FROM PROSOPIKO
    WHERE ΑΜΚΑ = NEW.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK;

    IF v_type = 'ΝΟΣΗΛΕΥΤΗΣ' THEN
        IF NOT EXISTS (
            SELECT 1 FROM NOSILEYTHS
            WHERE ΑΜΚΑ_FK   = NEW.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK
              AND ΤΜΗΜΑ_FK  = NEW.ΤΜΗΜΑ_FK
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Ο νοσηλευτής δεν ανήκει στο τμήμα αυτής της βάρδιας';
        END IF;

    ELSEIF v_type = 'ΔΙΟΙΚΗΤΙΚΟ ΠΡΟΣΩΠΙΚΟ' THEN
        IF NOT EXISTS (
            SELECT 1 FROM DIOIKITIKO_PROSOPIKO
            WHERE ΑΜΚΑ_FK   = NEW.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK
              AND ΤΜΗΜΑ_FK  = NEW.ΤΜΗΜΑ_FK
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Το διοικητικό προσωπικό δεν ανήκει στο τμήμα αυτής της βάρδιας';
        END IF;
    END IF;
END //

DELIMITER ;

-- TRIGGER: μέγιστο πλήθος βαρδιών μήνα ανά τύπο προσωπικού

DELIMITER //

CREATE TRIGGER trg_check_monthly_shifts_insert
BEFORE INSERT ON EFIMERIA_PROSOPIKOY
FOR EACH ROW
BEGIN
    DECLARE v_type  VARCHAR(30);
    DECLARE v_limit INT;
    DECLARE v_count INT;

    SELECT ΤΥΠΟΣ_ΠΡΟΣΩΠΙΚΟΥ INTO v_type
    FROM PROSOPIKO
    WHERE ΑΜΚΑ = NEW.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK;

    SET v_limit = CASE v_type
        WHEN 'ΙΑΤΡΟΣ'               THEN 15
        WHEN 'ΝΟΣΗΛΕΥΤΗΣ'           THEN 20
        WHEN 'ΔΙΟΙΚΗΤΙΚΟ ΠΡΟΣΩΠΙΚΟ' THEN 25
        ELSE 0
    END;

    SELECT COUNT(*) INTO v_count
    FROM EFIMERIA_PROSOPIKOY ep
    WHERE ep.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK = NEW.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK
      AND MONTH(ep.ΗΜΕΡΟΜΗΝΙΑ_FK) = MONTH(NEW.ΗΜΕΡΟΜΗΝΙΑ_FK)
      AND YEAR(ep.ΗΜΕΡΟΜΗΝΙΑ_FK)  = YEAR(NEW.ΗΜΕΡΟΜΗΝΙΑ_FK);

    IF v_count >= v_limit THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Υπέρβαση μέγιστου ορίου βαρδιών μήνα';
    END IF;
END //

CREATE TRIGGER trg_check_monthly_shifts_update
BEFORE UPDATE ON EFIMERIA_PROSOPIKOY
FOR EACH ROW
BEGIN
    DECLARE v_type  VARCHAR(30);
    DECLARE v_limit INT;
    DECLARE v_count INT;

    SELECT ΤΥΠΟΣ_ΠΡΟΣΩΠΙΚΟΥ INTO v_type
    FROM PROSOPIKO
    WHERE ΑΜΚΑ = NEW.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK;

    SET v_limit = CASE v_type
        WHEN 'ΙΑΤΡΟΣ'               THEN 15
        WHEN 'ΝΟΣΗΛΕΥΤΗΣ'           THEN 20
        WHEN 'ΔΙΟΙΚΗΤΙΚΟ ΠΡΟΣΩΠΙΚΟ' THEN 25
        ELSE 0
    END;

    SELECT COUNT(*) INTO v_count
    FROM EFIMERIA_PROSOPIKOY ep
    WHERE ep.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK = NEW.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK
      AND MONTH(ep.ΗΜΕΡΟΜΗΝΙΑ_FK) = MONTH(NEW.ΗΜΕΡΟΜΗΝΙΑ_FK)
      AND YEAR(ep.ΗΜΕΡΟΜΗΝΙΑ_FK)  = YEAR(NEW.ΗΜΕΡΟΜΗΝΙΑ_FK)
      AND NOT (ep.ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK   = OLD.ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK
               AND ep.ΗΜΕΡΟΜΗΝΙΑ_FK   = OLD.ΗΜΕΡΟΜΗΝΙΑ_FK
               AND ep.ΤΜΗΜΑ_FK        = OLD.ΤΜΗΜΑ_FK
               AND ep.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK = OLD.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK);

    IF v_count >= v_limit THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Υπέρβαση μέγιστου ορίου βαρδιών μήνα';
    END IF;
END //

DELIMITER ;

-- TRIGGER: ελάχιστη στελέχωση ΒΑΡΔΙΑΣ

DELIMITER //

CREATE TRIGGER trg_shift_min_staff_delete
BEFORE DELETE ON EFIMERIA_PROSOPIKOY
FOR EACH ROW
BEGIN
    DECLARE v_type  VARCHAR(30);
    DECLARE v_min   INT;
    DECLARE v_count INT;

    SELECT ΤΥΠΟΣ_ΠΡΟΣΩΠΙΚΟΥ INTO v_type
    FROM PROSOPIKO
    WHERE ΑΜΚΑ = OLD.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK;

    SET v_min = CASE v_type
        WHEN 'ΙΑΤΡΟΣ'               THEN 3
        WHEN 'ΝΟΣΗΛΕΥΤΗΣ'           THEN 6
        WHEN 'ΔΙΟΙΚΗΤΙΚΟ ΠΡΟΣΩΠΙΚΟ' THEN 2
        ELSE 0
    END;

    SELECT COUNT(*) INTO v_count
    FROM EFIMERIA_PROSOPIKOY ep
    JOIN PROSOPIKO π ON π.ΑΜΚΑ = ep.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK
    WHERE ep.ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK = OLD.ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK
      AND ep.ΗΜΕΡΟΜΗΝΙΑ_FK    = OLD.ΗΜΕΡΟΜΗΝΙΑ_FK
      AND ep.ΤΜΗΜΑ_FK         = OLD.ΤΜΗΜΑ_FK
      AND π.ΤΥΠΟΣ_ΠΡΟΣΩΠΙΚΟΥ  = v_type;

    IF v_count - 1 < v_min THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Η βάρδια απαγορευέται να πέσει κάτω από το ελάχιστο όριο προσωπικού';
    END IF;
END //

CREATE TRIGGER trg_shift_min_staff_update
BEFORE UPDATE ON EFIMERIA_PROSOPIKOY
FOR EACH ROW
BEGIN
    DECLARE v_type  VARCHAR(30);
    DECLARE v_min   INT;
    DECLARE v_count INT;

    IF OLD.ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK    <> NEW.ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK
       OR OLD.ΗΜΕΡΟΜΗΝΙΑ_FK    <> NEW.ΗΜΕΡΟΜΗΝΙΑ_FK
       OR OLD.ΤΜΗΜΑ_FK         <> NEW.ΤΜΗΜΑ_FK
       OR OLD.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK <> NEW.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK
    THEN
        SELECT ΤΥΠΟΣ_ΠΡΟΣΩΠΙΚΟΥ INTO v_type
        FROM PROSOPIKO
        WHERE ΑΜΚΑ = OLD.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK;

        SET v_min = CASE v_type
            WHEN 'ΙΑΤΡΟΣ'               THEN 3
            WHEN 'ΝΟΣΗΛΕΥΤΗΣ'           THEN 6
            WHEN 'ΔΙΟΙΚΗΤΙΚΟ ΠΡΟΣΩΠΙΚΟ' THEN 2
            ELSE 0
        END;

        SELECT COUNT(*) INTO v_count
        FROM EFIMERIA_PROSOPIKOY ep
        JOIN PROSOPIKO π ON π.ΑΜΚΑ = ep.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK
        WHERE ep.ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK = OLD.ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK
          AND ep.ΗΜΕΡΟΜΗΝΙΑ_FK    = OLD.ΗΜΕΡΟΜΗΝΙΑ_FK
          AND ep.ΤΜΗΜΑ_FK         = OLD.ΤΜΗΜΑ_FK
          AND π.ΤΥΠΟΣ_ΠΡΟΣΩΠΙΚΟΥ  = v_type;

        IF v_count - 1 < v_min THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Αλλαγή δεν επιτρέπεται: η αρχική ΒΑΡΔΙΑ πέφτει κάτω από το ελάχιστο όριο προσωπικού';
        END IF;
    END IF;
END //

DELIMITER ;

DELIMITER //

-- TRIGGER: Όταν συμμετέχει ειδικευόμενος ιατρός σε βάρδια πρέπει να υπάρχει ανώτερος

CREATE TRIGGER trg_specialist_needs_supervisor_insert
BEFORE INSERT ON EFIMERIA_PROSOPIKOY
FOR EACH ROW
BEGIN
    DECLARE v_rank VARCHAR(50);
    DECLARE v_seniors INT;

    SELECT i.ΒΑΘΜΙΔΑ INTO v_rank
    FROM IATROS i
    WHERE i.ΑΜΚΑ_FK = NEW.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK;

    IF v_rank = 'ΕΙΔΙΚΕΥΟΜΕΝΟΣ' THEN
        SELECT COUNT(*) INTO v_seniors
        FROM EFIMERIA_PROSOPIKOY ep
        JOIN IATROS i2 ON i2.ΑΜΚΑ_FK = ep.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK
        WHERE ep.ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK = NEW.ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK
          AND ep.ΗΜΕΡΟΜΗΝΙΑ_FK    = NEW.ΗΜΕΡΟΜΗΝΙΑ_FK
          AND ep.ΤΜΗΜΑ_FK         = NEW.ΤΜΗΜΑ_FK
          AND i2.ΒΑΘΜΙΔΑ IN ('ΕΠΙΜΕΛΗΤΗΣ Α', 'ΔΙΕΥΘΥΝΤΗΣ');

        IF v_seniors = 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Ειδικευόμενος ιατρός χρειάζεται Επιμελητή Α ή Διευθυντή στην ίδια βάρδια';
        END IF;
    END IF;
END //

CREATE TRIGGER trg_specialist_needs_supervisor_update
BEFORE UPDATE ON EFIMERIA_PROSOPIKOY
FOR EACH ROW
BEGIN
    DECLARE v_rank    VARCHAR(50);
    DECLARE v_seniors INT;

    SELECT i.ΒΑΘΜΙΔΑ INTO v_rank
    FROM IATROS i
    WHERE i.ΑΜΚΑ_FK = NEW.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK;

    IF v_rank = 'ΕΙΔΙΚΕΥΟΜΕΝΟΣ' THEN
        SELECT COUNT(*) INTO v_seniors
        FROM EFIMERIA_PROSOPIKOY ep
        JOIN IATROS i2 ON i2.ΑΜΚΑ_FK = ep.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK
        WHERE ep.ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK = NEW.ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK
          AND ep.ΗΜΕΡΟΜΗΝΙΑ_FK    = NEW.ΗΜΕΡΟΜΗΝΙΑ_FK
          AND ep.ΤΜΗΜΑ_FK         = NEW.ΤΜΗΜΑ_FK
          -- εξαιρούμε την ίδια εγγραφή που ενημερώνεται
          AND NOT (ep.ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK    = OLD.ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK
               AND ep.ΗΜΕΡΟΜΗΝΙΑ_FK       = OLD.ΗΜΕΡΟΜΗΝΙΑ_FK
               AND ep.ΤΜΗΜΑ_FK            = OLD.ΤΜΗΜΑ_FK
               AND ep.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK  = OLD.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK)
          AND i2.ΒΑΘΜΙΔΑ IN ('ΕΠΙΜΕΛΗΤΗΣ Α', 'ΔΙΕΥΘΥΝΤΗΣ');

        IF v_seniors = 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Ειδικευόμενος ιατρός χρειάζεται Επιμελητή Α ή Διευθυντή στην ίδια βάρδια';
        END IF;
    END IF;
END //

CREATE TRIGGER trg_supervisor_remove_check_delete
BEFORE DELETE ON EFIMERIA_PROSOPIKOY
FOR EACH ROW
BEGIN
    DECLARE v_rank VARCHAR(50);
    DECLARE v_other_seniors INT;
    DECLARE v_specialists INT;

    SELECT i.ΒΑΘΜΙΔΑ INTO v_rank
    FROM IATROS i
    WHERE i.ΑΜΚΑ_FK = OLD.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK;

    IF v_rank IN ('ΕΠΙΜΕΛΗΤΗΣ Α', 'ΔΙΕΥΘΥΝΤΗΣ') THEN
        SELECT COUNT(*) INTO v_other_seniors
        FROM EFIMERIA_PROSOPIKOY ep
        JOIN IATROS i2 ON i2.ΑΜΚΑ_FK = ep.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK
        WHERE ep.ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK = OLD.ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK
          AND ep.ΗΜΕΡΟΜΗΝΙΑ_FK    = OLD.ΗΜΕΡΟΜΗΝΙΑ_FK
          AND ep.ΤΜΗΜΑ_FK         = OLD.ΤΜΗΜΑ_FK
          AND ep.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK <> OLD.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK
          AND i2.ΒΑΘΜΙΔΑ IN ('ΕΠΙΜΕΛΗΤΗΣ Α', 'ΔΙΕΥΘΥΝΤΗΣ');

        IF v_other_seniors = 0 THEN
            SELECT COUNT(*) INTO v_specialists
            FROM EFIMERIA_PROSOPIKOY ep
            JOIN IATROS i2 ON i2.ΑΜΚΑ_FK = ep.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK
            WHERE ep.ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK = OLD.ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK
              AND ep.ΗΜΕΡΟΜΗΝΙΑ_FK    = OLD.ΗΜΕΡΟΜΗΝΙΑ_FK
              AND ep.ΤΜΗΜΑ_FK         = OLD.ΤΜΗΜΑ_FK
              AND ep.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK <> OLD.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK
              AND i2.ΒΑΘΜΙΔΑ = 'ΕΙΔΙΚΕΥΟΜΕΝΟΣ';

            IF v_specialists > 0 THEN
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = 'Δεν επιτρέπεται αφαίρεση: θα μείνει ειδικευόμενος χωρίς επόπτη στην βάρδια';
            END IF;
        END IF;
    END IF;
END //

-- TRIGGER: Ελάχιστο 8 ώρες ανάπαυση μεταξύ διαδοχικών βαρδιών του ίδιου ατόμου.

CREATE TRIGGER trg_shift_8h_rest_insert
BEFORE INSERT ON EFIMERIA_PROSOPIKOY
FOR EACH ROW
BEGIN
    DECLARE v_new_start DATETIME;
    DECLARE v_new_end   DATETIME;
    DECLARE v_conflicts INT;

    SET v_new_start = CASE NEW.ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK
        WHEN 'ΠΡΩΙΝΗ'       THEN TIMESTAMP(NEW.ΗΜΕΡΟΜΗΝΙΑ_FK, '07:00:00')
        WHEN 'ΑΠΟΓΕΥΜΑΤΙΝΗ' THEN TIMESTAMP(NEW.ΗΜΕΡΟΜΗΝΙΑ_FK, '15:00:00')
        WHEN 'ΝΥΧΤΕΡΙΝΗ'    THEN TIMESTAMP(NEW.ΗΜΕΡΟΜΗΝΙΑ_FK, '23:00:00')
    END;
    SET v_new_end = CASE NEW.ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK
        WHEN 'ΠΡΩΙΝΗ'       THEN TIMESTAMP(NEW.ΗΜΕΡΟΜΗΝΙΑ_FK, '15:00:00')
        WHEN 'ΑΠΟΓΕΥΜΑΤΙΝΗ' THEN TIMESTAMP(NEW.ΗΜΕΡΟΜΗΝΙΑ_FK, '23:00:00')
        WHEN 'ΝΥΧΤΕΡΙΝΗ'    THEN TIMESTAMP(DATE_ADD(NEW.ΗΜΕΡΟΜΗΝΙΑ_FK, INTERVAL 1 DAY), '07:00:00')
    END;

    SELECT COUNT(*) INTO v_conflicts
    FROM EFIMERIA_PROSOPIKOY ep
    WHERE ep.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK = NEW.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK
      AND v_new_start < DATE_ADD(
            CASE ep.ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK
                WHEN 'ΠΡΩΙΝΗ'       THEN TIMESTAMP(ep.ΗΜΕΡΟΜΗΝΙΑ_FK, '15:00:00')
                WHEN 'ΑΠΟΓΕΥΜΑΤΙΝΗ' THEN TIMESTAMP(ep.ΗΜΕΡΟΜΗΝΙΑ_FK, '23:00:00')
                WHEN 'ΝΥΧΤΕΡΙΝΗ'    THEN TIMESTAMP(DATE_ADD(ep.ΗΜΕΡΟΜΗΝΙΑ_FK, INTERVAL 1 DAY), '07:00:00')
            END, INTERVAL 8 HOUR)
      AND DATE_ADD(v_new_end, INTERVAL 8 HOUR) >
            CASE ep.ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK
                WHEN 'ΠΡΩΙΝΗ'       THEN TIMESTAMP(ep.ΗΜΕΡΟΜΗΝΙΑ_FK, '07:00:00')
                WHEN 'ΑΠΟΓΕΥΜΑΤΙΝΗ' THEN TIMESTAMP(ep.ΗΜΕΡΟΜΗΝΙΑ_FK, '15:00:00')
                WHEN 'ΝΥΧΤΕΡΙΝΗ'    THEN TIMESTAMP(ep.ΗΜΕΡΟΜΗΝΙΑ_FK, '23:00:00')
            END;

    IF v_conflicts > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Πρέπει να μεσολαβούν τουλάχιστον 8 ώρες ανάπαυσης μεταξύ διαδοχικών βαρδιών';
    END IF;
END //

-- TRIGGER: Όχι περισσότερες από 3 συνεχόμενες νυχτερινές βάρδιες

CREATE TRIGGER trg_max3_consecutive_nights_insert
BEFORE INSERT ON EFIMERIA_PROSOPIKOY
FOR EACH ROW
BEGIN
    DECLARE v_back INT DEFAULT 0;
    DECLARE v_fwd  INT DEFAULT 0;
    DECLARE v_check_date DATE;
    DECLARE v_has INT;

    IF NEW.ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK = 'ΝΥΧΤΕΡΙΝΗ' THEN
        SET v_check_date = DATE_SUB(NEW.ΗΜΕΡΟΜΗΝΙΑ_FK, INTERVAL 1 DAY);
        SELECT EXISTS (
            SELECT 1 FROM EFIMERIA_PROSOPIKOY
            WHERE ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK = NEW.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK
              AND ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK   = 'ΝΥΧΤΕΡΙΝΗ'
              AND ΗΜΕΡΟΜΗΝΙΑ_FK      = v_check_date
        ) INTO v_has;
        WHILE v_has = 1 DO
            SET v_back = v_back + 1;
            SET v_check_date = DATE_SUB(v_check_date, INTERVAL 1 DAY);
            SELECT EXISTS (
                SELECT 1 FROM EFIMERIA_PROSOPIKOY
                WHERE ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK = NEW.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK
                  AND ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK   = 'ΝΥΧΤΕΡΙΝΗ'
                  AND ΗΜΕΡΟΜΗΝΙΑ_FK      = v_check_date
            ) INTO v_has;
        END WHILE;

        SET v_check_date = DATE_ADD(NEW.ΗΜΕΡΟΜΗΝΙΑ_FK, INTERVAL 1 DAY);
        SELECT EXISTS (
            SELECT 1 FROM EFIMERIA_PROSOPIKOY
            WHERE ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK = NEW.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK
              AND ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK   = 'ΝΥΧΤΕΡΙΝΗ'
              AND ΗΜΕΡΟΜΗΝΙΑ_FK      = v_check_date
        ) INTO v_has;
        WHILE v_has = 1 DO
            SET v_fwd = v_fwd + 1;
            SET v_check_date = DATE_ADD(v_check_date, INTERVAL 1 DAY);
            SELECT EXISTS (
                SELECT 1 FROM EFIMERIA_PROSOPIKOY
                WHERE ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK = NEW.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK
                  AND ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK   = 'ΝΥΧΤΕΡΙΝΗ'
                  AND ΗΜΕΡΟΜΗΝΙΑ_FK      = v_check_date
            ) INTO v_has;
        END WHILE;

        IF v_back + 1 + v_fwd > 3 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Δεν επιτρέπονται περισσότερες από 3 συνεχόμενες νυχτερινές βάρδιες';
        END IF;
    END IF;
END //

DELIMITER ;

-- TRIGGER: Το ίδιο άτομο δεν μπορεί να έχει παράλληλες βάρδιες ίδιου τύπου την ίδια ημέρα σε διαφορετικά τμήματα

DELIMITER //

CREATE TRIGGER trg_no_parallel_shifts_insert
BEFORE INSERT ON EFIMERIA_PROSOPIKOY
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1 FROM EFIMERIA_PROSOPIKOY
        WHERE ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK = NEW.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK
          AND ΗΜΕΡΟΜΗΝΙΑ_FK      = NEW.ΗΜΕΡΟΜΗΝΙΑ_FK
          AND ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK   = NEW.ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK
          AND ΤΜΗΜΑ_FK           <> NEW.ΤΜΗΜΑ_FK
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Το ίδιο μέλος δεν μπορεί να είναι σε δύο βάρδιες ίδιου τύπου την ίδια ημέρα';
    END IF;
END //

CREATE TRIGGER trg_no_parallel_shifts_update
BEFORE UPDATE ON EFIMERIA_PROSOPIKOY
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1 FROM EFIMERIA_PROSOPIKOY
        WHERE ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK = NEW.ΑΜΚΑ_ΠΡΟΣΩΠΙΚΟΥ_FK
          AND ΗΜΕΡΟΜΗΝΙΑ_FK      = NEW.ΗΜΕΡΟΜΗΝΙΑ_FK
          AND ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK   = NEW.ΤΥΠΟΣ_ΒΑΡΔΙΑΣ_FK
          AND ΤΜΗΜΑ_FK           <> NEW.ΤΜΗΜΑ_FK
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Το ίδιο μέλος δεν μπορεί να είναι σε δύο βάρδιες ίδιου τύπου την ίδια ημέρα';
    END IF;
END //

DELIMITER ;

-- Trigger για την επιβεβαίωση ότι ο ασθενής της συνταγής είναι ο ίδιος με τον ασθενή της νοσηλείας

DELIMITER //

CREATE TRIGGER trg_rx_patient_matches_hospitalization
BEFORE INSERT ON SYNTAGOGRAFISI
FOR EACH ROW
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM NOSILEIA
        WHERE ΚΩΔΙΚΟΣ_ΝΟΣΗΛΕΙΑΣ = NEW.ΝΟΣΗΛΕΙΑ_FK
          AND ΑΜΚΑ_ΑΣΘΕΝΗ_FK    = NEW.ΑΜΚΑ_ΑΣΘΕΝΗ_FK
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ο ασθενής της συνταγής δεν αντιστοιχεί στη νοσηλεία';
    END IF;
END //

DELIMITER ;

-- Trigger για την αξιολόγηση νοσηλείας

DELIMITER //

CREATE TRIGGER trg_check_hosp_eval_completed
BEFORE INSERT ON AKSIOLOGHSH_NOSILEIAS
FOR EACH ROW
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM NOSILEIA
        WHERE ΚΩΔΙΚΟΣ_ΝΟΣΗΛΕΙΑΣ = NEW.ΝΟΣΗΛΕΙΑ_FK
          AND ΗΜΕΡΟΜΗΝΙΑ_ΕΞΟΔΟΥ IS NOT NULL
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Αξιολόγηση επιτρέπεται μόνο για ολοκληρωμένες νοσηλείες';
    END IF;
END //

DELIMITER ;

-- Trigger για την αξιολόγηση ιατρού

DELIMITER //

CREATE TRIGGER trg_check_doc_eval_prescribed
BEFORE INSERT ON AKSIOLOGHSH_IATROY
FOR EACH ROW
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM NOSILEIA n
        WHERE n.ΚΩΔΙΚΟΣ_ΝΟΣΗΛΕΙΑΣ = NEW.ΝΟΣΗΛΕΙΑ_FK
          AND n.ΗΜΕΡΟΜΗΝΙΑ_ΕΞΟΔΟΥ IS NOT NULL
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Αξιολόγηση επιτρέπεται μόνο για ολοκληρωμένες νοσηλείες';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM SYNTAGOGRAFISI s
        JOIN NOSILEIA n ON n.ΚΩΔΙΚΟΣ_ΝΟΣΗΛΕΙΑΣ = s.ΝΟΣΗΛΕΙΑ_FK
        WHERE s.ΝΟΣΗΛΕΙΑ_FK    = NEW.ΝΟΣΗΛΕΙΑ_FK
          AND s.ΑΜΚΑ_ΙΑΤΡΟΥ_FK = NEW.ΑΜΚΑ_ΙΑΤΡΟΥ_FK
          AND s.ΑΜΚΑ_ΑΣΘΕΝΗ_FK = n.ΑΜΚΑ_ΑΣΘΕΝΗ_FK
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ο ιατρός δεν συνταγογράφησε σε αυτόν τον ασθενή κατά τη νοσηλεία αυτή';
    END IF;
END //

DELIMITER ;

-- Trigger για αλλεργία σε δραστική ουσία φαρμάκου 

DELIMITER //
CREATE TRIGGER trg_check_allergy_beforerx
BEFORE INSERT ON SYNTAGOGRAFISI
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1
        FROM DRASTIKES_OYSIES_FARMAKOY δοφ
        JOIN ALLERGIES α ON α.ΔΡΑΣΤΙΚΗ_ΟΥΣΙΑ_FK = δοφ.ΔΡΑΣΤΙΚΗ_ΟΥΣΙΑ_FK
        WHERE δοφ.ΚΩΔΙΚΟΣ_EMA_FK = NEW.ΚΩΔΙΚΟΣ_ΦΑΡΜΑΚΟΥ_FK
          AND α.ΑΜΚΑ_ΑΣΘΕΝΗ_FK   = NEW.ΑΜΚΑ_ΑΣΘΕΝΗ_FK
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Απαγορεύεται η συνταγογράφηση: ο ασθενής έχει αλλεργία σε δραστική ουσία του φαρμάκου';
    END IF;
END //

CREATE TRIGGER trg_check_allergy_updaterx
BEFORE UPDATE ON SYNTAGOGRAFISI
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1
        FROM DRASTIKES_OYSIES_FARMAKOY δοφ
        JOIN ALLERGIES α ON α.ΔΡΑΣΤΙΚΗ_ΟΥΣΙΑ_FK = δοφ.ΔΡΑΣΤΙΚΗ_ΟΥΣΙΑ_FK
        WHERE δοφ.ΚΩΔΙΚΟΣ_EMA_FK = NEW.ΚΩΔΙΚΟΣ_ΦΑΡΜΑΚΟΥ_FK
          AND α.ΑΜΚΑ_ΑΣΘΕΝΗ_FK   = NEW.ΑΜΚΑ_ΑΣΘΕΝΗ_FK
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Απαγορεύεται η συνταγογράφηση: ο ασθενής έχει αλλεργία σε δραστική ουσία του φαρμάκου';
    END IF;
END //

DELIMITER ;
