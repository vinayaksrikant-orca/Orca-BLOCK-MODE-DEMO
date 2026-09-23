import sqlite3
from flask import request

def get_user():
    user_id = request.args.get("id")
    conn = sqlite3.connect("test.db")
    query = "SELECT * FROM users WHERE id = " + user_id
    return conn.execute(query).fetchall()