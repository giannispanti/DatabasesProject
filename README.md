# Database Semester Project, for the "Databases" course (6th Semester) of the ECE School, NTUA
# Design and Implementation of a system for storing and managing the information required for the operation of YGEIOPOLIS HOSPITAL
This project aims to emulate a realistic database for hospital, as well as storing and managing data related to many of the entities that are connected to a hospital. To name some of them: doctors, nurses, departments, buildings, drugs (real reference data from EMA - European Medicines Agency), medical procedures (real data from EODY - National Public Health Organization), a triage implemented with FIFO logic. We have optimized our database to ensure fast, efficient data queries and analysis. This repository contains all the necessary files for setting up and running the Hospital Database.
# Directory Features
(i) Database Management: Using MySQL (MariaDB) for structured, dependable data storage and efficient database management.  
(ii) Preprocess Real-Reference Data: Preprocessing 4 files that contain real data(drugs, ken codes, etc.) with a python script and loading them with LOAD INFILE.  
(iii) Data Generation: Includes a Python script (Faker) to create dummy data and loading an sql file which loads the database for testing and generating the real data(ii).  
(iv) Implements MySQL constraints and triggers, in order to secure the proper functioning while respecting system constraints  
(v) User Interface:
# Assumptions
(i) Μια νοσηλεία χωρίς ΗΜΕΡΟΜΗΝΙΑ_ΕΞΟΔΟΥ θεωρείται «ανοικτή» — δεν έχει διάγνωση εξόδου και δεν κοστολογείται.  
(ii) Το ΣΥΝΟΛΙΚΟ_ΚΟΣΤΟΣ υπολογίζεται αυτόματα από trigger κατά το INSERT/UPDATE, βάσει ΚΕΝ + υπέρβασης ΜΔΝ. Δεν επιτρέπεται χειροκίνητη εισαγωγή τιμής.  
(iii) Κάθε κλίνη μπορεί να έχει μόνο μία ενεργή νοσηλεία ανά πάσα στιγμή.  
(iv) Κάθε άφιξη ασθενή δημιουργεί υποχρεωτικά μία εγγραφή διαλογής, ανεξάρτητα από το αν οδηγήσει σε νοσηλεία.  
(v) Ο έλεγχος αλλεργιών γίνεται με LIKE (partial match) μεταξύ ονόματος δραστικής ουσίας και της καταγεγραμμένης αλλεργίας, λόγω ανομοιομορφίας στην ονοματολογία του αρχείου EMA.  
(vi) Συνταγογράφηση επιτρέπεται μόνο για ασθενείς με ενεργή νοσηλεία (χωρίς ημερομηνία εξόδου).  
(vii) Κάθε νοσηλεία αντιστοιχίζεται σε έναν ΚΕΝ κωδικό κατά την εισαγωγή. Το κόστος ανά ΚΕΝ διαφοροποιείται ανά ασφαλιστικό φορέα.  
(viii) Μόνο ένας ιατρός παρακολουθεί την εκάστοτε νοσηλεία (όχι ομάδα ιατρών)
(ix) Τα triggers εισάγονται μετά το load (install -> load -> triggers), εξασφαλίζουμε την ορθότητα/περιορισμούς στο ίδιο το py script, για την αποφυγή conflicts κατά την φόρτωση δεδομένων  
# Technical Details
και αυτα
