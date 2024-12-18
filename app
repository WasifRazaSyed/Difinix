from flask import Flask, request, jsonify, session
from flask_mysqldb import MySQL
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from flask_cors import CORS
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LogisticRegression

import smtplib
import random
import string
import requests
import pickle
import pandas as pd

app = Flask(__name__)
CORS(app)

app0 = Flask(__name__)

# Configure MySQL database
app0.config['MYSQL_HOST'] = 'localhost'  
app0.config['MYSQL_PORT'] = 3306
app0.config['MYSQL_USER'] = 'root'
app0.config['MYSQL_PASSWORD'] = 'Temp@123'  
app0.config['MYSQL_DB'] = 'userdata'  

# Initialize MySQL
mysql0 = MySQL(app0)

app.config['SECRET_KEY'] = 'secret_key'

# MySQL Configuration
app.config['MYSQL_HOST'] = 'localhost'
app.config['MYSQL_PORT'] = 3306
app.config['MYSQL_USER'] = 'root'
app.config['MYSQL_PASSWORD'] = 'Temp@123'
app.config['MYSQL_DB'] = 'userdb'

mysql = MySQL(app)

vCode = 0

GMAIL_USER = "difinix.app@gmail.com" 
APP_PASSWORD = "qtdm rozp oqyx iloj"

@app.route('/login', methods=['POST'])
def login():
    data = request.json
    username = data['username']
    password = data['password']
    session['username']=username
    try:
      
        cursor = mysql.connection.cursor()
        cursor.execute(''' SELECT * FROM users WHERE username = %s AND password = %s ''', (username, password))
        user = cursor.fetchone()
        cursor.close()

        if user:
            user_email=user[2]
            return jsonify({'message': 'Login successful!'}), 200
        else:
            return jsonify({'error': 'Invalid credentials!'}), 401

    except Exception as e:
     
        print(f"Error: {str(e)}")
        return jsonify({'error': 'An error occurred while processing your request.', 'details': str(e)}), 500


@app.route('/register', methods=['POST'])
def register():
    try:
        data = request.json
        user_id = ''.join(random.choices(string.digits, k=4))
        username = data['username']
        email = data['email']
        phone = data['phone']
        address = data['address']
        account_number = data['account_number']
        password = data['password']
        admin_code = data.get('admin_code', '')  

      
        if admin_code == '0099':
            is_admin = True
        elif admin_code == '':
            is_admin = False 
        else:
            return jsonify({'error': 'Invalid Admin Code.'}), 400
     
        cursor = mysql.connection.cursor()
        cursor.execute('SELECT * FROM users WHERE username = %s OR email = %s', (username, email))
        existing_user = cursor.fetchone()

        if existing_user:
            cursor.close()
            return jsonify({'error': 'Username or email already exists.'}), 400

   
        cursor.execute(''' 
            INSERT INTO users (user_id, username, email, phone, address, account_number, password, verified, amdin) 
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s) 
        ''', (user_id, username, email, phone, address, account_number, password, 0, is_admin))
        mysql.connection.commit()
        cursor.close()

        session['user_email'] = email

        return jsonify({'message': 'Sign up successful'}), 200

    except Exception as e:
        print(f"Error: {str(e)}")
        return jsonify({'error': 'Failed to register user.', 'details': str(e)}), 500




@app.route('/verificationCode', methods=['POST'])
def send_verification_code():
    try:
        user_email = session.get('user_email')
       
        verification_code = ''.join(random.choices(string.digits, k=4))

  
        session['verification_code'] = verification_code
    
        print("[DEBUG] Creating the email structure...", user_email, vCode)
       
        msg = MIMEMultipart()
        msg['From'] = GMAIL_USER
        msg['To'] = user_email  
        msg['Subject'] = 'Verification Code'

       
        msg.attach(MIMEText(f'Your login verification code is: {verification_code}', 'plain'))

        print("[DEBUG] Connecting to Gmail SMTP server...")
      
        server = smtplib.SMTP('smtp.gmail.com', 587)

        print("[DEBUG] Starting TLS encryption...")
        server.starttls()  

        print("[DEBUG] Logging in to the Gmail account...")
        server.login(GMAIL_USER, APP_PASSWORD)  

        print("[DEBUG] Sending the email...")
       
        server.sendmail(GMAIL_USER, user_email, msg.as_string())

        print("[DEBUG] Email sent successfully!")
        server.quit()

        return jsonify({'message': 'Verification code sent successfully!'}), 200

    except smtplib.SMTPAuthenticationError as auth_error:
        print("[ERROR] Authentication failed. Please check your email and app password.")
        print(f"[ERROR Details] {auth_error}")
        return jsonify({'error': 'Authentication failed. Please check your credentials.'}), 500

    except smtplib.SMTPException as smtp_error:
        print("[ERROR] An SMTP error occurred.")
        print(f"[ERROR Details] {smtp_error}")
        return jsonify({'error': 'Failed to send verification code.'}), 500

    except Exception as e:
        print(f"Error: {str(e)}")
        return jsonify({'error': 'Failed to send verification code.', 'details': str(e)}), 500

@app.route('/verify', methods=['POST'])
def verify_code():
    try:
      
        data = request.json
        user_code = data.get('verification_code')

       
        stored_code = session.get('verification_code')
        
      
        if user_code != stored_code:
            return jsonify({'error': 'Verification code does not match.'}), 400

     
        user_email = session.get('user_email')

       
        if not user_email:
            return jsonify({'error': 'User email not found in session.'}), 400

       
        try:
            cursor = mysql.connection.cursor()
            cursor.execute('''
                UPDATE users
                SET verified = 1
                WHERE email = %s
            ''', (user_email,))
            mysql.connection.commit()
            cursor.close()

        except Exception as db_error:
            
            print(f"Database Error: {str(db_error)}")
            return jsonify({'error': 'Database error occurred while verifying user.', 'details': str(db_error)}), 500

        return jsonify({'message': 'Verification successful!'}), 200

    except Exception as e:
       
        print(f"Error: {str(e)}")
        return jsonify({'error': 'An unexpected error occurred.', 'details': str(e)}), 500

@app.route('/forgot', methods=['POST'])
def forgot_password():
    try:
        data = request.json
        email = data.get('email')
 
        cursor = mysql.connection.cursor()
        cursor.execute("SELECT * FROM users WHERE email = %s", (email,))
        user = cursor.fetchone()

        if not user:
            return jsonify({'message': 'Email not found'}), 404

        
        session['user_email'] = email

        
        verification_code = ''.join(random.choices(string.digits, k=4))

        
        session['verification_code'] = verification_code

      
        msg = MIMEMultipart()
        msg['From'] = GMAIL_USER
        msg['To'] = email
        msg['Subject'] = 'Verification Code'

      
        msg.attach(MIMEText(f'Your login verification code is: {verification_code}', 'plain'))

  
        server = smtplib.SMTP('smtp.gmail.com', 587)
        server.starttls()  

       
        server.login(GMAIL_USER, APP_PASSWORD)

     
        server.sendmail(GMAIL_USER, email, msg.as_string())

      
        server.quit()

        return jsonify({'message': 'Verification code sent successfully!'}), 200

    except smtplib.SMTPAuthenticationError as auth_error:
        print("[ERROR] Authentication failed. Please check your email and app password.")
        print(f"[ERROR Details] {auth_error}")
        return jsonify({'error': 'Authentication failed. Please check your credentials.'}), 500

    except smtplib.SMTPException as smtp_error:
        print("[ERROR] An SMTP error occurred.")
        print(f"[ERROR Details] {smtp_error}")
        return jsonify({'error': 'Failed to send verification code.'}), 500

    except Exception as e:
        print(f"Error: {str(e)}") 
        return jsonify({'error': 'Failed to send verification code.', 'details': str(e)}), 500 


@app.route('/reset', methods=['POST'])
def reset_password():
    try:
        data = request.json
        new_password = data.get('new_password')

        email = session.get('user_email')

        if not email:
            return jsonify({'error': 'No email found in session. Please try again.'}), 400

        cursor = mysql.connection.cursor()
        cursor.execute("UPDATE users SET password = %s WHERE email = %s", (new_password, email))
        mysql.connection.commit()
        cursor.close()

        return jsonify({'message': 'Password Changed Successfully'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

    
@app.route('/getUserProfile', methods=['GET'])
def get_user_profile():
    try:
        user_name = session.get('username')  
        print(user_name)

        cursor = mysql.connection.cursor()
        cursor.execute(''' SELECT nickname, amdin, username FROM users WHERE username = %s ''', (user_name,))
        user = cursor.fetchone()
        cursor.close()
               
        if user:
            print("User found")
            print(f"Name: {user[0]}, Admin status: {user[1]}")
            session['username']=user[2]
            return jsonify({'name': user[0], 'is_admin': user[1]}), 200  
        else:
            return jsonify({'error': 'User not found'}), 404
            
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/saveFormData', methods=['POST'])
def save_form_data():
    try:
        data = request.json

       
        nickname = data['nickname']
        hobbies = data['hobbies']
        emergency_contact = data['emergencyContact']
        mental_state = data['mentalState']
        therapy_history = data['therapyHistory']
        medications = data['medications']
        goals = data['goals']
        user_name = session.get('username')


        cursor0 = mysql0.connection.cursor()
        cursor0.execute("SELECT * FROM userdata WHERE username = %s", (user_name,))
        existing_user = cursor0.fetchone()
        cursor0.close()

        cursor = mysql.connection.cursor()

        if existing_user:  
            cursor.execute(''' 
                UPDATE userdata 
                SET nickname = %s, hobbies = %s, emergency_contact = %s, mental_state = %s, 
                    therapy_history = %s, medications = %s, goals = %s 
                WHERE username = %s
            ''', (nickname, hobbies, emergency_contact, mental_state, therapy_history, medications, goals, user_name))
        else:  
            cursor.execute(''' 
                INSERT INTO userdata (username, nickname, hobbies, emergency_contact, mental_state, therapy_history, medications, goals) 
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s) 
            ''', (user_name, nickname, hobbies, emergency_contact, mental_state, therapy_history, medications, goals))

       
        mysql0.connection.commit()
        cursor.close()

        cursor = mysql.connection.cursor()
        cursor.execute("UPDATE users SET nickname = %s WHERE username = %s", (nickname, user_name))
        mysql.connection.commit()
        cursor.close()

        return jsonify({'message': 'Form data saved successfully!'}), 200

    except Exception as e:
        print(f"Error: {str(e)}")
        return jsonify({'error': 'Failed to save form data.', 'details': str(e)}), 500

@app.route('/saveDisease', methods=['POST'])
def save_disease():
    try:
        data = request.json
        disease = data.get('disease', '')
        username=session.get('username')
        cursor = mysql0.connection.cursor()
        cursor.execute('''
            UPDATE userdata SET disease=%s WHERE username=%s
        ''', (disease, username))
        
        mysql.connection.commit()
        cursor.close()

        return jsonify({'message': 'Diseases saved successfully!'}), 200
    except Exception as e:
        print(f"Error: {str(e)}")
        return jsonify({'error': 'Failed to save diseases.', 'details': str(e)}), 500

@app.route('/getStatus', methods=['GET'])
def get_status():
    try:
      
        username = session.get('username')

    
        if not username:
            return jsonify({'status': 0}), 200

        cursor = mysql.connection.cursor()
        cursor.execute("SELECT 1 FROM userdata WHERE username = %s", (username,))
        user_data = cursor.fetchone()
        cursor.close()

        if user_data:
            return jsonify({'status': 1}), 200  # Record exists
        else:
            return jsonify({'status': 0}), 200  # No record found

    except Exception as e:
        print(f"Error: {str(e)}")
        return jsonify({'error': 'An error occurred while checking the status.', 'details': str(e)}), 500

@app.route('/get_userDetails', methods=['GET'])
def get_user_details():
    try:
        user_input = request.args.get('user')
        cursor = mysql.connection.cursor()
        session['update_user'] = user_input

        cursor.execute("SELECT user_id, username, email, phone, address, account_number, password, verified, amdin, nickname FROM users WHERE username = %s OR email = %s", (user_input, user_input))
        user_details = cursor.fetchone()

        cursor.execute("SELECT hobbies, emergency_contact, therapy_history, medications, goals, username, nickname, disease FROM userdata WHERE username = %s", (user_input,))
        user_additional_details = cursor.fetchone()

        cursor.close()

        if user_details and user_additional_details:
            return jsonify({
                'User ID': user_details[0],
                'Username': user_details[1],
                'E-mail': user_details[2],
                'Phone': user_details[3],
                'Address': user_details[4],
                'Account number': user_details[5],
                'Verified': user_details[7],
                'Admin': user_details[8],
                'Nickname': user_additional_details[6],
                'Hobbies': user_additional_details[0],
                'Emergency Contact': user_additional_details[1],
                'Therapy History': user_additional_details[2],
                'Medications': user_additional_details[3],
                'Goals': user_additional_details[4],
                'Disease': user_additional_details[7]
            })
        else:
            return jsonify({'error': 'User not found'}), 404

    except Exception as e:
        print(f"Error: {str(e)}")
        return jsonify({'error': 'Failed to fetch user details', 'details': str(e)}), 500


@app.route('/edit_user', methods=['POST'])
def edit_user():
    try:
        data = request.json
        user_name = session.get('update_user')  
        print(data)

        mapped_userdata = {
            'nickname': data.get('Nickname', ''),
            'hobbies': data.get('Hobbies', ''),
            'emergency_contact': data.get('Emergency Contact', ''),
            'therapy_history': data.get('Therapy History', ''),
            'medications': data.get('Medications', ''),
            'goals': data.get('Goals', ''),
            'disease': data.get('Disease', '')
        }

        mapped_users = {
            'user_id': data.get('User ID', ''),
            'username': data.get('Username', ''),
            'email': data.get('E-mail', ''),
            'phone': data.get('Phone', ''),
            'address': data.get('Address', ''),
            'account_number': data.get('Account number', ''),
            'verified': data.get('Verified', ''),
            'amdin': data.get('Admin', ''),
            'nickname': data.get('Nickname', '')
        }
        
        cursor = mysql.connection.cursor()

        cursor.execute(''' 
            UPDATE userdata 
            SET nickname = %s, hobbies = %s, emergency_contact = %s, 
                therapy_history = %s, medications = %s, goals = %s, disease = %s
            WHERE username = %s
        ''', (
            mapped_userdata['nickname'], mapped_userdata['hobbies'], mapped_userdata['emergency_contact'], 
            mapped_userdata['therapy_history'], mapped_userdata['medications'], 
            mapped_userdata['goals'], mapped_userdata['disease'], user_name))

        cursor.execute('''
            UPDATE users
            SET user_id = %s, username = %s, email = %s, phone = %s, 
                address = %s, account_number = %s, verified = %s, amdin = %s, nickname = %s
            WHERE username = %s
        ''', (
            mapped_users['user_id'], mapped_users['username'], mapped_users['email'], mapped_users['phone'],
            mapped_users['address'], mapped_users['account_number'], mapped_users['verified'],
            mapped_users['amdin'], mapped_users['nickname'], user_name
        ))

        mysql.connection.commit()
        cursor.close()

        return jsonify({'message': 'User data updated successfully'}), 200
    except Exception as e:
        print(f"Error: {str(e)}")
        return jsonify({'error': 'Failed to update user data', 'details': str(e)}), 500

@app.route('/fetch_psy', methods=['GET'])
def fetch_psy():
    try:
        cursor = mysql.connection.cursor()
        query = "SELECT * FROM psychologist"  
        cursor.execute(query)
        result = cursor.fetchall()
        cursor.close()

        psychologists = []
        for row in result:
            psychologists.append({
                "id": row[0],        
                "name": row[1],
                "title": row[2],
                "email": row[3],
                "specialities": row[4],
                "wyh": row[5],
                "gender": row[6],
            })

        return jsonify(psychologists), 200
    except Exception as e:
        print(f"Error fetching psychologists: {str(e)}")
        return jsonify({"error": "Failed to fetch psychologists", "details": str(e)}), 500

@app.route('/add_prof', methods=['POST'])
def add_prof():
    try:
        data = request.json
        name = data.get('name')
        title = data.get('title')
        email = data.get('email')
        specialities = data.get('specialities', '')
        wyh = data.get('wyh', '')
        gender = data.get('gender', 'male')  

        if not name or not title or not email:
            return jsonify({"error": "Name, Title, and Email are required."}), 400

        cursor = mysql.connection.cursor()
        query = """
            INSERT INTO psychologist (name, title, email, specialities, wyh, gender) 
            VALUES (%s, %s, %s, %s, %s, %s)
        """
        cursor.execute(query, (name, title, email, specialities, wyh, gender))
        mysql.connection.commit()
        cursor.close()

        return jsonify({"message": "Success"}), 201
    except Exception as e:
        print(f"Error adding psychologist: {str(e)}")
        return jsonify({"error": "Failed to add psychologist", "details": str(e)}), 500
    
@app.route('/update_prof', methods=['PUT'])
def update_prof():
    try:

        data = request.json
        name = data.get('name') 
        title = data.get('title')
        email = data.get('email')
        specialities = data.get('specialities', '')
        wyh = data.get('wyh', '')
        gender = data.get('gender', 'male')  

        if not name or not title or not email:
            return jsonify({"error": "Name, Title, and Email are required."}), 400

        cursor = mysql.connection.cursor()
        query = """
            UPDATE psychologist 
            SET title = %s, email = %s, specialities = %s, wyh = %s, gender = %s 
            WHERE name = %s
        """
        cursor.execute(query, (title, email, specialities, wyh, gender, name))
        mysql.connection.commit()
        cursor.close()

        return jsonify({"message": "Profile updated successfully"}), 200
    except Exception as e:
        print(f"Error updating profile: {str(e)}")
        return jsonify({"error": "Failed to update profile", "details": str(e)}), 500

@app.route('/delete_prof', methods=['DELETE'])
def delete_prof():
    try:
        data = request.json
        name = data.get('name') 

        if not name:
            return jsonify({"error": "Name is required."}), 400

        cursor = mysql.connection.cursor()
        query = "DELETE FROM psychologist WHERE name = %s"
        cursor.execute(query, (name,))
        mysql.connection.commit()
        cursor.close()

        return jsonify({"message": "Profile deleted successfully"}), 200
    except Exception as e:
        print(f"Error deleting profile: {str(e)}")
        return jsonify({"error": "Failed to delete profile", "details": str(e)}), 500

@app.route('/review', methods=['POST'])
def review():
    try:
        data = request.json
        name = data.get('name')
        stars = data.get('stars')

        if not name or not stars:
            return jsonify({'error': 'Name and Stars are required.'}), 400

        cursor = mysql.connection.cursor()

        cursor.execute("SELECT stars FROM psychologist WHERE name = %s", (name,))
        result = cursor.fetchone()

        if not result:
            return jsonify({'error': 'Psychologist not found'}), 404

        current_stars = result[0] if result[0] else ''
        
        updated_stars = f"{stars},{current_stars}".strip(',')

        cursor.execute("UPDATE psychologist SET stars = %s WHERE name = %s", (updated_stars, name))
        mysql.connection.commit()

        cursor.close()

        return jsonify({'message': 'Review submitted successfully', 'updated_stars': updated_stars}), 200
    except Exception as e:
        print(f"Error: {str(e)}")
        return jsonify({'error': 'An error occurred while submitting the review', 'details': str(e)}), 500


data = {'Disease': ['Anxiety', 'Lack of interest', 'Major depressive disorder', 'Frustration'],
        'Genre': ['Chillout', 'Jazz', 'Acoustic', 'Rock']}
df = pd.DataFrame(data)


df.to_csv('disease_to_genre.csv', index=False)

df = pd.read_csv('disease_to_genre.csv')

df['Disease'] = df['Disease'].astype('category')
df['Genre'] = df['Genre'].astype('category')

disease_mapping = dict(enumerate(df['Disease'].cat.categories))
genre_mapping = dict(enumerate(df['Genre'].cat.categories))
reverse_disease_mapping = {v: k for k, v in disease_mapping.items()}
reverse_genre_mapping = {v: k for k, v in genre_mapping.items()}

df['Disease'] = df['Disease'].cat.codes
df['Genre'] = df['Genre'].cat.codes

X = df[['Disease']]
y = df['Genre']

X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

model = LogisticRegression()
model.fit(X_train, y_train)

with open('disease_to_genre_model.pkl', 'wb') as f:
    pickle.dump((model, disease_mapping, genre_mapping), f)

print("Done!")

def get_spotify_token(client_id, client_secret):
    url = "https://accounts.spotify.com/api/token"
    headers = {"Content-Type": "application/x-www-form-urlencoded"}
    data = {"grant_type": "client_credentials"}
    
    response = requests.post(url, headers=headers, data=data, auth=(client_id, client_secret))
    
    if response.status_code == 200:
        return response.json().get("access_token")
    else:
        raise Exception("Failed to fetch Spotify token.")

def fetch_spotify_tracks(genre, token):
    url = f"https://api.spotify.com/v1/search?q={genre}&type=track&limit=50"  # Change the limit to 50
    headers = {"Authorization": f"Bearer {token}"}
    
    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        data = response.json()
        tracks = data.get("tracks", {}).get("items", [])
        if len(tracks) > 20:

            selected_tracks = random.sample(tracks, 20)
            return [
                {
                    "name": track["name"],
                    "artist": ", ".join(artist["name"] for artist in track["artists"]),
                    "album": track["album"]["name"],
                    "url": track["external_urls"]["spotify"]
                }
                for track in selected_tracks
            ]
        else:
            return [
                {
                    "name": track["name"],
                    "artist": ", ".join(artist["name"] for artist in track["artists"]),
                    "album": track["album"]["name"],
                    "url": track["external_urls"]["spotify"]
                }
                for track in tracks
            ]
    else:
        return [{"error": "Error fetching songs from Spotify."}]

def predict_genre(disease):
    with open('disease_to_genre_model.pkl', 'rb') as f:
        model, disease_mapping, genre_mapping = pickle.load(f)
    
    reverse_disease_mapping = {v: k for k, v in disease_mapping.items()}
    
    if disease not in reverse_disease_mapping:
        return "Unknown disease."
    
    disease_encoded = [[reverse_disease_mapping[disease]]]
    genre_encoded = model.predict(disease_encoded)[0]
    
    return genre_mapping[genre_encoded]

@app.route('/fetch_disease', methods=['GET'])
def fetch_disease():
    try:
        username = session.get('username')
        if not username:
            return jsonify({'error': 'User not logged in'}), 401

        cursor = mysql.connection.cursor()
        cursor.execute('''SELECT disease FROM userdata WHERE username = %s''', (username,))
        disease = cursor.fetchone()

        cursor.close()

        if disease:
            return jsonify({'disease': disease[0]}), 200
        else:
            return jsonify({'error': 'No disease information found for the user'}), 404

    except Exception as e:
        print(f"Error: {str(e)}")
        return jsonify({'error': 'An error occurred while processing your request.', 'details': str(e)}), 500

@app.route('/fetch_music', methods=['POST'])
def fetch_music():
    try:
        data = request.get_json()
        disease = data.get('disease')
        print(disease)
        
        if not disease:
            return jsonify({'error': 'Disease is required'}), 400

        predicted_genre = predict_genre(disease)

        if predicted_genre == "Unknown disease.":
            return jsonify({'error': 'Could not predict genre for the disease'}), 400

        CLIENT_ID = "7d65fd86ae97449792b12d2f7ea6e0ef"
        CLIENT_SECRET = "b81b8dd1c91a4bfa8f5ae109cb4f3ab2"
        token = get_spotify_token(CLIENT_ID, CLIENT_SECRET)

        tracks = fetch_spotify_tracks(predicted_genre, token)
        return jsonify({'songs': tracks}), 200

    except Exception as e:
        print(f"Error: {str(e)}")
        return jsonify({'error': 'An error occurred while processing your request.', 'details': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)

