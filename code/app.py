from flask import Flask, render_template, request
import mysql.connector

app = Flask(__name__)

def get_db_connection():
    return mysql.connector.connect(
        host='127.0.0.1',
        user='root',         
        password='',     
        database='hospital'
    )

# Home Page
@app.route('/')
def home():
    return render_template('home.html')

# Page showing all doctors
@app.route('/doctors')
def doctors():
    conn = get_db_connection()
    cur = conn.cursor(dictionary=True)
    
    sql_query = """
        SELECT P.ΑΜΚΑ, P.ΟΝΟΜΑ, P.ΕΠΩΝΥΜΟ, P.EMAIL, I.ΕΙΔΙΚΟΤΗΤΑ, I.ΒΑΘΜΙΔΑ
        FROM PROSOPIKO P
        JOIN IATROS I ON P.ΑΜΚΑ = I.ΑΜΚΑ_FK
        WHERE P.ΤΥΠΟΣ_ΠΡΟΣΩΠΙΚΟΥ = 'ΙΑΤΡΟΣ'
    """
    cur.execute(sql_query)
    doctors_list = cur.fetchall()
    
    cur.close()
    conn.close()
    return render_template('doctors.html', doctors=doctors_list)

# Page for each doctor (using AMKA as identifier)
@app.route('/doctor/<string:amka>')
def doctor_detail(amka):
    conn = get_db_connection()
    cur = conn.cursor(dictionary=True)
    
    sql_query = """
        SELECT P.ΑΜΚΑ, P.ΟΝΟΜΑ, P.ΕΠΩΝΥΜΟ, P.EMAIL, P.ΗΜΕΡΟΜΗΝΙΑ_ΓΕΝΝΗΣΗΣ, P.ΗΜΕΡΟΜΗΝΙΑ_ΠΡΟΣΛΗΨΗΣ,
               I.ΕΙΔΙΚΟΤΗΤΑ, I.ΒΑΘΜΙΔΑ, I.ΑΡΙΘΜΟΣ_ΑΔΕΙΑΣ_ΣΥΛΛΟΓΟΥ
        FROM PROSOPIKO P
        JOIN IATROS I ON P.ΑΜΚΑ = I.ΑΜΚΑ_FK
        WHERE P.ΑΜΚΑ = %s
    """
    cur.execute(sql_query, (amka,))
    
    doctor_data = cur.fetchone() 
    
    cur.close()
    conn.close()
    
    return render_template('doctor_detail.html', doctor=doctor_data)

# Page showing all nurses
@app.route('/nurses')
def nurses():
    conn = get_db_connection()
    cur = conn.cursor(dictionary=True)

    sql_query = """
        SELECT P.ΑΜΚΑ, P.ΟΝΟΜΑ, P.ΕΠΩΝΥΜΟ, P.EMAIL, N.ΒΑΘΜΙΔΑ
        FROM PROSOPIKO P
        JOIN NOSILEYTHS N ON P.ΑΜΚΑ = N.ΑΜΚΑ_FK
        WHERE P.ΤΥΠΟΣ_ΠΡΟΣΩΠΙΚΟΥ = 'ΝΟΣΗΛΕΥΤΗΣ'
    """
    cur.execute(sql_query)
    nurses_list = cur.fetchall()
    
    cur.close()
    conn.close()
    return render_template('nurses.html', nurses=nurses_list)

# Page for each nurse (using AMKA as identifier)
@app.route('/nurse/<string:amka>')
def nurse_detail(amka):
    conn = get_db_connection()
    cur = conn.cursor(dictionary=True)
    
    sql_query = """
        SELECT P.ΑΜΚΑ, P.ΟΝΟΜΑ, P.ΕΠΩΝΥΜΟ, P.EMAIL, P.ΗΜΕΡΟΜΗΝΙΑ_ΓΕΝΝΗΣΗΣ, P.ΗΜΕΡΟΜΗΝΙΑ_ΠΡΟΣΛΗΨΗΣ,
               N.ΒΑΘΜΙΔΑ
        FROM PROSOPIKO P
        JOIN NOSILEYTHS N ON P.ΑΜΚΑ = N.ΑΜΚΑ_FK
        WHERE P.ΑΜΚΑ = %s
    """
    cur.execute(sql_query, (amka,))
    
    nurse_data = cur.fetchone() 
    
    cur.close()
    conn.close()
    
    return render_template('nurse_detail.html', nurse=nurse_data)

# Page showing all administrative staff members
@app.route('/administrative')
def administrative():
    conn = get_db_connection()
    cur = conn.cursor(dictionary=True)

    sql_query = """
        SELECT P.ΑΜΚΑ, P.ΟΝΟΜΑ, P.ΕΠΩΝΥΜΟ, P.EMAIL, DP.ΡΟΛΟΣ, DP.ΓΡΑΦΕΙΟ_ΕΡΓΑΣΙΑΣ
        FROM PROSOPIKO P
        JOIN DIOIKITIKO_PROSOPIKO DP ON P.ΑΜΚΑ = DP.ΑΜΚΑ_FK
        WHERE P.ΤΥΠΟΣ_ΠΡΟΣΩΠΙΚΟΥ = 'ΔΙΟΙΚΗΤΙΚΟ ΠΡΟΣΩΠΙΚΟ'
    """
    cur.execute(sql_query)
    administrative_list = cur.fetchall()
    
    cur.close()
    conn.close()
    return render_template('administrative.html', administrative=administrative_list)

# Page for each administrative staff member (using AMKA as identifier)
@app.route('/administrative/<string:amka>')
def administrative_detail(amka):
    conn = get_db_connection()
    cur = conn.cursor(dictionary=True)
    
    sql_query = """
        SELECT P.ΑΜΚΑ, P.ΟΝΟΜΑ, P.ΕΠΩΝΥΜΟ, P.EMAIL, P.ΗΜΕΡΟΜΗΝΙΑ_ΓΕΝΝΗΣΗΣ, P.ΗΜΕΡΟΜΗΝΙΑ_ΠΡΟΣΛΗΨΗΣ,
               DP.ΡΟΛΟΣ, DP.ΓΡΑΦΕΙΟ_ΕΡΓΑΣΙΑΣ
        FROM PROSOPIKO P
        JOIN DIOIKITIKO_PROSOPIKO DP ON P.ΑΜΚΑ = DP.ΑΜΚΑ_FK
        WHERE P.ΑΜΚΑ = %s
    """
    cur.execute(sql_query, (amka,))
    
    administrative_data = cur.fetchone() 
    
    cur.close()
    conn.close()
    
    return render_template('administrative_detail.html', administrative=administrative_data)

@app.route('/query', methods=['GET', 'POST'])
def query():
    result = None
    error = None
    query_text = ''
    columns = []
    tables = []
    
    # Παίρνουμε τα ονόματα των πινάκων για να τα δείχνουμε στο πλάι
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SHOW TABLES")
        tables = [table[0] for table in cur.fetchall()]
        cur.close()
        conn.close()
    except:
        pass

    if request.method == 'POST':
        query_text = request.form['query']
        query_lower = query_text.lower()
        
        # Προστασία από διαγραφή δεδομένων
        if any(word in query_lower for word in ['drop', 'delete', 'truncate', 'insert', 'update', 'alter']):
            error = "Για λόγους ασφαλείας, επιτρέπονται μόνο SELECT queries."
        else:
            try:
                conn = get_db_connection()
                cur = conn.cursor(dictionary=True)
                cur.execute(query_text)
                
                result = cur.fetchall()
                if result:
                    columns = list(result[0].keys())
                
                cur.close()
                conn.close()
            except Exception as e:
                error = f"Σφάλμα κατά την εκτέλεση: {str(e)}"
    
    return render_template('query.html', 
                           result=result, 
                           columns=columns, 
                           query=query_text, 
                           error=error,
                           tables=tables)

## Εκκίνηση του Server
if __name__ == '__main__':
    app.run(debug=True)